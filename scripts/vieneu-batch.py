"""Synthesizes Vietnamese lines with VieNeu-TTS. Run by gen-voice.py with the VieNeu venv's python.

Usage: vieneu-batch.py jobs.json   where jobs.json is [{"text": "...", "voice": "Hải Đăng", "out": "/abs/file.wav"}, ...]
"""
import json
import os
import sys

from vieneu import Vieneu
import soundfile as sf
import numpy as np

jobs = json.load(open(sys.argv[1], encoding="utf-8"))
tts = Vieneu(mode="v3turbo")
for i, job in enumerate(jobs, 1):
    if os.path.exists(job["out"]):
        continue
    audio = np.asarray(tts.infer(job["text"], voice=job["voice"]), dtype=np.float32).reshape(-1)
    sf.write(job["out"], audio, tts.sample_rate)
    print(f"vi {i}/{len(jobs)} {os.path.basename(job['out'])}", file=sys.stderr, flush=True)
