#!/usr/bin/env python3
"""Cut one long TTS recording per stage (e.g. from LuvVoice) into one file per word.

Usage:  python3 tools/split-stage-audio.py <folder with th-01.mp3 … en-06.mp3> <output audio/ folder>

Each recording must read the stage's words in the order of luvvoice-text/<stage>.txt.
Words are found from the silences between them; if the count is off, the split is
retried with other silence settings, then by merging the shortest gaps. Writes
<id>.m4a for every word and (re)writes manifest.json listing all files present.
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def words_by_stage():
    rows = [l.split("\t") for l in open(os.path.join(ROOT, "words.tsv"), encoding="utf-8").read().splitlines() if l]
    ids = {(lang, w): i for i, lang, w in rows}
    out = {}
    for f in sorted(os.listdir(os.path.join(ROOT, "luvvoice-text"))):
        if f.endswith(".txt"):
            lang = f[:2]
            ws = [l.rstrip(".") for l in open(os.path.join(ROOT, "luvvoice-text", f), encoding="utf-8").read().splitlines() if l]
            out[f[:-4]] = [ids[(lang, w)] for w in ws]
    return out

def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True)
    return float(r.stdout.strip())

def speech_spans(path, noise_db, min_sil):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", f"silencedetect=noise={noise_db}dB:d={min_sil}", "-f", "null", "-"],
                       capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    total = duration(path)
    sil = list(zip(starts, ends + [total] * (len(starts) - len(ends))))
    spans, t = [], 0.0
    for s, e in sil:
        if s - t > 0.06: spans.append([t, s])
        t = e
    if total - t > 0.06: spans.append([t, total])
    return spans

def fit(spans, n):
    spans = [s[:] for s in spans]
    while len(spans) > n:                   # a word with a pause inside: join across the shortest gap
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        i = gaps.index(min(gaps)); spans[i][1] = spans[i + 1][1]; del spans[i + 1]
    return spans

def split(path, n):
    for noise, d in [(-40, 0.30), (-35, 0.30), (-45, 0.30), (-40, 0.22), (-35, 0.20), (-30, 0.25), (-40, 0.40)]:
        spans = speech_spans(path, noise, d)
        if len(spans) >= n: return fit(spans, n)
    raise SystemExit(f"{os.path.basename(path)}: found only {len(spans)} words, expected {n}. "
                     "Ask for a longer pause between words (e.g. a slower speed) and export again.")

def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    stages = words_by_stage(); made = 0
    for f in sorted(os.listdir(src)):
        stem, ext = os.path.splitext(f)
        if stem not in stages or ext.lower() not in (".mp3", ".wav", ".m4a", ".ogg"): continue
        ids = stages[stem]; spans = split(os.path.join(src, f), len(ids))
        for wid, (a, b) in zip(ids, spans):
            a = max(0.0, a - 0.08); b = b + 0.12
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-to", f"{b:.3f}", "-i", os.path.join(src, f),
                            "-ac", "1", "-ar", "24000", "-c:a", "aac", "-b:a", "48k", os.path.join(dst, wid + ".m4a")], check=True)
        made += len(ids); print(f"{stem}: {len(ids)} words")
    have = sorted(x[:-4] for x in os.listdir(dst) if x.endswith(".m4a"))
    json.dump({"ext": "m4a", "voice": "luvvoice", "ids": have}, open(os.path.join(dst, "manifest.json"), "w"))
    print(f"cut {made} words · {len(have)} files in {dst}")

if __name__ == "__main__":
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
