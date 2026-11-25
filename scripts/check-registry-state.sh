#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${EVIDENCE_DIR:-"$root/build/runtime-registry-evidence/state"}
mkdir -p "$out"
out=$(cd "$out" && pwd)
echo INCOMPLETE > "$out/result.txt"
work=$(mktemp -d)
trap 'status=$?; if ((status)); then echo FAIL > "$out/result.txt"; tail -n 35 "$out"/*.txt >&2; fi; rm -rf "$work"' EXIT
[[ $(zig version) == 0.15.2 ]]
cp -R "$root/src/interface/Abi" "$work/"
cp "$root/src/interface/RegistryStateOracle.idr" "$work/Main.idr"
cp "$root/src/interface/RegistryStateRunner.zig" "$work/runner.zig"
cp "$root/src/interface/ffi/src/registry_state.zig" "$work/"
(cd "$work"; sha256sum Main.idr Abi/*.idr *.zig) > "$out/inputs.sha256"
(cd "$work"; idris2 --total -Werror --codegen refc -o oracle Main.idr) > "$out/idris-build.txt" 2>&1
if grep -q '^Error:' "$out/idris-build.txt"; then exit 1; fi
(cd "$work"; printf ':m\n:q\n' | idris2 --no-banner Main.idr) > "$out/idris-holes.txt" 2>&1
grep -q 'No holes' "$out/idris-holes.txt"
if grep -q '^Error:' "$out/idris-holes.txt"; then exit 1; fi
"$work/build/exec/oracle" > "$out/contract.tsv"
[[ $(wc -l < "$out/contract.tsv") == 917 ]]
for mode in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
    zig build-exe "$work/runner.zig" -O "$mode" -femit-bin="$work/native" > "$out/build-$mode.txt" 2>&1
    "$work/native" > "$out/native-$mode.tsv"
    cmp "$out/contract.tsv" "$out/native-$mode.tsv"
done
cp "$work/registry_state.zig" "$work/original"
for mutation in frame busy restoration identity status; do
    case "$mutation" in
      frame) sed 's/.rest = s.rest, .mcp = endpoint/.rest = endpoint, .mcp = endpoint/' "$work/original" ;;
      busy) sed '/if (s.active)/d' "$work/original" ;;
      restoration) sed 's/return mark(E, s, false)/return mark(E, s, true)/' "$work/original" ;;
      identity) sed 's/.selected = endpoint/.selected = null/;s/const endpoint = get/_ = get/' "$work/original" ;;
      status) sed 's/status <= 11/status <= 12/' "$work/original" ;;
    esac > "$work/registry_state.zig"
    ! cmp -s "$work/original" "$work/registry_state.zig"
    zig build-exe "$work/runner.zig" -O ReleaseSafe -femit-bin="$work/mutant" > "$out/mutant-$mutation-build.txt" 2>&1
    "$work/mutant" > "$out/mutant-$mutation.tsv"
    if cmp -s "$out/contract.tsv" "$out/mutant-$mutation.tsv"; then echo "FAIL $mutation escaped"; exit 1; fi
done
cp "$work/original" "$work/registry_state.zig"
(cd "$work"; sha256sum -c "$out/inputs.sha256") > "$out/recheck.txt"
cp "$work/"*.zig "$out/"
cp "$work/Abi/RegistryState.idr" "$out/"
idris2 --version > "$out/idris-version.txt"
zig version > "$out/zig-version.txt"
echo PASS > "$out/result.txt"
echo 'REGISTRY PASS: 900 two-operation traces, 17 signed statuses, four modes, five compiled mutants'

