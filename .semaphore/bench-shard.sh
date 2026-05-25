#!/usr/bin/env bash
# Emit one "pkg<TAB>bench-regex" line per package this shard should benchmark.
# Distributes individual Benchmark funcs across SEMAPHORE_JOB_COUNT shards
# so heavy packages (like the root) split across multiple agents.
set -u

idx="${SEMAPHORE_JOB_INDEX:-1}"
cnt="${SEMAPHORE_JOB_COUNT:-1}"

# Collect (pkg, benchname) tuples from all test files.
go list -f '{{if (or .TestGoFiles .XTestGoFiles)}}{{.ImportPath}} {{.Dir}}{{end}}' ./... |
while read -r pkg dir; do
  [ -z "$pkg" ] && continue
  grep -h -oE '^func (Benchmark[A-Za-z0-9_]+)' "$dir"/*_test.go 2>/dev/null |
    awk -v p="$pkg" '{print p"\t"$2}'
done |
# Round-robin tuples across shards. Sort by pkg first so heavy packages
# distribute evenly via index modulo.
sort |
awk -v idx="$idx" -v cnt="$cnt" 'NR % cnt == (idx - 1) {print}' |
# Group by package: pkg<TAB>name1|name2|...
awk -F'\t' '
  { pkg=$1; n=$2; if (pkg!=prev && prev!="") { print prev"\t"acc; acc="" }
    acc = (acc=="" ? n : acc"|"n); prev=pkg }
  END { if (prev!="") print prev"\t"acc }
'
