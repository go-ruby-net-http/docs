<!-- SPDX-License-Identifier: BSD-3-Clause -->
# `go-ruby-net-http` offline library benchmark harness

Reproducible, cross-runtime benchmark of the **pure-Go `go-ruby-net-http/net-http`
HTTP/1.1 message codec** against the reference Ruby runtimes (MRI, MRI + YJIT,
JRuby, TruffleRuby). It measures the **network-free surface** through the Go API,
isolated from any interpreter, so the numbers answer: *is the pure-Go codec as
fast as the reference runtime's own `Net::HTTP` on the deterministic, compute-only
work?*

**Offline scope only.** DNS, the `TCPSocket`, the TLS handshake and the actual
byte transfer are the host's job (see the library's socket/TLS seam) and are
**not** benchmarked here. This measures request/response *codec* cost, not
end-to-end HTTP latency.

## What is measured

Four network-free operations, each built from identical deterministic inputs on
both sides:

- **`request-serialize`** — build the exact request byte stream (`Request.Bytes` /
  `Net::HTTPGenericRequest#exec`): request line, default headers in MRI order,
  form body, `Content-Length`.
- **`response-parse`** — parse a fixed chunked response buffer (`ParseResponse` /
  `Net::HTTPResponse.read_new` + `reading_body`): status line, multi-value
  headers, chunked-`Transfer-Encoding` decode.
- **`form-encode`** — `URI.encode_www_form` over a corpus with spaces, reserved
  bytes, percent signs and multibyte UTF-8 (`EncodeWWWForm`).
- **`header-canonicalize`** — canonicalize + join a rich header block
  (`each_capitalized` / `EachCapitalized`).

## Layout

- `go/`             — self-contained Go driver; `go.mod` pins the published library.
- `ruby/net_http.rb` — the equivalent workload; `ruby/_harness.rb` is the shared timer.
- `run.sh`          — runs every available runtime and prints one Markdown table per
  sub-benchmark (ns/op + ratio vs MRI).

## Run

```sh
bash benchmarks/run.sh
```

Environment knobs: `OUTER` (timed passes, default 25), `WARM` (untimed warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select runtime binaries.

## Method

Each process runs `WARM` untimed passes (to let the JVM/GraalVM JITs warm up),
then `OUTER` timed passes of a fixed inner loop, timed with a monotonic clock;
the **best** pass is reported as **ns/op**. Interpreter start-up is outside the
timed region. The Go driver and the Ruby script build **identical inputs**, and
every op emits a `sha256` **CHECK** of its output: a runtime is only timed if all
four digests match the Go driver **byte-for-byte** (a mismatching runtime is
skipped with a warning). Results are published, dated, in `../docs/performance.md`.
