#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
set -euo pipefail
unset CDPATH
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
zig=$(command -v "${ZIG:-zig}")
zig=$(cd "$(dirname "$zig")" && pwd)/$(basename "$zig")
test "$("$zig" version)" = 0.15.2
evidence="$root/build/runtime-registry-evidence"
mkdir -p "$evidence"
echo INCOMPLETE > "$evidence/result.txt"
work=$(mktemp -d -t uaa-runtime-registry.XXXXXXXX)
trap 'status=$?; rm -rf -- "$work"; if ((status)); then echo FAIL > "$evidence/result.txt"; fi' EXIT
# Rebuild the Idris oracle in this invocation: a prior PASS cannot rescue it.
bash "$root/scripts/check-registry.sh" > "$evidence/idris.log" 2>&1
cp "$root/build/registry-evidence/idris-oracle.csv" "$work/oracle.csv"
cp "$root/src/interface/ffi/src/registry.zig" "$work/registry.zig"
cp "$root/src/interface/ffi/include/uaa_registry.h" "$work/uaa_registry.h"
cp "$root/src/interface/ffi/test/registry_caller.c" "$work/caller.c"
(cd "$work"; sha256sum registry.zig uaa_registry.h caller.c oracle.csv) > "$evidence/inputs.sha256"
"$zig" version > "$evidence/zig-version.txt"
build() {
  "$zig" build-lib -dynamic -lc -O ReleaseSafe "$work/registry.zig" -femit-bin="$work/libuaa_registry.so"
  "$zig" cc -Wall -Wextra -Werror -I "$work" "$work/caller.c" -L "$work" -luaa_registry \
    -Wl,-rpath,"$work" -o "$work/caller"
}
build > "$evidence/build.log" 2>&1
"$work/caller" > "$evidence/actual.csv"
cmp "$work/oracle.csv" "$evidence/actual.csv"
cp "$work/oracle.csv" "$evidence/expected.csv"
# An actual Zig decoder mutation must compile and be rejected at execution.
sed -i 's/if (!known(tag)) return 2;/if (!known(tag)) return 11;/' "$work/registry.zig"
build > "$evidence/mutant-build.log" 2>&1
if "$work/caller" > "$evidence/mutant.csv" 2> "$evidence/mutant.log"; then
  if cmp -s "$work/oracle.csv" "$evidence/mutant.csv"; then
    echo 'FAIL: unknown-tag mutation escaped the oracle' >&2; exit 1
  fi
fi
echo PASS > "$evidence/result.txt"
echo 'PASS: real C ABI, Idris differential matrix, lifetime/refusal regressions and rejecting Zig mutant'
