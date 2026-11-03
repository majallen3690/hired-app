"""Builds the demo recordings from tool/demo/script.json.

Each line is spoken by a Windows SAPI voice (David interviews, Zira answers), the turns are laid on one timeline
with natural gaps, and the real start and end of every turn is written next to the audio. Nothing is estimated:
the timestamps are the lengths of the audio that was actually produced.

Run from the project root:  python tool/demo/build_audio.py
"""
import json
import re
import subprocess
import tempfile
import wave
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = json.loads((ROOT / "tool/demo/script.json").read_text(encoding="utf-8"))
OUT = ROOT / "assets/demo"
RATE = 16000
SAMPLE_WIDTH = 2

PAUSE = re.compile(r"\[\[pause ([0-9.]+)\]\]")


def ssml(text: str) -> str:
    parts, at = [], 0
    for m in PAUSE.finditer(text):
        parts.append(escape(text[at:m.start()]))
        parts.append('<break time="%dms"/>' % round(float(m.group(1)) * 1000))
        at = m.end()
    parts.append(escape(text[at:]))
    return ('<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
            + "".join(parts) + "</speak>")


def plain(text: str) -> str:
    return re.sub(r"\s+", " ", PAUSE.sub(" ", text)).strip()


def silence(ms: int) -> bytes:
    return b"\x00" * (RATE * SAMPLE_WIDTH * ms // 1000)


def read_pcm(path: Path) -> bytes:
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1 and w.getsampwidth() == SAMPLE_WIDTH, path
        return w.readframes(w.getnframes())


def write_wav(path: Path, pcm: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(SAMPLE_WIDTH)
        w.setframerate(RATE)
        w.writeframes(pcm)


def ms_of(pcm: bytes) -> int:
    return len(pcm) * 1000 // (RATE * SAMPLE_WIDTH)


def main() -> None:
    work = Path(tempfile.mkdtemp(prefix="hired-demo-"))
    jobs, plan = [], []

    for s in SCRIPT["sessions"]:
        for i, t in enumerate(s["turns"]):
            cand = t["who"] == "candidate"
            out = work / f"{s['id']}-{i}.wav"
            jobs.append({
                "out": str(out),
                "voice": SCRIPT["candidateVoice"] if cand else SCRIPT["interviewerVoice"],
                "rate": s.get("candidateRate", 0) if cand else 0,
                "ssml": ssml(t["text"]),
            })
    for it in SCRIPT["intros"]:
        out = work / f"{it['id']}.wav"
        jobs.append({"out": str(out), "voice": SCRIPT["candidateVoice"], "rate": it.get("rate", 0), "ssml": ssml(it["text"])})

    manifest = work / "manifest.json"
    manifest.write_text(json.dumps(jobs), encoding="utf-8")
    subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "tool/demo/tts.ps1"), "-Manifest", str(manifest)],
        check=True,
    )

    sessions = []
    for s in SCRIPT["sessions"]:
        pcm = bytearray(silence(1500))
        turns = []
        prev = None
        for i, t in enumerate(s["turns"]):
            if prev is not None:
                pcm += silence(1100 if prev == "interviewer" else 700)
            audio = read_pcm(work / f"{s['id']}-{i}.wav")
            start = ms_of(bytes(pcm))
            pcm += audio
            turns.append({
                "speaker": t["who"],
                "text": plain(t["text"]),
                "startMs": start,
                "endMs": ms_of(bytes(pcm)),
            })
            prev = t["who"]
        pcm += silence(800)
        write_wav(OUT / "audio" / f"{s['id']}.wav", bytes(pcm))
        sessions.append({
            "id": s["id"],
            "daysAgo": s["daysAgo"],
            "hour": s["hour"],
            "config": s["config"],
            "durationMs": ms_of(bytes(pcm)),
            "turns": turns,
        })

    intros = []
    for it in SCRIPT["intros"]:
        pcm = silence(900) + read_pcm(work / f"{it['id']}.wav") + silence(700)
        write_wav(OUT / "audio" / f"{it['id']}.wav", pcm)
        intros.append({
            "id": it["id"],
            "daysAgo": it["daysAgo"],
            "hour": it["hour"],
            "target": it["target"],
            "durationMs": ms_of(pcm),
        })

    (OUT / "sessions.json").write_text(json.dumps(sessions, indent=1), encoding="utf-8")
    (OUT / "intros.json").write_text(json.dumps(intros, indent=1), encoding="utf-8")

    for s in sessions:
        spoken = [t for t in s["turns"] if t["speaker"] == "candidate"]
        words = sum(len(t["text"].split()) for t in spoken)
        ms = sum(t["endMs"] - t["startMs"] for t in spoken)
        print(f"{s['id']}: {s['durationMs']/1000:.0f}s total, candidate {words} words in {ms/1000:.0f}s = {words*60000/ms:.0f} wpm")
    for it in SCRIPT["intros"]:
        words = len(plain(it["text"]).split())
        d = next(i for i in intros if i["id"] == it["id"])
        print(f"{it['id']}: {d['durationMs']/1000:.0f}s, {words} words = {words*60000/(d['durationMs']-1600):.0f} wpm")


if __name__ == "__main__":
    main()
