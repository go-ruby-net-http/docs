<p align="center"><img src="https://raw.githubusercontent.com/go-ruby-net-http/brand/main/social/go-ruby-net-http-net-http.png" alt="go-ruby-net-http/docs" width="720"></p>

# go-ruby-net-http/docs

Versioned documentation for [go-ruby-net-http](https://github.com/go-ruby-net-http),
built with [Hugo](https://gohugo.io/) and this fleet's [Hextra fork](https://github.com/tannevaled/hextra) — upstream Hextra plus the opt-in features the fleet's sites use. Published to the
`gh-pages` branch and served at <https://go-ruby-net-http.github.io/docs/>.

The organization landing page ([go-ruby-net-http.github.io](https://go-ruby-net-http.github.io))
links here.

## Local preview

```bash
git submodule update --init --recursive   # themes/hextra, pinned at a release tag
hugo server                               # http://localhost:1313
```

## Benchmarks

The offline, cross-runtime performance harness behind
[Performance](https://go-ruby-net-http.github.io/docs/performance/) lives under
[`benchmarks/`](benchmarks): a self-contained Go driver (`go/`, pinning the
published library by pseudo-version), the equivalent `ruby/net_http.rb` workload,
and `run.sh`. It measures only the network-free surface (message codec) and
proves every runtime's output byte-identical to the Go driver before timing.

```bash
OUTER=60 WARM=5 bash benchmarks/run.sh
```

## Releasing a new docs version

Each documented version is its own build under `/docs/<version>/`, and
`/docs/latest/` follows the newest — which is what `mike` did before. The version
comes from `params.docs.version` in `hugo.yaml`: set it to the release the pages
describe (`v0.16.0` → `/docs/0.16/`), or leave it at `main` while no release is
tagged. The `docs` workflow reads it, builds with that `--baseURL`, and replaces
**only** that version's path.

⛔ The build runs with `--panicOnWarning`, so a link to a page that is not there
fails the lane instead of 404ing for a reader.
