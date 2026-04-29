from datetime import datetime, timedelta, timezone
from uuid import uuid4


def make_task(title, course, minutes, reward):
    return {
        "id": str(uuid4()).upper(),
        "title": title,
        "course": course,
        "minutes": minutes,
        "reward": reward,
        "isComplete": False,
    }


def parse_exam_date(value):
    if not value:
        return datetime.now(timezone.utc) + timedelta(days=7)
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return datetime.now(timezone.utc) + timedelta(days=7)


def scaled_minutes(base, mode):
    scale = {"normal": 1.0, "hard": 1.25, "ultimate": 1.6}.get(mode, 1.25)
    return int(round((base * scale) / 5) * 5)


def make_rule_plan(goal, exam_date, hours_per_day, preparedness, mode):
    now = datetime.now(timezone.utc)
    days_left = max(1, (exam_date - now).days + 1)
    hours_per_day = max(1, min(12, int(hours_per_day or 4)))
    daily_cap = 6 if mode == "ultimate" else 8
    daily_blocks = max(2, min(daily_cap, hours_per_day * 2))
    total_blocks = max(6, min(36, daily_blocks * min(days_left, 5)))
    rescue_share = {"lost": 0.45, "shaky": 0.30, "okay": 0.18}.get(preparedness, 0.45)
    rescue_blocks = max(2, int(total_blocks * rescue_share))
    practice_blocks = max(2, int(total_blocks * 0.35))
    recall_blocks = max(2, total_blocks - rescue_blocks - practice_blocks - 3)
    target_date = exam_date.replace(microsecond=0).isoformat().replace("+00:00", "Z")
    triage_minutes = scaled_minutes(25, mode)
    rescue_minutes = scaled_minutes(35, mode)
    recall_minutes = scaled_minutes(25, mode)
    practice_minutes = scaled_minutes(45, mode)

    tasks = [
        make_task("Emergency triage: collect syllabus, old exams, homework, formula sheet", goal, triage_minutes, "One coin"),
        make_task("Rank every topic high-yield, medium, or skip", goal, triage_minutes, "Five minute reset"),
        make_task("Build a survival sheet from solved examples, not rereading", goal, triage_minutes, "Snack"),
    ]

    for index in range(1, rescue_blocks + 1):
        tasks.append(make_task(f"Rescue learn weak topic {index}: watch/read one example, then redo it closed-book", goal, rescue_minutes, "One coin"))

    for index in range(1, recall_blocks + 1):
        tasks.append(make_task(f"Active recall loop {index}: blank page, check, correct, repeat", goal, recall_minutes, "Short walk"))

    for index in range(1, practice_blocks + 1):
        tasks.append(make_task(f"Timed practice set {index}: grade mistakes and write fixes", goal, practice_minutes, "Phone break"))

    tasks.append(make_task("Final pass: memorize survival sheet and sleep plan", goal, triage_minutes, "Premium reward"))

    return {
        "plan": {
            "finalName": goal,
            "targetDate": target_date,
            "tasks": tasks,
        },
        "note": f"{mode.title()} fallback plan: {days_left} day(s), {hours_per_day} hour(s)/day, {total_blocks} work blocks. Transformer was unavailable, so rule planning was used.",
    }
