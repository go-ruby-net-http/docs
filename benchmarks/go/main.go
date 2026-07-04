// Copyright (c) the go-ruby-* authors
// SPDX-License-Identifier: BSD-3-Clause
//
// Offline, library-level benchmark of the pure-Go go-ruby-net-http/net-http
// message codec against MRI's Net::HTTP over its deterministic, network-free
// surface: request serialization, response parsing (status line + headers +
// chunked decode over a fixed buffer), URI form (query) building, and header
// canonicalization. No sockets, no DNS, no clock — every input is built
// identically here and in ruby/net_http.rb and the outputs are proven identical
// (CHECK digests) before any timing.
package main

import (
	"bytes"
	"os"
	"strconv"
	"strings"

	nethttp "github.com/go-ruby-net-http/net-http"
)

// ---------------------------------------------------------------------------
// Deterministic shared inputs — mirrored byte-for-byte in ruby/net_http.rb.
// ---------------------------------------------------------------------------

// request-serialize: a POST with an x-www-form-urlencoded body. This is exactly
// the Net::HTTP::Post.new(URI) + set_form_data path the differential oracle
// pins byte-for-byte; here it is serialized on the hot loop.
var reqFormPairs = [][2]string{
	{"title", "Ruby Net::HTTP"},
	{"q", "a b & c=d"},
	{"lang", "en"},
	{"n", "42"},
	{"tag", "café"},
}

// form-encode: URI.encode_www_form over a corpus with spaces, reserved bytes,
// percent signs and multibyte UTF-8.
var formPairs = [][2]string{
	{"q", "ruby net http"},
	{"title", "The Pragmatic Programmer's Guide"},
	{"tags", "a,b,c"},
	{"expr", "1+1=2 & 3>2"},
	{"path", "/usr/local/bin"},
	{"url", "https://example.com/p?x=1&y=2"},
	{"name", "café au lait"},
	{"price", "€19.99"},
	{"pct", "100%"},
	{"star", "*"},
	{"tilde", "a~b"},
	{"space", "one two three"},
	{"amp", "you & me"},
	{"eq", "k=v"},
	{"slash", "a/b/c"},
	{"hash", "a#b"},
	{"plus", "a+b"},
	{"paren", "f(x)"},
	{"quote", "\"quoted\""},
	{"semi", "a;b"},
	{"unicode", "日本語"},
	{"empty", ""},
	{"dash", "a-b_c.d"},
	{"n", "1234567890"},
}

// header-canonicalize: a rich set of downcased header names (none colliding with
// the seeded Accept-Encoding / Accept / User-Agent / Host / Range defaults) whose
// each_capitalized wire form is produced on the hot loop.
var canonHeaders = [][2]string{
	{"x-request-id", "c8f3e1a2-7b04-4d19-9f2a-1e6b0c5d3a77"},
	{"x-forwarded-for", "203.0.113.7, 198.51.100.2"},
	{"x-forwarded-proto", "https"},
	{"cache-control", "no-cache, no-store, max-age=0"},
	{"content-md5", "Q2hlY2sgSW50ZWdyaXR5"},
	{"if-none-match", "\"686897696a7c876b7e\""},
	{"if-modified-since", "Wed, 21 Oct 2026 07:28:00 GMT"},
	{"www-authenticate", "Bearer realm=\"api\""},
	{"content-language", "en-US"},
	{"access-control-allow-origin", "*"},
	{"x-content-type-options", "nosniff"},
	{"strict-transport-security", "max-age=63072000; includeSubDomains"},
	{"referrer-policy", "no-referrer"},
	{"x-xss-protection", "1; mode=block"},
	{"proxy-authenticate", "Basic realm=\"proxy\""},
	{"last-modified", "Tue, 15 Nov 2026 12:45:26 GMT"},
}

// response-parse: a chunked HTTP/1.1 response whose body is split into 200-byte
// chunks. Built identically in Go and Ruby so both parse the same stream.
const respUnit = "Wikipedia, the free encyclopedia. "

var respHeaders = [][2]string{
	{"Content-Type", "text/plain; charset=utf-8"},
	{"Server", "go-ruby-net-http-bench"},
	{"Cache-Control", "no-cache"},
	{"Set-Cookie", "session=abc123"},
	{"Set-Cookie", "theme=dark"},
	{"Transfer-Encoding", "chunked"},
}

func respBody() []byte { return bytes.Repeat([]byte(respUnit), 64) }

func respRaw() []byte {
	body := respBody()
	var b bytes.Buffer
	b.WriteString("HTTP/1.1 200 OK\r\n")
	for _, h := range respHeaders {
		b.WriteString(h[0])
		b.WriteString(": ")
		b.WriteString(h[1])
		b.WriteString("\r\n")
	}
	b.WriteString("\r\n")
	for i := 0; i < len(body); i += 200 {
		end := i + 200
		if end > len(body) {
			end = len(body)
		}
		chunk := body[i:end]
		b.WriteString(strconv.FormatInt(int64(len(chunk)), 16))
		b.WriteString("\r\n")
		b.Write(chunk)
		b.WriteString("\r\n")
	}
	b.WriteString("0\r\n\r\n")
	return b.Bytes()
}

// ---------------------------------------------------------------------------
// The four network-free operations. Each returns its canonical output bytes so
// the same bytes can be digested for the CHECK cross-check.
// ---------------------------------------------------------------------------

func buildRequest() *nethttp.Request {
	r, err := nethttp.NewRequest("POST", "/v1/submit", "api.example.com", nil)
	if err != nil {
		panic(err)
	}
	r.SetFormData(reqFormPairs)
	return r
}

func buildCanonRequest() *nethttp.Request {
	r, err := nethttp.NewRequest("GET", "/", "", canonHeaders)
	if err != nil {
		panic(err)
	}
	return r
}

func opRequestSerialize(r *nethttp.Request) []byte {
	out, err := r.Bytes("1.1")
	if err != nil {
		panic(err)
	}
	return out
}

func opResponseParse(raw []byte) []byte {
	res, err := nethttp.ParseResponse(raw)
	if err != nil {
		panic(err)
	}
	return []byte(res.Code() + "|" + res.Class() + "|" + string(res.Body()))
}

func opFormEncode() []byte {
	return []byte(nethttp.EncodeWWWForm(formPairs))
}

func opHeaderCanon(r *nethttp.Request) []byte {
	var b strings.Builder
	r.EachCapitalized(func(k, v string) {
		b.WriteString(k)
		b.WriteString(": ")
		b.WriteString(v)
		b.WriteString("\r\n")
	})
	return []byte(b.String())
}

func main() {
	req := buildRequest()
	canonReq := buildCanonRequest()
	raw := respRaw()

	if len(os.Args) > 1 && os.Args[1] == "verify" {
		check("request-serialize", opRequestSerialize(req))
		check("response-parse", opResponseParse(raw))
		check("form-encode", opFormEncode())
		check("header-canonicalize", opHeaderCanon(canonReq))
		return
	}

	bench("request-serialize", 200, func() { sink = opRequestSerialize(req) })
	bench("response-parse", 200, func() { sink = opResponseParse(raw) })
	bench("form-encode", 200, func() { sink = opFormEncode() })
	bench("header-canonicalize", 200, func() { sink = opHeaderCanon(canonReq) })
}
