# Why pure Go

`go-ruby-net-http/net-http` reimplements the core of Ruby's `Net::HTTP` in **pure
Go, with cgo disabled**. The slice of `Net::HTTP` it covers is **deterministic and
interpreter-independent**: given the request description it produces the exact
bytes MRI would write to the socket, and given a response byte stream it produces
the exact `Net::HTTPResponse` model MRI would build — a pure function of the
bytes, no live binding, no evaluation of arbitrary Ruby. That is precisely the
part that can — and should — live as a standalone Go library, separate from both
the interpreter and the network.

## The transport is a separate concern

`Net::HTTP` bundles two very different things: a **message codec** (format the
request, parse the response) and a **transport** (DNS, `TCPSocket`, TLS, timeouts,
redirects, connection reuse). Only the first is deterministic and pure. This
library implements exactly that half:

- `Request.Bytes` is the inverse of `ParseResponse`; neither touches the network,
  a file, or a clock.
- The host supplies the byte transport — open the (TLS) socket, write
  `Request.Bytes`, read everything back, hand it to `ParseResponse`. In the rbgo
  ecosystem that host is the interpreter's socket layer.

Keeping the transport out is what makes the codec **testable in isolation** and
**reusable** by any Go program that already has a byte transport.

## Extracted for reuse, bound the other way

This library is designed as a reusable standalone module so that:

- any Go program can import `github.com/go-ruby-net-http/net-http` directly, with
  no Ruby runtime;
- the dependency runs the *other* way — `rbgo` binds this module as the
  HTTP-message backend (the same pattern as
  [go-ruby-yaml](https://github.com/go-ruby-yaml/yaml)), rather than this module
  depending on the interpreter;
- the behaviour is pinned by a **differential oracle** against the system `ruby`,
  independent of any one consumer.

## Why pure Go matters here

Because the library is CGO-free, it:

- cross-compiles to every Go target with no C toolchain, and links into a single
  static binary;
- has **no dependency on the Ruby runtime** — the dependency runs the other way;
- can be differentially tested against the `ruby` binary wherever one is on
  `PATH`, while the cross-arch lanes (where `ruby` is absent) still validate the
  codec itself.

See [Usage & API](api.md) for the surface and [Roadmap](roadmap.md) for the
codec-vs-transport boundary.
