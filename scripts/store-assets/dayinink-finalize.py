#!/usr/bin/env python3
"""Process real captures without stretching and write provenance manifests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/store-assets/day-in-ink'
FFMPEG = '/opt/homebrew/bin/ffmpeg'
FFPROBE = '/opt/homebrew/bin/ffprobe'


def probe(path):
    return json.loads(subprocess.check_output([FFPROBE, '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)], text=True))


def render(kind):
    screenshots = OUT / 'screenshots' / kind
    preview = OUT / 'previews' if kind == 'iphone' else OUT / 'previews' / kind
    for path in sorted(screenshots.glob('*.png')):
        with Image.open(path) as image:
            image.convert('RGB').save(path, optimize=True)
    raw = preview / 'raw-interaction.mov'
    metadata = probe(raw)
    duration = float(metadata['format']['duration'])
    if duration < 15:
        raise SystemExit('Actual recording shorter than the required 15 seconds; no still-frame extension is allowed')
    length = min(duration - .15, 29.5)
    width, height = 886, 1920
    movie = preview / 'app-preview.mp4'
    vf = f'scale={width}:{height}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=0xF4F0E7,setsar=1,fps=30,format=yuv420p'
    subprocess.run([FFMPEG, '-y', '-i', str(raw), '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000', '-t', str(length), '-map', '0:v:0', '-map', '1:a:0', '-vf', vf, '-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-c:a', 'aac_at', '-aac_at_mode', 'cbr', '-b:a', '256k', '-ar', '48000', '-ac', '2', '-movflags', '+faststart', str(movie)], check=True)
    poster = preview / 'poster.png'
    subprocess.run([FFMPEG, '-y', '-ss', '3', '-i', str(movie), '-frames:v', '1', '-update', '1', str(poster)], check=True)
    with Image.open(poster) as image:
        image.convert('RGB').save(poster, optimize=True)
    (preview / 'encoding-provenance.json').write_text(json.dumps(dict(rawSource=str(raw.relative_to(ROOT)), rawMetadata=metadata, output=str(movie.relative_to(ROOT)), durationSeconds=length, dimensions=[width,height], fps=30, videoCodec='H.264 High profile level 4.0', audio='AAC 256k CBR stereo synthetic silence via AudioToolbox (the app has no audio)', filter=vf, edit='Continuous real interaction recording; only end trim to maximum 29.5 seconds; no slide sequence or fabricated UI', screenshotProcessing='RGB conversion only; native dimensions retained'), indent=2)+'\n')


def manifest():
    assets = []
    for path in sorted(OUT.rglob('*')):
        if not path.is_file() or path.name == 'manifest.json' or '.xcresult' in str(path):
            continue
        if path.suffix.lower() not in ['.png','.mp4','.mov','.json']:
            continue
        item = dict(path=str(path.relative_to(OUT)), bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        if path.suffix == '.png':
            with Image.open(path) as image:
                item.update(dimensions=list(image.size), colorMode=image.mode)
        if path.suffix in ['.mov','.mp4']:
            info = probe(path)
            item.update(media=info)
        assets.append(item)
    data = dict(
        app='Day in Ink', bundleIdentifier='com.droessmj.dayinink',
        supportedDevices='iPhone only; production platform configuration unchanged',
        deliveryScope=dict(iphone='complete', duo='deferred by explicit user approval after compatible runtime download failed for insufficient disk space', ipad='skipped by explicit user decision'),
        sourceScripts=['scripts/store-assets/dayinink-capture.py','scripts/store-assets/dayinink-capture/DayInInkCapture.swift','scripts/store-assets/dayinink-capture/project.yml','scripts/store-assets/dayinink-render.py','scripts/store-assets/dayinink-finalize.py'],
        dependencies=dict(python='/usr/bin/python3 (Python 3.9.6)', pillow='11.3.0 user-site installation; install with /usr/bin/python3 -m pip install --user Pillow==11.3.0', ffmpeg='/opt/homebrew/bin/ffmpeg; libx264 and AudioToolbox aac_at required', developerDirectory='/Applications/Xcode.app/Contents/Developer'),
        captureMethod='XCTest controls the installed shipping UI; localhost coordinator invokes xcrun simctl io screenshot / recordVideo on dedicated StoreAssets simulators',
        data='Entirely synthetic version-3 archive injected only into dedicated simulator data containers. Fixtures are never included in shipping source or app bundle.',
        sources=['https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/','https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/','https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/'],
        warnings=['iPad artifacts explicitly skipped per user decision; no native iPad support is claimed.', 'iPhone Duo artifacts explicitly deferred by user approval. A compatible iOS 27.1 or newer runtime download failed because it required 8.34 GB of additional disk space. No further download or cache deletion is authorized; no substitute, stretched image or invented Duo UI is generated.'],
        commands=dict(
            prepare='python3 scripts/store-assets/dayinink-capture.py prepare --kind {iphone|duo-outer|duo-inner} --udid DEDICATED_UDID --app build/StoreCapture/Build/Products/Debug-iphonesimulator/DayInInk.app',
            server='python3 scripts/store-assets/dayinink-capture.py serve --kind {iphone|duo-outer|duo-inner} --udid DEDICATED_UDID',
            generate='env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate --spec scripts/store-assets/dayinink-capture/project.yml',
            capture='env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project scripts/store-assets/dayinink-capture/DayInInkCapture.xcodeproj -scheme DayInInkCapture -destination "platform=iOS Simulator,id=DEDICATED_UDID" -derivedDataPath build/DayInInkCapture -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO',
            render='python3 scripts/store-assets/dayinink-render.py',
            encode='python3 scripts/store-assets/dayinink-finalize.py --kind {iphone|duo-outer|duo-inner}',
            manifest='python3 scripts/store-assets/dayinink-finalize.py --manifest-only'), assets=assets)
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2)+'\n')
    print('Wrote', OUT/'manifest.json')

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--kind', choices=['iphone','duo-outer','duo-inner'])
parser.add_argument('--manifest-only', action='store_true')
args = parser.parse_args()
if args.kind:
    render(args.kind)
elif not args.manifest_only:
    parser.error('Pass --kind or --manifest-only')
manifest()
