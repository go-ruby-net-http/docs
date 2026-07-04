# Roadmap

`go-ruby-net-http/net-http` is grown **test-first**, each capability
differential-tested against MRI rather than built in isolation. The
deterministic, interpreter-independent slice of `Net::HTTP` — the HTTP/1.1 message
codec — is **complete**.

| Stage | What | Status |
| --- | --- | --- |
| Request building | Request line + MRI's default headers in exact order/casing (`Accept-Encoding`, `Accept`, `User-Agent`, `Host`), `Content-Length` vs `Transfer-Encoding`, empty-body default for body-permitting methods, `set_form_data`, Basic / Proxy-Basic auth — byte-for-byte `Net::HTTPGenericRequest#exec`. | **Done** |
| Response parsing | Status-line regex, header lines with obs-fold continuation and repeated multi-value fields, body by `Content-Length` **or** chunked `Transfer-Encoding` (extensions + trailers). | **Done** |
| Response subclass model | Every status code mapped to its `Net::HTTPResponse` subclass and category, generated from MRI's `CODE_TO_OBJ`, with the `HAS_BODY` rule and the `HTTPUnknownResponse` / category fallbacks. | **Done** |
| `Net::HTTPHeader` mixin | `[]` / `[]=` / `key?` / `delete` / `add_field` / `get_fields` / `each_header` / `each_capitalized`, plus `content_type` / `content_length` / `chunked?` / `connection_close?` and the `URI.encode_www_form` component encoder. | **Done** |
| Differential oracle & coverage | Request bytes, response parse, subclass over MRI's whole table, and form encoding checked byte-for-byte against `ruby` (≥ 4.0); 100% coverage, green across 6 arches and 3 OSes. | **Done** |

## Documented out-of-scope boundaries

These are **deliberate**, recorded so the module's surface is unambiguous:

- **No transport — the socket / TLS is the host's.** DNS, `TCPSocket`, the TLS
  handshake, timeouts, redirects and connection reuse belong to the host (rbgo
  supplies the byte transport). This library formats and parses bytes only.
- **No I/O, no clock.** The codec is a pure function of its bytes; anything that
  needs to open a connection or measure time is the consumer's job.
- **No content-coding inflation.** `gzip` / `deflate` body inflation, like the
  socket itself, is the host's concern; the codec frames the body (Content-Length
  / chunked) and hands it back raw.
- **Reference is reference Ruby (MRI).** Byte-for-byte conformance targets MRI
  4.0.5's `Net::HTTP`, as pinned by the differential oracle.

See [Usage & API](api.md) for the surface and [Why pure Go](why.md) for the
codec/transport split.
