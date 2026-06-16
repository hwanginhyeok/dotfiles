#!/usr/bin/env python3
"""스킬 호출 빈도 추적 + 메모리 요약 자동 갱신.

사용:
  --track <skill_name>     스킬 호출 시 카운트 +1, last_used 갱신
  --rebuild                JSON → markdown 요약 재생성 (세션 시작 시 호출)
"""
from __future__ import annotations
import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

MEM_DIR = Path.home() / ".claude/projects/-home-window11-project-manager/memory"
JSON_PATH = MEM_DIR / "skill_usage.json"
MD_PATH = MEM_DIR / "reference_skill_usage.md"
NOW = datetime.now(timezone.utc).astimezone()
RECENT_WINDOW_DAYS = 14
TOP_N = 15


def load() -> dict:
    if not JSON_PATH.exists():
        return {"skills": {}, "history": []}
    try:
        return json.loads(JSON_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {"skills": {}, "history": []}


def save(data: dict) -> None:
    MEM_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def track(skill_name: str) -> None:
    if not skill_name:
        return
    data = load()
    skills = data.setdefault("skills", {})
    history = data.setdefault("history", [])
    entry = skills.setdefault(skill_name, {"count": 0, "first_used": NOW.isoformat(), "last_used": ""})
    entry["count"] = int(entry.get("count", 0)) + 1
    entry["last_used"] = NOW.isoformat()
    history.append({"ts": NOW.isoformat(), "skill": skill_name})
    cutoff = NOW - timedelta(days=90)
    data["history"] = [h for h in history if datetime.fromisoformat(h["ts"]) >= cutoff]
    save(data)


def rebuild() -> None:
    data = load()
    skills = data.get("skills", {})
    history = data.get("history", [])
    if not skills:
        MD_PATH.write_text(_empty_md(), encoding="utf-8")
        return

    by_count = sorted(skills.items(), key=lambda kv: -kv[1].get("count", 0))[:TOP_N]
    cutoff = NOW - timedelta(days=RECENT_WINDOW_DAYS)
    recent = Counter(h["skill"] for h in history if datetime.fromisoformat(h["ts"]) >= cutoff)
    recent_top = recent.most_common(TOP_N)

    lines = [
        "---",
        "name: 스킬 호출 빈도",
        "description: 사용자가 자주 쓰는 스킬 + 최근 사용 패턴 — 적절한 스킬 자동 제안 근거",
        "type: reference",
        "---",
        "",
        f"# 스킬 호출 빈도 (자동 추적, 갱신: {NOW.strftime('%Y-%m-%d %H:%M %z')})",
        "",
        "## 누적 Top",
        "| 스킬 | 횟수 | 최근 사용 |",
        "|------|------|----------|",
    ]
    for name, info in by_count:
        last = info.get("last_used", "")
        last_disp = last.split("T")[0] if last else "-"
        lines.append(f"| `/{name}` | {info.get('count', 0)} | {last_disp} |")

    lines.append("")
    lines.append(f"## 최근 {RECENT_WINDOW_DAYS}일 빈도")
    if recent_top:
        lines.append("| 스킬 | 횟수 |")
        lines.append("|------|------|")
        for name, n in recent_top:
            lines.append(f"| `/{name}` | {n} |")
    else:
        lines.append("- (최근 호출 없음)")

    lines.append("")
    lines.append("## 활용 룰")
    lines.append("- 사용자 요청을 받을 때 위 빈도를 참고하여 적절한 스킬 자동 제안")
    lines.append("- 비슷한 맥락(예: cron 점검)이면 자주 쓰던 스킬(`/hih-cron`) 우선 제안")
    lines.append("- 누적 0회 스킬도 맥락 일치 시 제안 가능 (빈도가 절대 기준은 아님)")
    lines.append("")
    MD_PATH.write_text("\n".join(lines), encoding="utf-8")


def _empty_md() -> str:
    return (
        "---\n"
        "name: 스킬 호출 빈도\n"
        "description: 자동 추적 — 호출 기록 없음\n"
        "type: reference\n"
        "---\n\n"
        f"# 스킬 호출 빈도 (갱신: {NOW.strftime('%Y-%m-%d %H:%M %z')})\n\n"
        "아직 추적된 호출이 없다. 스킬 사용 시 자동 누적된다.\n"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--track", metavar="SKILL_NAME")
    g.add_argument("--rebuild", action="store_true")
    args = ap.parse_args()

    if args.track:
        track(args.track)
    if args.rebuild:
        rebuild()
    return 0


if __name__ == "__main__":
    sys.exit(main())
