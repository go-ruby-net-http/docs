# go-ruby-net-http documentation

**Ruby's `Net::HTTP` HTTP/1.1 message codec — in pure Go, no cgo, no I/O.**

`go-ruby-net-http/net-http` is a faithful, pure-Go (zero cgo) reimplementation of
the deterministic, interpreter-independent core of Ruby's `Net::HTTP`: it builds
request bytes exactly as MRI 4.0.5 writes them to the socket and parses a raw
HTTP/1.1 response byte stream into MRI's `Net::HTTPResponse` subclass model —
**without any Ruby runtime, and without performing any I/O itself**. The module
path is `github.com/go-ruby-net-http/net-http`.

It is a **standalone, reusable** library importable by any Go program, and the
HTTP-message backend intended for [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)
(`rbgo`) — the same sibling pattern as
[go-ruby-regexp](https://github.com/go-ruby-regexp/regexp),
[go-ruby-erb](https://github.com/go-ruby-erb/erb) and
[go-ruby-yaml](https://github.com/go-ruby-yaml/yaml). The dependency runs one way:
this library has **no dependency on the Ruby runtime**.

!!! success "Status: complete — MRI byte-exact codec"
    A faithful pure-Go port of `Net::HTTP`'s message codec, validated by a
    **differential oracle** against the system `ruby` — request bytes and parsed
    responses compared byte-for-byte — at 100% coverage, `gofmt` + `go vet` clean,
    CI green across the six 64-bit Go targets and three OSes.

## The socket / TLS is a host-side seam

Building HTTP/1.1 request bytes and parsing a response byte stream is fully
deterministic and needs no interpreter, so it lives here as pure Go. Opening the
`TCPSocket`, doing the TLS handshake, and moving the bytes is the host's job.

| Stage | Owner | This library |
| --- | --- | --- |
| DNS, `TCPSocket`, TLS | host (rbgo) | — |
| serialise the request | this library | `Request.Bytes(version) []byte` |
| write / read bytes on the socket | host (rbgo) | — |
| parse the response | this library | `ParseResponse([]byte) (*Response, error)` |

## Quick taste

```go
req, _ := nethttp.NewRequest("POST", "/submit", "example.com", nil)
req.SetFormData([][2]string{{"name", "a b"}, {"x", "1&2"}})
wire, _ := req.Bytes("1.1")   // exact MRI socket bytes

raw := "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n"
res, _ := nethttp.ParseResponse([]byte(raw))
res.Class()      // "HTTPOK"
res.IsSuccess()  // true
res.Body()       // "Wikipedia" (chunked-decoded)
```

## Repositories

| Repo | What it is |
| --- | --- |
| [`net-http`](https://github.com/go-ruby-net-http/net-http) | the library — the `Net::HTTP` codec in pure Go |
| [`docs`](https://github.com/go-ruby-net-http/docs) | this documentation site (MkDocs Material, versioned with mike) |
| [`go-ruby-net-http.github.io`](https://github.com/go-ruby-net-http/go-ruby-net-http.github.io) | the organization landing page (Hugo) |
| [`brand`](https://github.com/go-ruby-net-http/brand) | logo and brand assets |

## Principles

- **Pure Go, `CGO_ENABLED=0`** — trivial cross-compilation, a single static
  binary, no C toolchain.
- **MRI byte-exact.** Request bytes and parsed responses match reference Ruby
  exactly, validated by a differential oracle against the `ruby` binary.
- **No I/O.** The codec never opens a socket, touches a file, or reads a clock —
  it is a pure function of its bytes, so it is deterministic and testable in
  isolation.
- **Standalone & reusable.** No dependency on the Ruby runtime; the dependency
  runs the other way.
- **100% test coverage**, enforced as a CI gate, across 6 arches and 3 OSes.

## Where to go next

- [Why pure Go](why.md) — why this slice of `Net::HTTP` is deterministic enough to
  live as a standalone, interpreter-independent Go library.
- [Usage & API](api.md) — the public surface and worked examples.
- [Roadmap](roadmap.md) — what is done and what is downstream (the transport) by design.
- [Performance](performance.md) — the offline, cross-runtime codec benchmark.

Source lives at [github.com/go-ruby-net-http/net-http](https://github.com/go-ruby-net-http/net-http).
