#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
set -euo pipefail
unset CDPATH
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
evidence="$root/build/runtime-registry-evidence"
mkdir -p "$evidence"
echo INCOMPLETE > "$evidence/result.txt"
work=$(mktemp -d -t uaa-runtime-registry.XXXXXXXX)
finish() {
  local status=$?
  # Preserve a failed fresh oracle's diagnostics before deleting its directory.
  if [[ -d "$work/idris-evidence" ]]; then cp -R "$work/idris-evidence" "$evidence/"; fi
  rm -rf -- "$work"
  if ((status)); then echo FAIL > "$evidence/result.txt"; fi
}
trap finish EXIT
zig=$(command -v "${ZIG:-zig}")
zig=$(cd "$(dirname "$zig")" && pwd)/$(basename "$zig")
test "$("$zig" version)" = 0.15.2
# Rebuild and consume the oracle in the same private directory. An inherited
# EVIDENCE_DIR or a stale default oracle must not change the inputs to this run.
EVIDENCE_DIR="$work/idris-evidence" bash "$root/scripts/check-registry.sh" > "$evidence/idris.log" 2>&1
test "$(cat "$work/idris-evidence/result.txt")" = PASS
cp "$work/idris-evidence/idris-oracle.csv" "$work/oracle.csv"
cp -R "$work/idris-evidence" "$evidence/"
mkdir -p "$work/src" "$work/include" "$work/test"
cp "$root/src/interface/ffi/build.zig" "$work/"
cp "$root/src/interface/ffi/src/registry.zig" "$work/src/"
cp "$root/src/interface/ffi/src/protocol_tag.zig" "$work/src/"
cp "$root/src/interface/ffi/src/main.zig" "$work/src/"
cp "$root/src/interface/ffi/include/uaa_registry.h" "$work/include/"
cp "$root/src/interface/ffi/test/registry_caller.c" "$work/test/"
cp "$root/src/interface/ffi/test/integration_test.zig" "$work/test/"
(cd "$work"; sha256sum build.zig src/*.zig include/*.h test/* oracle.csv) > "$evidence/inputs.sha256"
"$zig" version > "$evidence/zig-version.txt"
build() {
  (cd "$work"; "$zig" build -Doptimize=ReleaseSafe)
  "$zig" cc -Wall -Wextra -Werror -I "$work/zig-out/include" "$work/test/registry_caller.c" \
    -L "$work/zig-out/lib" -luaa_registry -Wl,-rpath,"$work/zig-out/lib" -o "$work/caller"
}
build > "$evidence/build.log" 2>&1
"$work/caller" > "$evidence/actual.csv"
cmp "$work/oracle.csv" "$evidence/actual.csv"
cp "$work/oracle.csv" "$evidence/expected.csv"
# An actual Zig decoder mutation must compile and be rejected at execution.
sed -i 's/if (!known(tag)) return 2;/if (!known(tag)) return 11;/' "$work/src/registry.zig"
build > "$evidence/mutant-build.log" 2>&1
if "$work/caller" > "$evidence/mutant.csv" 2> "$evidence/mutant.log"; then
  if cmp -s "$work/oracle.csv" "$evidence/mutant.csv"; then
    echo 'FAIL: unknown-tag mutation escaped the oracle' >&2; exit 1
  fi
fi
echo PASS > "$evidence/result.txt"
echo 'PASS: real C ABI, Idris differential matrix, lifetime/refusal regressions and rejecting Zig mutant'
