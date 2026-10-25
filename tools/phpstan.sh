#!/usr/bin/env bash
# lightningcss-php — PHPStan entry point shared by composer and CI.
#
# The extension stub is loaded via scanFiles (its signatures carry empty
# bodies by design, and return.missing is non-ignorable), so PHPStan analyses
# runtime PHP only. Until the first runtime PHP file lands the gate passes
# with an explicit notice instead of failing on an empty analysis set — the
# activation set and the analysed set are the same enumerated list, so a
# nested file activates the gate exactly when PHPStan sees it.
# Copyright 2026 Fojle Rabbi (Rabib)
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for dir in tests tools examples; do
    [[ -d "$dir" ]] || continue
    find "$dir" -type f -name '*.php' ! -name gen_stub.php -print0 | sort -z >>"$tmp" || exit 1
done

files=()
while IFS= read -r -d '' f; do
    files+=("$f")
done <"$tmp"

if [ "${#files[@]}" -eq 0 ]; then
    echo "phpstan: no runtime PHP files yet; the gate runs from the first one"
    exit 0
fi

# exec replaces the process image, so the EXIT trap never fires on the
# success path; the list file is fully consumed above and is removed here.
rm -f "$tmp"
exec vendor/bin/phpstan analyse --no-progress "${files[@]}" "$@"
