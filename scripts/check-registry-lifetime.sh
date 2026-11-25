#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${EVIDENCE_DIR:-"$root/build/runtime-registry-evidence/lifetime"}
mkdir -p "$out"; out=$(cd "$out" && pwd)
echo INCOMPLETE > "$out/result.txt"
work=$(mktemp -d)
trap 'status=$?; if ((status)); then echo FAIL > "$out/result.txt"; tail -n 35 "$out"/*.txt >&2; fi; rm -rf "$work"' EXIT
idris=$(command -v "${IDRIS2:-idris2}")
idris=$(cd "$(dirname "$idris")" && pwd)/$(basename "$idris")
zig=$(command -v "${ZIG:-zig}")
zig=$(cd "$(dirname "$zig")" && pwd)/$(basename "$zig")
[[ $("$idris" --version) == 'Idris 2, version 0.8.0-b6cbc25d5' ]]
[[ $("$zig" version) == 0.15.2 ]]
(cd "$root"; sha256sum src/interface/Abi/*.idr \
  src/interface/ffi/src/{registry,registry_state,protocol_tag}.zig \
  src/interface/RegistryLifetimeTests.zig scripts/check-registry-lifetime.sh) > "$out/inputs.sha256"
mkdir -p "$work/src/interface/ffi/src" "$work/scripts"
cp -R "$root/src/interface/Abi" "$work/src/interface/"
cp "$root/src/interface/ffi/src/"{registry,registry_state,protocol_tag}.zig "$work/src/interface/ffi/src/"
cp "$root/src/interface/RegistryLifetimeTests.zig" "$work/src/interface/"
cp "$root/scripts/check-registry-lifetime.sh" "$work/scripts/"
(cd "$work"; sha256sum -c "$out/inputs.sha256") > "$out/snapshot-recheck.txt"
interface="$work/src/interface"
(cd "$interface"; "$idris" --total -Werror --check Abi/RegistryLifetime.idr) > "$out/idris.txt" 2>&1
if grep -q '^Error:' "$out/idris.txt"; then echo 'FAIL: lifetime compiler diagnostics' >&2; exit 1; fi
(cd "$interface"; printf ':m\n:q\n' | "$idris" --no-banner Abi/RegistryLifetime.idr) > "$out/holes.txt" 2>&1
grep -q 'No holes' "$out/holes.txt"
if grep -q '^Error:' "$out/holes.txt"; then echo 'FAIL: lifetime hole-check diagnostics' >&2; exit 1; fi
for kind in Retained Borrowed; do
  counts='1 0'; [[ $kind != Borrowed ]] || counts='0 1'
  cat > "$interface/Bad$kind.idr" <<IDRIS
module Bad$kind
import Abi.RegistryLifetime
%default total
bad : (f : (1 payload : resource) -> ()) -> (1 permit : Permit resource $counts) -> ()
bad f permit = release f permit
IDRIS
  (cd "$interface"; "$idris" --total -Werror --check "Bad$kind.idr") > "$out/reject-$kind.txt" 2>&1 || true
  grep -q '^Error:' "$out/reject-$kind.txt"
  grep -q 'Mismatch between' "$out/reject-$kind.txt"
  grep -q "Bad$kind" "$out/reject-$kind.txt"
done
for mode in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
  "$zig" test "$interface/RegistryLifetimeTests.zig" -lc -O "$mode" > "$out/native-$mode.txt" 2>&1
done
cp "$interface/ffi/src/registry.zig" "$work/registry-original.zig"
cp "$interface/ffi/src/registry_state.zig" "$work/state-original.zig"
for mutant in busy-destroy detach preserve-other; do
  cp "$work/registry-original.zig" "$interface/ffi/src/registry.zig"
  cp "$work/state-original.zig" "$interface/ffi/src/registry_state.zig"
  case "$mutant" in
    busy-destroy)
      awk '/pub export fn uaa_registry_destroy/{inside=1} inside && /if \(registry.active\) return 6;/{sub("return 6;", "return 0;"); inside=0} {print}' \
        "$work/registry-original.zig" > "$interface/ffi/src/registry.zig"
      if cmp -s "$work/registry-original.zig" "$interface/ffi/src/registry.zig"; then exit 1; fi ;;
    detach)
      sed 's/\.next = put(E, s, slot, null)/.next = s/' "$work/state-original.zig" > "$interface/ffi/src/registry_state.zig"
      if cmp -s "$work/state-original.zig" "$interface/ffi/src/registry_state.zig"; then exit 1; fi ;;
    preserve-other)
      sed 's/\.next = put(E, s, slot, null)/.next = .{}/' "$work/state-original.zig" > "$interface/ffi/src/registry_state.zig"
      if cmp -s "$work/state-original.zig" "$interface/ffi/src/registry_state.zig"; then exit 1; fi ;;
  esac
  "$zig" test "$interface/RegistryLifetimeTests.zig" -lc -O ReleaseSafe --test-no-exec -femit-bin="$work/mutant" > "$out/build-$mutant.txt" 2>&1
  if "$work/mutant" > "$out/reject-$mutant.txt" 2>&1; then echo "FAIL $mutant escaped" >&2; exit 1; fi
  grep -E 'TestUnexpectedResult|TestExpectedEqual' "$out/reject-$mutant.txt" >/dev/null
done
cp "$work/registry-original.zig" "$interface/ffi/src/registry.zig"
cp "$work/state-original.zig" "$interface/ffi/src/registry_state.zig"
(cd "$work"; sha256sum -c "$out/inputs.sha256") > "$out/checked-input-recheck.txt"
(cd "$root"; sha256sum -c "$out/inputs.sha256") > "$out/input-recheck.txt"
cp "$interface/RegistryLifetimeTests.zig" "$interface/Abi/RegistryLifetime.idr" "$out/"
echo PASS > "$out/result.txt"
echo 'LIFETIME PILOT PASS: retained/read permission refusals and actual native lifecycle; caller pointer/lifetime premises remain'
