#!/usr/bin/env python3
"""Export real XCTest screenshots as opaque RGB PNG, without resizing."""
import argparse
import json
import pathlib
import subprocess
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--attachments', type=pathlib.Path, nargs='+', default=[pathlib.Path('build/store-assets/blotter/provenance/attachments')])
a = p.parse_args()
out = pathlib.Path('build/store-assets/blotter/screenshots/iphone')
out.mkdir(parents=True, exist_ok=True)
names = {
    '01-setup': '04-setup',
    '02-keywords': '01-keywords',
    '03-matching-options': '02-matching-options',
    '04-keywords-and-privacy-links': '03-rules-and-privacy',
}
provenance = {}
for directory in a.attachments:
    manifest = json.loads((directory / 'manifest.json').read_text())
    for test in manifest:
        for attachment in test['attachments']:
            stem = attachment['suggestedHumanReadableName'].split('_0_')[0].removeprefix('blotter-')
            if stem not in names:
                continue
            source = directory / attachment['exportedFileName']
            target = out / (names[stem] + '.png')
            subprocess.run(['/opt/homebrew/bin/ffmpeg', '-y', '-i', str(source), '-frames:v', '1', '-pix_fmt', 'rgb24', '-update', '1', str(target)], check=True)
            provenance[str(target)] = {'screenshot': str(target), 'source_attachment': str(source), 'timestamp': attachment['timestamp'], 'device_id': attachment['deviceId'], 'processing': 'Opaque RGB conversion only; native 1206x2622 pixels unchanged'}
(out / 'provenance.json').write_text(json.dumps(list(provenance.values()), indent=2) + '\n')
