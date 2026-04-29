# FinalFocus Agent Backend

This is the backend layer the iPhone app calls for planning help. The app never talks directly to a model provider.

Run locally:

```bash
python3 server.py
```

## Real Agent Mode

Set `FINALFOCUS_TRANSFORMER_ENDPOINT` to an OpenAI-compatible chat-completions endpoint served by your own model. This can be vLLM, llama.cpp server, a fine-tuned transformer behind your own API, or any compatible gateway.

Example:

```bash
export FINALFOCUS_TRANSFORMER_ENDPOINT=http://127.0.0.1:8000/v1/chat/completions
export FINALFOCUS_MODEL=finalfocus-planner
python3 server.py
```

Optional:

```bash
export FINALFOCUS_TRANSFORMER_API_KEY=your-private-backend-key
export FINALFOCUS_TEMPERATURE=0.2
```

If the transformer endpoint is missing or fails, the backend falls back to the deterministic cram planner in `planner_rules.py`.

Endpoint:

```http
POST /plan
Content-Type: application/json

{
  "goal": "Organic Chemistry final in 6 days",
  "existingFinal": "Next Final",
  "examDate": "2026-05-02T04:00:00Z",
  "hoursPerDay": 5,
  "preparedness": "lost",
  "mode": "ultimate"
}
```

The real agent implementation lives in `agent.py`. It prompts your transformer to return strict JSON, validates the result, clamps unsafe durations, and returns the same response shape expected by the iOS app.
