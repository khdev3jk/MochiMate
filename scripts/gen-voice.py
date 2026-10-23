#!/usr/bin/env python3
"""Generates the pre-recorded voice lines into Sources/MochiMate/Resources/Content/audio/<lang>/.

- vi: VieNeu-TTS, "Hải Đăng" for male characters and "Trúc Ly" for female ones. Needs the VieNeu venv that the
  Web to EPUB app installed (VIENEU_PYTHON).
- en, ja: HyperFrames TTS (Kokoro). Needs a venv with kokoro-onnx, soundfile and pykakasi (HYPERFRAMES_PYTHON, also the python to run this script with) and espeak-ng
  (`brew install espeak-ng`).

Only the reminder lines (water, move, eyes) are voiced; everything else stays text.

A line is saved as <line id>.m4a. Shared lines (any character can say them) get one file per gender,
<line id>.m.m4a and <line id>.f.m4a. Lines with {placeholders} can't be pre-recorded, so they have no audio.
Files that already exist are kept, so an interrupted run can simply be started again.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "Sources/MochiMate/Resources/Content"
VIENEU_PYTHON = os.environ.get("VIENEU_PYTHON", str(Path.home() / "Library/Application Support/web-to-epub/data/tts/venv/bin/python"))
VIENEU_HF_HOME = os.environ.get("VIENEU_HF_HOME", str(Path.home() / "Library/Application Support/web-to-epub/data/tts/hf"))
HYPERFRAMES = ["npx", "-y", "hyperframes@0.8.186"]

VOICES = {
    "vi": {"m": "Hải Đăng", "f": "Trúc Ly"},
    "en": {"m": "am_michael", "f": "af_heart"},
    "ja": {"m": "jm_kumo", "f": "jf_alpha"},
}
REMINDER_KINDS = {"water", "move", "eyes"}
FEMALE = {"rin", "hana", "mei", "yui", "aki"}


# Latin words in the Japanese lines, as katakana; the phonemizer would switch to English for them.
JA_WORDS = {"Comic Sans": "コミックサンス", "Figma": "フィグマ", "Excel": "エクセル", "KPI": "ケーピーアイ", "CSS": "シーエスエス",
            "JPEG": "ジェイペグ", "PR": "ピーアール", "px": "ピクセル"}


def spoken(text, lang):
    """What is read aloud: no emoji, tildes, quotes or other symbols a voice would trip over. Japanese goes in as
    hiragana, since Kokoro's phonemizer reads kanji as Chinese."""
    text = re.sub(r"\s+", " ", re.sub(r"[✨~〜「」_#=＝+]", " ", text)).strip()
    if lang == "ja":
        for word, kana in JA_WORDS.items():
            text = text.replace(word, kana)
        import pykakasi  # in the HYPERFRAMES_PYTHON venv: run this script with that python
        text = "".join(part["hira"] for part in pykakasi.kakasi().convert(text))
    return text


def entries(node):
    for i, entry in enumerate(node or []):
        yield i + 1, entry if isinstance(entry, dict) else {"text": entry}


def build_jobs(only_langs):
    pack = json.loads((CONTENT / "content.json").read_text(encoding="utf-8"))
    jobs = []  # (lang, file stem, text, gender)

    def add(lang, owner, kind, n, entry, genders):
        if "{" in entry["text"] or lang not in only_langs:
            return
        stem = entry.get("id") or f"{owner}.{lang}.{kind}.{n}"
        for g in genders:
            jobs.append((lang, stem if len(genders) == 1 else f"{stem}.{g}", spoken(entry["text"], lang), g))

    for character, languages in pack["characters"].items():
        gender = "f" if character in FEMALE else "m"
        for lang, kinds in languages.items():
            for kind, lines in kinds.items():
                for n, entry in entries(lines):
                    if kind in REMINDER_KINDS:
                        add(lang, character, kind, n, entry, [gender])
    for lang, kinds in pack["shared"].items():
        for kind, lines in kinds.items():
            for n, entry in entries(lines):
                if kind in REMINDER_KINDS:
                    add(lang, "shared", kind, n, entry, ["m", "f"])
    return jobs


def to_m4a(wav, m4a):
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "48000", "-c", "1", str(wav), str(m4a)], check=True)


def run_vietnamese(jobs, work):
    batch = [{"text": text, "voice": VOICES["vi"][g], "out": str(work / f"vi-{stem}.wav")} for _, stem, text, g in jobs]
    (work / "vi.json").write_text(json.dumps(batch, ensure_ascii=False), encoding="utf-8")
    env = {**os.environ, "HF_HOME": VIENEU_HF_HOME, "HF_HUB_OFFLINE": "1"}
    subprocess.run([VIENEU_PYTHON, str(Path(__file__).with_name("vieneu-batch.py")), str(work / "vi.json")], check=True, env=env)


def run_hyperframes(job, work):
    lang, stem, text, gender = job
    wav = work / f"{lang}-{stem}.wav"
    subprocess.run([*HYPERFRAMES, "tts", text, "-v", VOICES[lang][gender], "-o", str(wav)],
                   check=True, capture_output=True, text=True)
    print(f"{lang} {wav.name}", file=sys.stderr, flush=True)


def main():
    langs = sys.argv[1:] or ["vi", "en", "ja"]
    todo = [j for j in build_jobs(langs) if not (CONTENT / "audio" / j[0] / f"{j[1]}.m4a").exists()]
    print(f"{len(todo)} lines to record", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        if vi := [j for j in todo if j[0] == "vi"]:
            run_vietnamese(vi, work)
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda j: run_hyperframes(j, work), [j for j in todo if j[0] != "vi"]))
        for lang, stem, _, _ in todo:
            out = CONTENT / "audio" / lang / f"{stem}.m4a"
            out.parent.mkdir(parents=True, exist_ok=True)
            to_m4a(work / f"{lang}-{stem}.wav", out)


if __name__ == "__main__":
    main()
