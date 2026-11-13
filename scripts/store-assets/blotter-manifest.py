#!/usr/bin/env python3
"""Refresh Blotter machine-readable artifact inventory after capture/conversion."""
import hashlib
import json
import pathlib
root = pathlib.Path('build/store-assets/blotter')
for folder in ['screenshots/iphone', 'previews', 'creative']:
    (root / folder).mkdir(parents=True, exist_ok=True)
files = []
for path in sorted(root.rglob('*')):
    if not path.is_file() or path.suffix.lower() not in {'.png', '.mp4', '.mov'}:
        continue
    if any(part.endswith(('.xcresult', '.app', '.xctest')) for part in path.parts) or 'capture-derived' in path.parts:
        continue
    relative = str(path.relative_to(root))
    role = 'provenance' if relative.startswith('provenance/') or path.suffix.lower() == '.mov' else 'deliverable'
    files.append({'path': relative, 'role': role, 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'source': 'Actual app UI captured from dedicated simulator' if not relative.startswith('creative/') else 'AppKit-rendered indigo/teal artwork with original app icon'})
manifest = {
    'app': 'Blotter', 'bundle_identifier': 'com.droessmj.blotter',
    'production_device_family': 'iPhone only; production app/project unmodified',
    'capture_coverage': {'iphone': 'included', 'ipad': 'skipped at user request', 'duo_outer': 'deferred with user approval; compatible runtime download required 8.34 GB unavailable disk', 'duo_inner': 'deferred with user approval; compatible runtime download required 8.34 GB unavailable disk'},
    'synthetic_keywords': ['prize claim', 'limited offer', 'vote', 'cash reward', 'special promotion', 'bonus offer'],
    'simulators': {'iphone': '20D92C22-04DD-446B-A925-17264DB38272'},
    'capture_source': 'scripts/store-assets/blotter-capture.swift',
    'isolated_capture_project': 'scripts/store-assets/blotter-capture.yml',
    'capture_results': {'initial': 'provenance/iphone-capture.xcresult', 'final_options': 'provenance/iphone-final-capture.xcresult', 'final_options_result': 'Passed, reported by parent capture owner'},
    'screenshot_order': ['screenshots/iphone/01-keywords.png', 'screenshots/iphone/02-matching-options.png', 'screenshots/iphone/03-rules-and-privacy.png', 'screenshots/iphone/04-setup.png'],
    'export_command': 'python3 scripts/store-assets/blotter-export.py --attachments build/store-assets/blotter/provenance/attachments build/store-assets/blotter/provenance/final-attachments',
    'render_command': 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift scripts/store-assets/blotter-render.swift',
    'manifest_command': 'python3 scripts/store-assets/blotter-manifest.py',
    'preview_command': 'python3 scripts/store-assets/blotter-preview.py --raw build/store-assets/blotter/previews/raw-final.mov --start 19.9 --duration 23.5 --kind iphone',
    'creative_specifications': {'header': {'size': [3840, 1646], 'safe_rect': [1097, 493, 1646, 661]}, 'search-results': {'size': [3840, 2560], 'safe_rect': [836, 765, 2168, 1030]}, 'alpha': 'Opaque RGB'},
    'sources': ['https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/', 'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/', 'https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/'],
    'warnings': ['Simulator captures show setup and keyword/options interaction, not incoming message delivery or proof of filtering.', 'No fabricated incoming SMS or Junk messages.', 'App must be enabled separately in iPhone Settings.', 'iPad capture omitted at user request; app supports iPhone only.', 'Duo outer and inner media explicitly deferred with user approval because compatible runtime download lacked sufficient disk space.'],
    'artifacts': files
}
(root / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
