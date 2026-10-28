#!/bin/sh
# Prints activity entries the filter couldn't write to the shared keychain (fallback copies in
# the extension's own container, each with its keychain error). Requires a USB-connected iPhone.
# Copyright (c) 2026 Michael Droessler
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
set -eu
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEVICE="${1:-$(xcrun devicectl list devices | awk '/connected/ {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i; exit}')}"
OUT="${TMPDIR:-/tmp}/sift-filter-activity.jsonl"
rm -f "$OUT"
xcrun devicectl device copy from --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier com.droessmj.sift.filter \
    --source Documents/activity.jsonl --destination "$OUT" >/dev/null
cat "$OUT"
