<p align="center"><img src="https://raw.githubusercontent.com/go-ruby-net-http/brand/main/social/go-ruby-net-http-net-http.png" alt="go-ruby-net-http/docs" width="720"></p>

# go-ruby-net-http/docs

Versioned documentation for [go-ruby-net-http](https://github.com/go-ruby-net-http),
built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and
versioned with [mike](https://github.com/jimporter/mike). Published to the
`gh-pages` branch and served at <https://go-ruby-net-http.github.io/docs/>.

The organization landing page ([go-ruby-net-http.github.io](https://go-ruby-net-http.github.io))
links here.

## Local preview

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
mkdocs serve                       # http://localhost:8000 (current sources)
mike serve                         # preview the versioned site
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

```bash
mike deploy --push --update-aliases <version> latest
mike set-default --push latest
```
