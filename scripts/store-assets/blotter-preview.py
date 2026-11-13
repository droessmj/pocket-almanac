#!/usr/bin/env python3
"""Encode an actual simctl interaction recording; never synthesize interface frames.
Example: python3 scripts/store-assets/blotter-preview.py --raw build/store-assets/blotter/previews/iphone-raw.mov --start 35 --kind iphone
Use raw frame/contact-sheet timestamps to select --start; attachment wall timestamps may differ.
"""
import argparse
import json
import pathlib
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--raw', type=pathlib.Path, required=True)
p.add_argument('--start', type=float, required=True)
p.add_argument('--duration', type=float, default=22)
p.add_argument('--kind', choices=['iphone'], default='iphone')
a = p.parse_args()
if not 15 <= a.duration <= 30:
    p.error('App previews must be 15–30 seconds')
if a.start < 0 or not a.raw.is_file():
    p.error('Provide an existing original recording and nonnegative start time')
probe = json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(a.raw)]))
raw_duration = float(probe['format']['duration'])
if a.start + a.duration > raw_duration:
    p.error('Selected interval exceeds actual raw recording; freeze extension is not permitted')
root = pathlib.Path('build/store-assets/blotter')
out = root / 'previews'
out.mkdir(parents=True, exist_ok=True)
w, h = 886, 1920
mp4 = out / (a.kind + '-preview.mp4')
poster = out / (a.kind + '-poster.png')
ffmpeg = '/opt/homebrew/bin/ffmpeg'
command = [ffmpeg, '-y', '-ss', str(a.start), '-i', str(a.raw), '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000', '-t', str(a.duration), '-map', '0:v:0', '-map', '1:a:0', '-vf', f'setpts=PTS-STARTPTS,scale={w}:{h}:force_original_aspect_ratio=decrease:flags=lanczos,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30', '-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'medium', '-c:a', 'aac_at', '-aac_at_mode', 'cbr', '-b:a', '256k', '-ac', '2', '-movflags', '+faststart', str(mp4)]
subprocess.run(command, check=True)
encoded = json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(mp4)]))
video = next(stream for stream in encoded['streams'] if stream['codec_type'] == 'video')
audio = next(stream for stream in encoded['streams'] if stream['codec_type'] == 'audio')
assert 15 <= float(video['duration']) <= 30 and abs(float(video['duration']) - a.duration) < 0.1
assert (video['width'], video['height'], video['codec_name'], video['pix_fmt'], video['r_frame_rate']) == (w, h, 'h264', 'yuv420p', '30/1')
assert audio['codec_name'] == 'aac' and audio['channels'] == 2
assert mp4.stat().st_size <= 500_000_000
(out / (a.kind + '-verification.json')).write_text(json.dumps(encoded, indent=2) + '\n')
subprocess.run([ffmpeg, '-y', '-ss', '1', '-i', str(mp4), '-frames:v', '1', '-pix_fmt', 'rgb24', '-update', '1', str(poster)], check=True)
metadata = {'kind': a.kind, 'raw_recording': str(a.raw), 'start_seconds': a.start, 'duration_seconds': a.duration, 'video': str(mp4), 'poster': str(poster), 'size': [w, h], 'frames_per_second': 30, 'audio': 'AAC stereo silence; no app audio', 'command': command, 'presentation': 'Actual simulator UI; aspect ratio preserved, never stretched', 'warnings': ['Simulator cannot demonstrate incoming SMS/MMS delivery or filtering.', 'Synthetic keywords only; app setup is not proof filtering is enabled.']}
(out / (a.kind + '-provenance.json')).write_text(json.dumps(metadata, indent=2) + '\n')
