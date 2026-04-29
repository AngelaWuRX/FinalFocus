import json
import os
import re
import urllib.error
import urllib.request
from uuid import uuid4

from planner_rules import make_rule_plan


SYSTEM_PROMPT = """You are FinalFocus Planner, a strict study rescue agent for university undergrads who are behind before final exams.

Create a practical cram plan. Do not suggest passive rereading unless paired with immediate recall or practice.
Prioritize:
1. scope triage,
2. high-yield topic selection,
3. rescue learning from worked examples,
4. active recall,
5. timed practice,
6. mistake repair,
7. sleep-protecting final pass.

Return only JSON with this exact schema:
{
  "plan": {
    "finalName": "string",
    "targetDate": "ISO-8601 string",
    "tasks": [
      {
        "id": "UUID string",
        "title": "specific action",
        "course": "string",
        "minutes": 25,
        "reward": "short reward",
        "isComplete": false
      }
    ]
  },
  "note": "short explanation"
}
"""


def generate_plan(payload, exam_date):
    fallback = make_rule_plan(
        goal=(payload.get("goal") or "Next Final").strip(),
        exam_date=exam_date,
        hours_per_day=payload.get("hoursPerDay", 4),
        preparedness=payload.get("preparedness", "lost"),
        mode=payload.get("mode", "hard"),
    )

    endpoint = os.environ.get("FINALFOCUS_TRANSFORMER_ENDPOINT", "").strip()
    if not endpoint:
        return fallback

    try:
        model_json = call_transformer(endpoint, payload, fallback)
        return normalize_plan(model_json, fallback)
    except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError):
        return fallback


def call_transformer(endpoint, payload, fallback):
    body = {
        "model": os.environ.get("FINALFOCUS_MODEL", "finalfocus-planner"),
        "temperature": float(os.environ.get("FINALFOCUS_TEMPERATURE", "0.2")),
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "studentContext": {
                            "goal": payload.get("goal"),
                            "examDate": payload.get("examDate"),
                            "hoursPerDay": payload.get("hoursPerDay"),
                            "preparedness": payload.get("preparedness"),
                            "mode": payload.get("mode"),
                            "existingFinal": payload.get("existingFinal"),
                        },
                        "fallbackPlanForShapeOnly": fallback,
                    }
                ),
            },
        ],
    }

    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    api_key = os.environ.get("FINALFOCUS_TRANSFORMER_API_KEY")
    if api_key:
        request.add_header("Authorization", f"Bearer {api_key}")

    with urllib.request.urlopen(request, timeout=20) as response:
        response_json = json.loads(response.read())

    content = response_json["choices"][0]["message"]["content"]
    return extract_json(content)


def extract_json(content):
    stripped = content.strip()
    if stripped.startswith("{"):
        return json.loads(stripped)

    match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", stripped, re.DOTALL)
    if match:
        return json.loads(match.group(1))

    start = stripped.find("{")
    end = stripped.rfind("}")
    if start >= 0 and end > start:
        return json.loads(stripped[start : end + 1])

    raise ValueError("model did not return JSON")


def normalize_plan(model_json, fallback):
    plan = model_json.get("plan") or {}
    tasks = plan.get("tasks") or []
    if not tasks:
        raise ValueError("model returned no tasks")

    normalized_tasks = []
    for task in tasks[:40]:
        minutes = int(task.get("minutes") or 25)
        normalized_tasks.append(
            {
                "id": str(task.get("id") or uuid4()).upper(),
                "title": str(task.get("title") or "Study block")[:140],
                "course": str(task.get("course") or plan.get("finalName") or fallback["plan"]["finalName"])[:80],
                "minutes": max(10, min(120, minutes)),
                "reward": str(task.get("reward") or "One coin")[:40],
                "isComplete": bool(task.get("isComplete", False)),
            }
        )

    return {
        "plan": {
            "finalName": str(plan.get("finalName") or fallback["plan"]["finalName"])[:80],
            "targetDate": str(plan.get("targetDate") or fallback["plan"]["targetDate"]),
            "tasks": normalized_tasks,
        },
        "note": str(model_json.get("note") or "Transformer-generated plan.")[:240],
    }
