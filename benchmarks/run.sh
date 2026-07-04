#!/usr/bin/env bash
#
# Copyright (c) the go-ruby-* authors
# SPDX-License-Identifier: BSD-3-Clause
#
# Offline, library-level cross-runtime benchmark runner for go-ruby-net-http.
#
# Runs the SAME network-free workload (request serialization, response parsing +
# chunked decode, URI form building, header canonicalization) through (a) the
# pure-Go go-ruby-net-http/net-http codec (benchmarks/go) and (b) each available
# reference Ruby runtime (benchmarks/ruby/net_http.rb), and prints one Markdown
# table per sub-benchmark: ns/op and the ratio vs MRI.
#
# Before timing, it proves correctness: every runtime emits a sha256 CHECK of
# each op's output, and a runtime is only timed if its digests match the pure-Go
# driver's byte-for-byte. A mismatching runtime is skipped with a warning.
#
# Usage:  bash benchmarks/run.sh
# Env:    OUTER (timed passes, default 25), WARM (untimed passes, default 3),
#         RUBY / JRUBY / TRUFFLERUBY (override runtime binaries).
set -u
cd "$(dirname "$0")"
export GOWORK=off

RUBY=${RUBY:-ruby}
JRUBY=${JRUBY:-jruby}
TRUFFLERUBY=${TRUFFLERUBY:-truffleruby}

RB=$(ls ruby/*.rb | grep -v _harness | head -1)
TMP=$(mktemp)
GOCHECK=$(mktemp)
RTCHECK=$(mktemp)
trap 'rm -f "$TMP" "$GOCHECK" "$RTCHECK"' EXIT

echo "== go-ruby-net-http offline library benchmark ==" >&2

# --- reference digests from the pure-Go driver ------------------------------
( cd go && go run . verify ) 2>/dev/null | grep '^CHECK' | sort > "$GOCHECK"
if [ ! -s "$GOCHECK" ]; then
  echo "  ERROR: the Go driver produced no CHECK digests" >&2; exit 1
fi

# verified <label> <cmd...> : true iff the runtime's CHECK digests all match Go's.
verified() {
  local label=$1; shift
  "$@" verify 2>/dev/null | grep '^CHECK' | sort > "$RTCHECK"
  if [ ! -s "$RTCHECK" ]; then return 1; fi
  diff -q "$GOCHECK" "$RTCHECK" >/dev/null 2>&1
}

# time_go / run: append RESULT rows for a runtime, but only after CHECK passes.
echo "  go: verify + time ..." >&2
( cd go && go run . ) 2>/dev/null | awk '$1=="RESULT"{printf "go\t%s\t%s\n", $2, $3}' >> "$TMP"

run() { # <runtime-label> <cmd...>
  local label=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($label: $1 not found — skipped)" >&2; return; }
  if ! verified "$label" "$@" "$RB"; then
    echo "  ($label: output does NOT match the Go driver byte-for-byte — skipped)" >&2; return
  fi
  echo "  $label: verified, timing ..." >&2
  "$@" "$RB" 2>/dev/null | awk -v r="$label" '$1=="RESULT"{printf "%s\t%s\t%s\n", r, $2, $3}' >> "$TMP"
}

run "mri"         "$RUBY"
run "mri-yjit"    "$RUBY" --yjit
run "jruby"       "$JRUBY"
run "truffleruby" "$TRUFFLERUBY"

echo >&2
# Emit one Markdown table per sub-benchmark (label), runtimes as rows.
awk -F'\t' '
  { key=$2; rt=$1; ns=$3; labels[key]=1; val[rt SUBSEP key]=ns; rts[rt]=1 }
  END {
    order="go mri mri-yjit jruby truffleruby"
    n=split(order, ord, " ")
    ln=0; for (k in labels) lab[++ln]=k
    for (i=1;i<=ln;i++) for (j=i+1;j<=ln;j++) if (lab[j]<lab[i]){t=lab[i];lab[i]=lab[j];lab[j]=t}
    for (i=1;i<=ln;i++){
      k=lab[i]
      printf "\n#### %s\n\n", k
      print  "| Runtime | ns/op | vs MRI |"
      print  "| --- | ---: | ---: |"
      base=val["mri" SUBSEP k]
      for (o=1;o<=n;o++){
        rt=ord[o]; v=val[rt SUBSEP k]
        if (v=="") continue
        ratio=(base!=""&&base+0>0)? sprintf("%.2f×", v/base) : "—"
        name=rt
        if (rt=="go") name="**go-ruby-net-http (pure Go)**"
        else if (rt=="mri") name="MRI"
        else if (rt=="mri-yjit") name="MRI + YJIT"
        else if (rt=="jruby") name="JRuby"
        else if (rt=="truffleruby") name="TruffleRuby"
        printf "| %s | %s | %s |\n", name, v, ratio
      }
    }
  }
' "$TMP"
