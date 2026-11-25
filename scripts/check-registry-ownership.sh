#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${EVIDENCE_DIR:-"$root/build/runtime-registry-evidence/ownership"}
mkdir -p "$out"; out=$(cd "$out" && pwd)
echo INCOMPLETE > "$out/result.txt"
work=$(mktemp -d)
trap 'status=$?; if ((status)); then echo FAIL > "$out/result.txt"; tail -n 40 "$out"/*.txt >&2; fi; rm -rf "$work"' EXIT
[[ $(zig version) == 0.15.2 ]]
mkdir -p "$work/ffi/src"
cp "$root/src/interface/ffi/src/"{registry,registry_state,protocol_tag}.zig "$work/ffi/src/"
cp "$root/src/interface/RegistryOwnershipTests.zig" "$work/"
cp -R "$root/src/interface/Abi" "$work/"
(cd "$work"; idris2 --total -Werror --check Abi/RegistryOwnership.idr) > "$out/idris.txt" 2>&1
! grep -q '^Error:' "$out/idris.txt"
(cd "$work"; printf ':m\n:q\n' | idris2 --no-banner Abi/RegistryOwnership.idr) > "$out/holes.txt" 2>&1
grep -q 'No holes' "$out/holes.txt"
! grep -q '^Error:' "$out/holes.txt"
cat > "$work/BadLease.idr" <<'IDRIS'
module BadLease
import Abi.RegistryOwnership
%default total
duplicate : (1 owner : Lease endpoint Idle) -> (Lease endpoint Idle, Lease endpoint Idle)
duplicate owner = (owner, owner)
IDRIS
(cd "$work"; idris2 --total -Werror --check BadLease.idr) > "$out/reject-duplicate.txt" 2>&1 || true
grep -q '^Error:' "$out/reject-duplicate.txt"
grep -Ei 'linear|multiplicity|more than once|non-linear' "$out/reject-duplicate.txt" >/dev/null
for mode in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
  zig test "$work/RegistryOwnershipTests.zig" -lc -O "$mode" > "$out/native-$mode.txt" 2>&1
done
cp "$work/ffi/src/registry.zig" "$work/original.zig"
for mutant in cleanup context guard; do
  case "$mutant" in
    cleanup) sed '/defer registry\.\* = state.finish/d' "$work/original.zig" ;;
    context) sed 's/endpoint.callback(endpoint.context, bytes, len)/endpoint.callback(null, bytes, len)/' "$work/original.zig" ;;
    guard) sed '/if (bytes == null and len != 0) return 4;/d' "$work/original.zig" ;;
  esac > "$work/ffi/src/registry.zig"
  ! cmp -s "$work/original.zig" "$work/ffi/src/registry.zig"
  zig test "$work/RegistryOwnershipTests.zig" -lc -O ReleaseSafe --test-no-exec -femit-bin="$work/mutant" > "$out/build-$mutant.txt" 2>&1
  if "$work/mutant" > "$out/reject-$mutant.txt" 2>&1; then echo "FAIL $mutant escaped" >&2; exit 1; fi
  grep -E 'TestUnexpectedResult|TestExpectedEqual' "$out/reject-$mutant.txt" >/dev/null
done
cp "$work/original.zig" "$work/ffi/src/registry.zig"
(cd "$work"; sha256sum Abi/*.idr ffi/src/*.zig RegistryOwnershipTests.zig) > "$out/inputs.sha256"
cp "$work/Abi/RegistryOwnership.idr" "$work/RegistryOwnershipTests.zig" "$out/"
echo PASS > "$out/result.txt"
echo 'OWNERSHIP PILOT PASS: linear protocol, normal-return fixtures, alias counterexample and compiled controls; pointer premises remain'
