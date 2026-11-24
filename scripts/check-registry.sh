#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
idris=${IDRIS2:-idris2}
command -v "$idris" >/dev/null
evidence=${EVIDENCE_DIR:-"$root/build/registry-evidence"}
mkdir -p "$evidence"
evidence=$(cd "$evidence" && pwd)
rm -f "$evidence/result.txt"
work=$(mktemp -d -t uapi-registry-check.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/Abi"
for module in Protocol ProtocolFinite Status Registry; do
  cp "$root/src/interface/Abi/$module.idr" "$work/Abi/"
done
cp "$root/src/interface/RegistryCheck.idr" "$work/"
cp "$root/src/interface/ProtocolTagOracle.idr" "$work/Main.idr"
(cd "$work"; sha256sum Abi/*.idr RegistryCheck.idr Main.idr) > "$evidence/inputs.sha256"
(cd "$work"; "$idris" --total -Werror --codegen refc -o registry-check RegistryCheck.idr) > "$evidence/build.log" 2>&1
if grep -q '^Error:' "$evidence/build.log"; then cat "$evidence/build.log" >&2; exit 1; fi
test -x "$work/build/exec/registry-check"
(cd "$work"; printf ':m\n:q\n' | "$idris" --no-banner RegistryCheck.idr) > "$evidence/holes.log" 2>&1
grep -q 'No holes' "$evidence/holes.log"
if grep -q '^Error:' "$evidence/holes.log"; then cat "$evidence/holes.log" >&2; exit 1; fi
"$work/build/exec/registry-check" | tee "$evidence/registry.log"
grep '^case,' "$evidence/registry.log" > "$evidence/idris-oracle.csv"
test "$(wc -l < "$evidence/idris-oracle.csv")" -eq 1024

# The scalar oracle consumes the authoritative decoder in the same fresh profile.
(cd "$work"; "$idris" --total -Werror --codegen refc -o tag-oracle Main.idr) > "$evidence/tag-build.log" 2>&1
if grep -q '^Error:' "$evidence/tag-build.log"; then cat "$evidence/tag-build.log" >&2; exit 1; fi
test -x "$work/build/exec/tag-oracle"
(cd "$work"; printf ':m\n:q\n' | "$idris" --no-banner Main.idr) > "$evidence/tag-holes.log" 2>&1
grep -q 'No holes' "$evidence/tag-holes.log"
if grep -q '^Error:' "$evidence/tag-holes.log"; then cat "$evidence/tag-holes.log" >&2; exit 1; fi
"$work/build/exec/tag-oracle" > "$evidence/tag-oracle.tsv"
awk 'NF != 2 || $1 != NR-1 || $2 != (NR >= 2 && NR <= 10 ? 1 : 0) {exit 1}
     END {if (NR != 256) exit 1}' "$evidence/tag-oracle.tsv"

# Mutate the actual decoder: unknown values must not turn into REST.
sed -i 's/)))))))))) = Nothing/)))))))))) = Just REST/' "$work/Abi/ProtocolFinite.idr"
if (cd "$work"; "$idris" --total -Werror --check Abi/ProtocolFinite.idr) > "$evidence/reject.log" 2>&1; then
  # Idris versions that report errors with exit zero still fail this gate.
  grep -q '^Error:' "$evidence/reject.log" || { echo 'FAIL: reverse-decoding proof accepted mutant' >&2; exit 1; }
fi
grep -q 'finiteDecodeSound' "$evidence/reject.log"
{
  "$idris" --version
  cat "$evidence/inputs.sha256"
} > "$evidence/identity.log"
echo PASS > "$evidence/result.txt"
printf 'PASS: total proof modules, no holes, executable matrix, rejecting decoder mutation.\nEvidence: %s\n' "$evidence"

