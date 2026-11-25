#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${EVIDENCE_DIR:-"$root/build/runtime-registry-evidence/ownership"}
mkdir -p "$out"; out=$(cd "$out" && pwd)
echo INCOMPLETE > "$out/result.txt"
work=$(mktemp -d)
trap 'status=$?; if ((status)); then echo FAIL > "$out/result.txt"; tail -n 40 "$out"/*.txt >&2; fi; rm -rf "$work"' EXIT
idris=$(command -v "${IDRIS2:-idris2}")
idris=$(cd "$(dirname "$idris")" && pwd)/$(basename "$idris")
zig=$(command -v "${ZIG:-zig}")
zig=$(cd "$(dirname "$zig")" && pwd)/$(basename "$zig")
[[ $("$idris" --version) == 'Idris 2, version 0.8.0-b6cbc25d5' ]]
[[ $("$zig" version) == 0.15.2 ]]
mkdir -p "$work/ffi/src"
cp "$root/src/interface/ffi/src/"{registry,registry_state,protocol_tag}.zig "$work/ffi/src/"
cp "$root/src/interface/RegistryOwnershipTests.zig" "$work/"
cp -R "$root/src/interface/Abi" "$work/"
(cd "$work"; "$idris" --total -Werror --check Abi/RegistryOwnership.idr) > "$out/idris.txt" 2>&1
if grep -q '^Error:' "$out/idris.txt"; then echo 'FAIL: ownership compiler diagnostics' >&2; exit 1; fi
(cd "$work"; printf ':m\n:q\n' | "$idris" --no-banner Abi/RegistryOwnership.idr) > "$out/holes.txt" 2>&1
grep -q 'No holes' "$out/holes.txt"
if grep -q '^Error:' "$out/holes.txt"; then echo 'FAIL: ownership hole-check diagnostics' >&2; exit 1; fi
cat > "$work/BadLease.idr" <<'IDRIS'
module BadLease
import Abi.RegistryOwnership
%default total
duplicate : (1 owner : Lease endpoint Idle) -> (Lease endpoint Idle, Lease endpoint Idle)
duplicate owner = (owner, owner)
IDRIS
(cd "$work"; "$idris" --total -Werror --check BadLease.idr) > "$out/reject-duplicate.txt" 2>&1 || true
grep -q '^Error:' "$out/reject-duplicate.txt"
grep -Ei 'linear|multiplicity|more than once|non-linear' "$out/reject-duplicate.txt" >/dev/null
# The public module hides constructors. Also expose ONLY a private scratch copy
# to show the real linear payload rejects destruct-and-reconstruct duplication.
mkdir "$work/exposed"
cp -R "$work/Abi" "$work/exposed/"
sed 's/^export$/public export/' "$work/Abi/RegistryOwnership.idr" > "$work/exposed/Abi/RegistryOwnership.idr"
cat > "$work/exposed/BadReconstruct.idr" <<'IDRIS'
module BadReconstruct
import Abi.RegistryOwnership
%default total
duplicate : (1 owner : Lease resource Idle) -> (Lease resource Idle, Lease resource Idle)
duplicate (IdleLease payload) = (IdleLease payload, IdleLease payload)
IDRIS
(cd "$work/exposed"; "$idris" --total -Werror --check BadReconstruct.idr) > "$out/reject-reconstruct.txt" 2>&1 || true
grep -q '^Error:' "$out/reject-reconstruct.txt"
grep -Ei 'linear|multiplicity|more than once|non-linear' "$out/reject-reconstruct.txt" >/dev/null
grep -q 'BadReconstruct' "$out/reject-reconstruct.txt"
for mode in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
  "$zig" test "$work/RegistryOwnershipTests.zig" -lc -O "$mode" > "$out/native-$mode.txt" 2>&1
done
cp "$work/ffi/src/registry.zig" "$work/original.zig"
for mutant in cleanup context callback guard; do
  case "$mutant" in
    cleanup) sed '/defer registry\.\* = state.finish/d' "$work/original.zig" ;;
    context) sed 's/endpoint.callback(endpoint.context, bytes, len)/endpoint.callback(null, bytes, len)/' "$work/original.zig" ;;
    callback) sed 's/endpoint.callback(endpoint.context, bytes, len)/(registry.rest orelse return 11).callback(endpoint.context, bytes, len)/' "$work/original.zig" ;;
    guard) sed '/if (bytes == null and len != 0) return 4;/d' "$work/original.zig" ;;
  esac > "$work/ffi/src/registry.zig"
  if cmp -s "$work/original.zig" "$work/ffi/src/registry.zig"; then echo 'FAIL: unchanged mutant' >&2; exit 1; fi
  "$zig" test "$work/RegistryOwnershipTests.zig" -lc -O ReleaseSafe --test-no-exec -femit-bin="$work/mutant" > "$out/build-$mutant.txt" 2>&1
  if "$work/mutant" > "$out/reject-$mutant.txt" 2>&1; then echo "FAIL $mutant escaped" >&2; exit 1; fi
  grep -E 'TestUnexpectedResult|TestExpectedEqual' "$out/reject-$mutant.txt" >/dev/null
done
cp "$work/original.zig" "$work/ffi/src/registry.zig"
(cd "$work"; sha256sum Abi/*.idr ffi/src/*.zig RegistryOwnershipTests.zig) > "$out/inputs.sha256"
cp "$work/Abi/RegistryOwnership.idr" "$work/RegistryOwnershipTests.zig" "$out/"
echo PASS > "$out/result.txt"
echo 'OWNERSHIP PILOT PASS: linear protocol, normal-return fixtures, alias counterexample and compiled controls; pointer premises remain'
