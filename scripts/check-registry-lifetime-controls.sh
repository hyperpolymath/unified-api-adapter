#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${EVIDENCE_DIR:-"$root/build/runtime-registry-evidence/lifetime-controls"}
mkdir -p "$out"; out=$(cd "$out" && pwd)
echo INCOMPLETE > "$out/result.txt"
work=$(mktemp -d)
trap 'status=$?; if ((status)); then echo FAIL > "$out/result.txt"; fi; rm -rf "$work"' EXIT
real_idris=$(command -v "${IDRIS2:-idris2}")
real_idris=$(cd "$(dirname "$real_idris")" && pwd)/$(basename "$real_idris")
cat > "$work/diagnostic-compiler" <<'SH'
#!/usr/bin/env bash
if [[ $1 == --version ]]; then exec "$REAL_IDRIS" "$@"; fi
printf 'Error: planted zero-exit compiler failure\n'
exit 0
SH
chmod +x "$work/diagnostic-compiler"
if REAL_IDRIS="$real_idris" IDRIS2="$work/diagnostic-compiler" EVIDENCE_DIR="$out/refused" \
  bash "$root/scripts/check-registry-lifetime.sh" > "$out/reject-diagnostic.txt" 2>&1; then
  echo 'FAIL: zero-exit lifetime compiler diagnostic accepted' >&2; exit 1
fi
grep -q 'FAIL: lifetime compiler diagnostics' "$out/reject-diagnostic.txt"
[[ $(cat "$out/refused/result.txt") == FAIL ]]
echo PASS > "$out/result.txt"
