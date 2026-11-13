#!/usr/bin/env python3
"""Validate generated submission media and create an upload-only ZIP and review gallery."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/store-assets'
SOURCES = {
    'creative': 'https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/',
    'screenshots': 'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/',
    'previews': 'https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/',
}


def png_size(path):
    with path.open('rb') as handle:
        header = handle.read(33)
    if header[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not PNG: {path}')
    width, height, depth, color = struct.unpack('>IIBB', header[16:26])
    if color not in (0, 2):
        raise ValueError(f'PNG must be opaque grayscale/RGB, not alpha or palette: {path}')
    return width, height


def inspect(path, expected_size=None):
    relative = path.relative_to(OUT).as_posix()
    item = {'path': relative, 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.suffix == '.png':
        size = png_size(path)
        if expected_size and size != expected_size:
            raise ValueError(f'Unexpected PNG dimensions {size}, expected {expected_size}: {path}')
        item['dimensions'] = size
    else:
        probe = json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)], text=True))
        video = next(stream for stream in probe['streams'] if stream['codec_type'] == 'video')
        audio = next(stream for stream in probe['streams'] if stream['codec_type'] == 'audio')
        duration = float(probe['format']['duration'])
        numerator, denominator = map(int, video['avg_frame_rate'].split('/'))
        if not (15 <= duration <= 30 and item['bytes'] < 500_000_000):
            raise ValueError(f'Invalid preview duration/size: {path}')
        if video['codec_name'] != 'h264' or video['pix_fmt'] != 'yuv420p' or video['level'] > 40:
            raise ValueError(f'Unexpected preview encoding: {path}')
        if (video['width'], video['height']) != (886, 1920) or numerator / denominator > 30:
            raise ValueError(f'Unexpected iPhone preview dimensions/frame rate: {path}')
        if audio['codec_name'] != 'aac' or audio['channels'] != 2 or int(audio['sample_rate']) not in (44100, 48000):
            raise ValueError(f'Unexpected preview audio: {path}')
        item.update(duration_seconds=duration, dimensions=[video['width'], video['height']], frames_per_second=numerator / denominator, video_codec='H.264', profile=video['profile'], level=video['level'], audio='AAC stereo; synthetic silence')
    return item


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--duo-status', choices=['blocked', 'deferred', 'complete'], default='blocked')
    args = parser.parse_args()
    assets = []
    sections = []
    for slug, title in [('day-in-ink', 'Day in Ink'), ('blotter', 'Blotter')]:
        base = OUT / slug
        header = base / 'creative/header.png'
        search = base / 'creative/search-results.png'
        screenshots = sorted((base / 'screenshots/iphone').glob('*.png'))
        movies = sorted((base / 'previews').glob('*.mp4'))
        posters = sorted((base / 'previews').glob('*poster.png'))
        if len(screenshots) < 3 or len(movies) != 1 or len(posters) != 1:
            raise ValueError(f'Incomplete iPhone output set for {slug}')
        files = [inspect(header, (3840, 1646)), inspect(search, (3840, 2560))]
        files += [inspect(path, (1206, 2622)) for path in screenshots]
        files += [inspect(path) for path in movies + posters]
        if args.duo_status == 'complete':
            for kind, size in [('duo-outer', (1398, 2034)), ('duo-inner', (2007, 2853))]:
                captures = sorted((base / 'screenshots' / kind).glob('*.png'))
                if not captures:
                    raise ValueError(f'Missing genuine {kind} capture for {slug}')
                files += [inspect(path, size) for path in captures]
        assets += files
        link = lambda path: html.escape(path.relative_to(OUT).as_posix(), quote=True)
        figures = ''.join(f'<figure><a href="{link(path)}"><img loading="lazy" src="{link(path)}" alt="{html.escape(path.stem)}"></a><figcaption>{html.escape(path.stem)}</figcaption></figure>' for path in screenshots)
        sections.append(f'''<section><h2>{title}</h2><div class="creative"><figure><a href="{link(header)}"><img src="{link(header)}" alt="{title} Header"></a><figcaption>Header · 3840 × 1646</figcaption></figure><figure><a href="{link(search)}"><img src="{link(search)}" alt="{title} Search Results"></a><figcaption>Search Results · 3840 × 2560</figcaption></figure></div><h3>App preview · iPhone</h3><video controls preload="metadata" poster="{link(posters[0])}" src="{link(movies[0])}"></video><p><a href="{link(movies[0])}" download>Download preview MP4</a> · 886 × 1920 · H.264, 30 fps · silent stereo AAC</p><h3>Screenshots · iPhone 18 Pro</h3><div class="screens">{figures}</div></section>''')
    report = {'locale': 'en-US', 'ipad': 'Skipped at user request; both production apps remain iPhone-only', 'duo': args.duo_status, 'duo_blocker': None if args.duo_status == 'complete' else 'Compatible iOS 27.2 runtime installation failed: insufficient space; Apple installer requires 8.34 GB. Installed iOS 27.0 is incompatible with iPhone Duo.', 'sources': SOURCES, 'artifacts': assets, 'warnings': ['Assets generated locally only; no App Store upload or Apple acceptance claimed.', 'All app captures use actual simulator UI with synthetic data.', 'Blotter simulator recordings do not demonstrate incoming SMS/MMS delivery or filtering.']}
    (OUT / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    status = 'Complete' if args.duo_status == 'complete' else f'{args.duo_status.title()}: compatible simulator runtime needs disk space'
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pocket Almanac · App Store Assets</title><style>:root{color-scheme:light dark}body{font:16px/1.5 system-ui,sans-serif;max-width:1280px;margin:auto;padding:32px;background:#14181f;color:#f0f3f8}h1,h2,h3{line-height:1.2}h1{font-size:40px}h2{font-size:30px;border-top:1px solid #435063;padding-top:28px}a{color:#a9ceff}p{max-width:80ch}.notice{padding:16px 20px;background:#242d3b;border-radius:12px}.creative{display:grid;grid-template-columns:1.5fr 1fr;gap:20px;align-items:start}figure{margin:0}img{width:100%;display:block;border-radius:10px}figcaption{font-size:14px;margin:8px 0 20px;color:#bdc8d8}.screens{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}video{width:300px;max-width:100%;border-radius:12px}section{margin-top:36px}@media(max-width:650px){body{padding:18px}h1{font-size:30px}.creative{grid-template-columns:1fr}.screens{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}}</style><h1>App Store assets</h1><p>English (U.S.) · Real app UI · Synthetic example data</p><p><a href="app-store-upload-assets.zip" download>Download upload-only ZIP</a> · <a href="verification.json">Verification and file inventory</a></p>'''
    document += f'<div class="notice"><strong>Device coverage</strong><br>iPhone: generated. iPhone Duo: {html.escape(status)}. iPad: omitted at your request; the apps remain iPhone-only.<br>Nothing has been uploaded to Apple. Blotter footage shows setup and keyword matching controls, not live SMS filtering.</div>'
    document += ''.join(sections)
    document += '<section><h2>Where to upload</h2><p>In each app’s App Store Connect record, use Header and Search Results for the matching creative PNGs. Under App Previews and Screenshots → iPhone with Dynamic Island (medium display), upload the iPhone MP4 and the ordered 1206 × 2622 PNGs. Select a poster frame from the video in App Store Connect; the provided poster image is a reference. Do not upload raw recordings, provenance, or capture test results.</p><p>Apple reviews assets; local dimensions and codec validation do not guarantee acceptance. Review the artwork in App Store Connect’s placement preview before submitting.</p></section></html>'
    (OUT / 'index.html').write_text(document)
    with zipfile.ZipFile(OUT / 'app-store-upload-assets.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for asset in assets:
            archive.write(OUT / asset['path'], asset['path'])
    print(json.dumps({'validated_assets': len(assets), 'zip': str(OUT / 'app-store-upload-assets.zip'), 'gallery': str(OUT / 'index.html'), 'duo': args.duo_status}, indent=2))


if __name__ == '__main__':
    main()
