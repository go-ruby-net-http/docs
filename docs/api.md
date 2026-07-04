# Usage & API

The public API lives at the module root (`github.com/go-ruby-net-http/net-http`,
package `nethttp`). It is **Ruby-shaped but Go-idiomatic**: the names mirror
`Net::HTTP` / `Net::HTTPHeader` (`chunked?` → `Chunked`, `content_type` →
`ContentType`, `each_capitalized` → `EachCapitalized`), while the surface follows
Go conventions — explicit byte slices, returned errors, no global state, and no
hidden I/O.

!!! success "Status: implemented"
    The library is built and importable as `github.com/go-ruby-net-http/net-http`;
    see [Roadmap](roadmap.md).

## Install

```sh
go get github.com/go-ruby-net-http/net-http
```

## Building a request

`NewRequest` mirrors `Net::HTTPGenericRequest#initialize` for the `Get` / `Post` /
`Put` / `Delete` / `Head` / `Patch` / `Options` subclasses: it seeds MRI's default
headers (`Accept-Encoding`, `Accept`, `User-Agent`, `Host`) in MRI's exact order
and casing, after any caller-supplied initial fields.

```go
req, _ := nethttp.NewRequest("POST", "/submit", "example.com", nil)
req.SetFormData([][2]string{{"name", "a b"}, {"x", "1&2"}}) // set_form_data
wire, _ := req.Bytes("1.1")                                 // exact MRI socket bytes
// POST /submit HTTP/1.1
// Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
// Accept: */*
// User-Agent: Ruby
// Host: example.com
// Content-Type: application/x-www-form-urlencoded
// Content-Length: 16
//
// name=a+b&x=1%262
```

`Request.Bytes` handles the `Content-Length` vs. `Transfer-Encoding` rule, the
empty-body default for body-permitting methods, and Basic / Proxy-Basic auth
(`req.BasicAuth("user", "pass")`).

## Parsing a response

`ParseResponse` mirrors `Net::HTTPResponse.read_new` + `read_body`: the status
line, folded multi-value headers, and the body decoded by `Content-Length` **or**
chunked `Transfer-Encoding` (chunk extensions and trailers included).

```go
raw := "HTTP/1.1 200 OK\r\n" +
    "Content-Type: text/plain\r\n" +
    "Transfer-Encoding: chunked\r\n\r\n" +
    "4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n"
res, _ := nethttp.ParseResponse([]byte(raw))
res.Code()      // "200"
res.Class()     // "HTTPOK"
res.Category()  // "HTTPSuccess"
res.IsSuccess() // true (+ IsInformation / IsRedirection / IsClientError / IsServerError)
res.Body()      // "Wikipedia" (chunked-decoded)
```

The response carries the **`Net::HTTPResponse` subclass identity** its status
selects — `HTTPOK`, `HTTPNotFound`, `HTTPMovedPermanently`, … with the
`HTTPUnknownResponse` / category fallbacks — exposed as `Class()` / `Category()`
and the `Is*` predicates rather than a distinct Go type per code.

## The `Net::HTTPHeader` mixin

Both `Request` and `Response` embed `*Header`, the pure-Go port of the
`Net::HTTPHeader` mixin (keys stored downcased, first-insertion order preserved):

```go
h.Get("Content-Type")       // []      -> (value, ok)
h.Set("X-Trace", "abc")     // []=
h.AddField("Set-Cookie", v) // add_field (multi-value)
h.GetFields("Set-Cookie")   // get_fields -> []string
h.ContentType()             // "text/plain"
h.ContentLength()           // (n, ok, err)
h.Chunked()                 // chunked?
h.ConnectionClose()         // connection_close?
h.EachCapitalized(fn)       // each_capitalized (wire order + casing)
```

## Public surface

```go
// Request building (Net::HTTPGenericRequest + the Get/Post/... subclasses).
func NewRequest(method, path, host string, initHeader [][2]string) (*Request, error)
func (r *Request) Bytes(version string) ([]byte, error) // exact MRI socket bytes
func (r *Request) SetBody(body []byte)
func (r *Request) SetFormData(params [][2]string, sep ...string)
func (r *Request) BasicAuth(account, password string)
func (r *Request) ProxyBasicAuth(account, password string)

// Response parsing (Net::HTTPResponse.read_new + read_body).
func ParseResponse(raw []byte) (*Response, error)
func (r *Response) Code() string        // "200"
func (r *Response) Message() string     // "OK"
func (r *Response) HTTPVersion() string // "1.1"
func (r *Response) Class() string       // "HTTPOK"
func (r *Response) Category() string    // "HTTPSuccess"
func (r *Response) Body() []byte        // decoded (Content-Length or chunked)
func (r *Response) IsSuccess() bool     // + Is{Information,Redirection,ClientError,ServerError}

// URI.encode_www_form helpers.
func EncodeWWWFormComponent(s string) string
func EncodeWWWForm(pairs [][2]string) string
```

See [Roadmap](roadmap.md) for the codec-vs-transport boundary and
[Performance](performance.md) for the offline benchmark.
