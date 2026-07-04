# Performance

`go-ruby-net-http/net-http` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) can bind for Ruby's
`Net::HTTP` **message codec**. This page records a **comparative, offline
benchmark** of that codec against the reference Ruby runtimes, part of the
ecosystem-wide per-module parity suite.

!!! warning "Offline scope — this is the codec, not the network"
    `net-http` is a **message codec with no I/O**: DNS, the `TCPSocket`, the TLS
    handshake and the byte transfer are the host's job (rbgo's), by design. This
    benchmark therefore measures **only the deterministic, network-free surface** —
    building request bytes, parsing a response buffer (including chunked decode),
    URI form encoding, and header canonicalization. It is **not** an end-to-end
    HTTP latency comparison; the wire, the kernel and the TLS stack dominate any
    real request and are identical regardless of who builds the bytes.

## What is measured

The **same** four network-free operations run through the pure-Go library (via
its Go API) and through each reference runtime's own `Net::HTTP` / `URI`. Inputs
are built byte-for-byte identically on both sides, and — before any timing — every
runtime emits a `sha256` of each op's output that is checked **identical to the Go
driver**; a runtime that diverges is skipped, not timed. So each column is the
**same observable operation**, apples-to-apples.

| Op | what it exercises |
| --- | --- |
| `request-serialize` | request line + MRI-ordered default headers + form body + `Content-Length` (`Request.Bytes` vs `Net::HTTPGenericRequest#exec`) |
| `response-parse` | status line + multi-value headers + **chunked `Transfer-Encoding` decode** over a fixed buffer (`ParseResponse` vs `read_new` + `reading_body`) |
| `form-encode` | `URI.encode_www_form` over spaces / reserved bytes / `%` / multibyte UTF-8 |
| `header-canonicalize` | canonicalize + join a 16-field header block (`EachCapitalized` vs `each_capitalized`) |

- **Host:** Apple M4 Max (`Mac16,5`, arm64), macOS 26.5.1 — **date 2026-07-04**.
- **Runtimes:** Go 1.26.4 · MRI `ruby 4.0.5 +PRISM` · MRI + YJIT · JRuby 10.1.0.0
  (OpenJDK 25) · TruffleRuby 34.0.1 (GraalVM CE Native).
- **Method:** each process runs 5 untimed warm-up passes, then 60 timed passes of
  a fixed inner loop, timed with a monotonic clock; the **best** pass is reported
  as **ns/op** (lower is better). `vs MRI` < 1.00× means *faster than MRI*.
  Interpreter start-up is outside the timed region, so these are operation costs,
  not `ruby file.rb` process costs.

## Summary — the pure-Go codec beats MRI *and* YJIT on all four

| Op | go-ruby (ns/op) | vs MRI | vs YJIT | verdict |
| --- | ---: | ---: | ---: | --- |
| request-serialize | 1056.9 | **0.22×** | **0.27×** | beats MRI + YJIT |
| response-parse | 1744.2 | **0.07×** | **0.10×** | beats MRI + YJIT |
| form-encode | 1869.6 | **0.06×** | **0.07×** | beats MRI + YJIT |
| header-canonicalize | 4120.0 | **0.28×** | **0.34×** | beats MRI + YJIT |

Unlike collection primitives (where MRI's `Hash` / `Array` are hand-written C and
hard to beat), Ruby's `Net::HTTP` codec is **pure Ruby** built on regexps and
per-line object allocation. Compiled Go with no interpreter dispatch and no
per-header `String`/`MatchData` allocation is a structural win here, so there is
**no op in this offline surface where YJIT is faster** — an honest result, not a
cherry-pick: the numbers below are every op measured, and the cross-runtime CHECK
gate guarantees each column computed the identical bytes.

## Per-operation results (best of 60)

#### request-serialize

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-net-http (pure Go)** | 1056.9 | 0.22× |
| MRI | 4735.0 | 1.00× |
| MRI + YJIT | 3860.0 | 0.82× |
| JRuby | 3534.8 | 0.75× |
| TruffleRuby | 8707.9 | 1.84× |

#### response-parse

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-net-http (pure Go)** | 1744.2 | 0.07× |
| MRI | 24400.0 | 1.00× |
| MRI + YJIT | 17035.0 | 0.70× |
| JRuby | 11425.6 | 0.47× |
| TruffleRuby | 17964.2 | 0.74× |

#### form-encode

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-net-http (pure Go)** | 1869.6 | 0.06× |
| MRI | 29090.0 | 1.00× |
| MRI + YJIT | 25200.0 | 0.87× |
| JRuby | 12307.7 | 0.42× |
| TruffleRuby | 21444.2 | 0.74× |

#### header-canonicalize

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-net-http (pure Go)** | 4120.0 | 0.28× |
| MRI | 14945.0 | 1.00× |
| MRI + YJIT | 12290.0 | 0.82× |
| JRuby | 5366.0 | 0.36× |
| TruffleRuby | 12570.6 | 0.84× |

!!! note "Reproduce"
    The harness is committed under
    [`benchmarks/`](https://github.com/go-ruby-net-http/docs/tree/main/benchmarks):
    a self-contained Go driver (`go/`, which pins this library's published
    pseudo-version via `go.mod`), the equivalent `ruby/net_http.rb` workload, and
    `run.sh`. Run `OUTER=60 WARM=5 bash benchmarks/run.sh`; env `OUTER`/`WARM`
    tune the pass budget and `RUBY`/`JRUBY`/`TRUFFLERUBY` select the runtime
    binaries. `run.sh` verifies every runtime's `sha256` CHECK against the Go
    driver before timing it.

!!! warning "Warm-up budget & noise — honest framing"
    Numbers reflect a **fixed warm-process budget** (5 warm-up + 60 timed passes
    in one process, best pass reported). The JVM/GraalVM JITs (JRuby, TruffleRuby)
    may need a larger warm-up to reach steady state, so their columns can
    **understate** peak throughput — TruffleRuby's `request-serialize` (1.84×) is
    the clearest case of a cold, short-loop outlier. Every number here is a **real
    measured value** from the dated run above — nothing is fabricated, estimated,
    or cherry-picked. The go-ruby column is the pure-Go library; every other column
    is that interpreter's own `Net::HTTP` / `URI` doing the equivalent work, proven
    to produce identical output.

!!! note "What this does *not* claim"
    This measures the **codec**, not HTTP. A real request is dominated by DNS, the
    TCP round-trips and the TLS handshake — none of which this library performs, and
    all of which are identical no matter which runtime formats the bytes. The result
    to take away is narrow and honest: **formatting and parsing HTTP/1.1 messages is
    materially cheaper in the pure-Go codec than in any Ruby runtime's `Net::HTTP`**,
    so binding it costs the interpreter nothing on the compute side.
