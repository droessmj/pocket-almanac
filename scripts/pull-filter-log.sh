#!/bin/sh
# Copyright (c) 2026 Michael Droessler
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
set -eu
printf '%s\n' \
    'Sift no longer writes plaintext activity.jsonl diagnostic files.' \
    'Old copies are deleted when the updated filter next starts.' \
    'For storage errors, use the device Console with subsystem com.droessmj.sift and category ActivityLog.' \
    'Diagnostics contain status codes only; do not export real message metadata for support.'
