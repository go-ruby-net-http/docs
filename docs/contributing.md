# Contributing

Contributions are welcome. `go-ruby-net-http/net-http` is built to a small set of
non-negotiable rules — they are what keep it pure-Go, correct, and
MRI-compatible. Please read these before opening a pull request.

## Hard rules

- **Build from source — no vendoring.** Everything compiles from source. Being
  able to compile from source is a guarantee of independence.
- **100% test coverage target, enforced in CI.** New code ships with tests, and
  coverage is a CI gate. Fill the error branches, not just the happy path.
- **All GitHub content in English.** Issues, pull requests, commits, comments,
  and discussions are English-only.
- **Differential testing against MRI.** Correctness is defined by reference Ruby.
  The same requests are serialised here and by the system `ruby` (via a recording
  socket) and compared **byte-for-byte**; responses are parsed both here and by
  `Net::HTTPResponse.read_new` and compared — not approximated from memory.
- **Pure Go, cgo disabled.** The whole point is a single static binary with no C
  toolchain. Code must build with `CGO_ENABLED=0`.
- **A codec, not a client.** This module formats and parses HTTP/1.1 messages. It
  performs **no I/O** — no socket, no TLS, no clock. Anything that needs the
  network belongs in the host (rbgo), not here.

## Workflow

1. Pick or open an issue describing the change.
2. Work test-first: add the differential / unit tests, then make them pass.
3. Run the full suite with coverage and confirm the gate is green:

    ```sh
    COVERPKG=$(go list ./... | paste -sd, -)
    go test -race -coverpkg="$COVERPKG" -coverprofile=cover.out ./...
    go tool cover -func=cover.out | tail -1   # 100.0%
    ```

4. Open a PR in English, referencing the issue.

## Where things live

The library is in
[`github.com/go-ruby-net-http/net-http`](https://github.com/go-ruby-net-http/net-http).
This documentation site (and the offline benchmark harness) is in
[`github.com/go-ruby-net-http/docs`](https://github.com/go-ruby-net-http/docs).
Start from the [Usage & API](api.md) page and the [Roadmap](roadmap.md) to find
the right place for your change.
