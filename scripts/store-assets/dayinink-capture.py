#!/usr/bin/env python3
"""Dedicated-simulator fixture/capture server; never writes into the app bundle."""
import argparse
import datetime as dt
import http.server
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid

os.environ.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
BUNDLE = 'com.droessmj.dayinink'
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/store-assets/day-in-ink'


def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()


def fixture(day):
    start = day - dt.timedelta(days=89)
    def civil(d):
        return dict(year=d.year, month=d.month, day=d.day)
    specs = [('Walk', '🚶', 'blue', 'progress', 8000, 1000, 'steps'),
             ('Read', '📖', 'lavender', 'progress', 20, 5, 'pages'),
             ('Mindful moment', '🧘', 'mint', 'checkIn', 1, 1, ''),
             ('Drink water', '💧', 'amber', 'progress', 8, 1, 'glasses')]
    habits, entries = [], []
    for h, (name, emoji, color, kind, target, step, unit) in enumerate(specs):
        ident = str(uuid.uuid5(uuid.NAMESPACE_URL, 'dayinink-store-assets/' + name)).upper()
        habits.append(dict(id=ident, name=name, emoji=emoji, color=color, kind=kind,
                           target=target, step=step, unit=unit, createdAt=(dt.datetime.combine(start, dt.time(12)) - dt.datetime(2001, 1, 1)).total_seconds(),
                           startDay=civil(start), isArchived=False, defaultPassed=False))
        for i in range(90):
            date = start + dt.timedelta(days=i)
            fraction = [1, 1, .75, 1, .5, 1, 1, .9, 1, 1][(i + h * 3) % 10]
            value = int(target * fraction) if kind == 'progress' else 0
            passed = fraction >= .75
            if i == 89:
                value = [5000, 20, 0, 5][h]
                passed = True
            entry = dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL, ident + '/' + date.isoformat())).upper(),
                         habitID=ident, day=civil(date), value=value, target=target, kind=kind, unit=unit)
            if kind == 'checkIn':
                entry['checkIn'] = 'passed' if passed else 'failed'
            entries.append(entry)
    return dict(version=3, habits=habits, entries=entries)


def prepare(args):
    devices = json.loads(sim('list', 'devices', '--json'))
    device = next(d for ds in devices['devices'].values() for d in ds if d['udid'] == args.udid)
    if not device['name'].startswith(('StoreAssets-DayInInk-', 'StoreAssets-Duo')):
        raise SystemExit('Refusing to seed a simulator not dedicated to store assets')
    if device['state'] != 'Booted':
        sim('boot', args.udid)
    sim('bootstatus', args.udid, '-b')
    sim('install', args.udid, str(Path(args.app).resolve()))
    subprocess.run(['xcrun', 'simctl', 'terminate', args.udid, BUNDLE], capture_output=True)
    container = Path(sim('get_app_container', args.udid, BUNDLE, 'data'))
    target = container / 'Library/Application Support/DayInInk/habits.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    archive = fixture(dt.date.today())
    target.write_text(json.dumps(archive, indent=2) + '\n')
    provenance = OUT / 'provenance'
    provenance.mkdir(parents=True, exist_ok=True)
    (provenance / ('synthetic-fixture-' + args.kind + '.json')).write_text(json.dumps(archive, indent=2) + '\n')
    sim('status_bar', args.udid, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    for folder in ('screenshots/iphone', 'screenshots/duo-outer', 'screenshots/duo-inner', 'previews', 'creative'):
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    (provenance / ('device-' + args.kind + '.json')).write_text(json.dumps(dict(device=device, app=str(Path(args.app).resolve()), bundleIdentifier=BUNDLE, fixtureDate=str(dt.date.today()), dataSource='synthetic; dedicated simulator container only'), indent=2) + '\n')
    print('Prepared', args.kind, args.udid, flush=True)


def serve(args):
    screenshot_dir = OUT / 'screenshots' / args.kind
    preview_dir = OUT / 'previews' if args.kind == 'iphone' else OUT / 'previews' / args.kind
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)
    events = []
    recording = None
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            nonlocal recording
            try:
                if self.path.startswith('/screenshot/'):
                    name = self.path.rsplit('/', 1)[1]
                    if name not in ['01-today', '02-habit-progress', '03-check-in', '04-trends', '05-your-habits', '06-make-it-yours']:
                        raise ValueError('Unknown capture name')
                    sim('io', args.udid, 'screenshot', '--type=png', str(screenshot_dir / (name + '.png')))
                elif self.path == '/record/start':
                    if recording:
                        raise ValueError('Already recording')
                    recording = subprocess.Popen(['xcrun', 'simctl', 'io', args.udid, 'recordVideo', '--codec=h264', '--force', str(preview_dir / 'raw-interaction.mov')])
                    time.sleep(1)
                elif self.path == '/record/stop':
                    if not recording:
                        raise ValueError('Not recording')
                    recording.send_signal(signal.SIGINT)
                    recording.wait(timeout=20)
                    recording = None
                else:
                    raise ValueError('Unknown action')
                events.append(dict(action=self.path, time=dt.datetime.now(dt.timezone.utc).isoformat(), udid=args.udid))
                (preview_dir / 'capture-events.json').write_text(json.dumps(events, indent=2) + '\n')
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'ok')
            except Exception as error:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(error).encode())
    print('Day in Ink capture server ready on 8871', flush=True)
    try:
        http.server.HTTPServer(('127.0.0.1', 8871), Handler).serve_forever()
    finally:
        if recording:
            recording.send_signal(signal.SIGINT)
            recording.wait(timeout=20)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('action', choices=['prepare', 'serve'])
parser.add_argument('--udid', required=True)
parser.add_argument('--kind', choices=['iphone', 'duo-outer', 'duo-inner'], required=True)
parser.add_argument('--app')
args = parser.parse_args()
if args.action == 'prepare':
    if not args.app:
        parser.error('prepare requires --app')
    prepare(args)
else:
    serve(args)
