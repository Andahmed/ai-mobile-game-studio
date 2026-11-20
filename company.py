import os, glob, time, random
from google import genai
from google.genai import errors

MODEL = os.getenv("GEMINI_MODEL") or "gemini-3.8-flash"
client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

# Retry transient Gemini overload/rate-limit/server errors with exponential backoff.
MAX_ATTEMPTS = int(os.getenv("GEMINI_MAX_ATTEMPTS", "5"))
RETRYABLE_STATUS = {429, 500, 502, 503, 504}

def load_agents():
    agents = {}
    for path in sorted(glob.glob("agents/*.md")):
        key = os.path.basename(path)[:-3]
        with open(path, encoding="utf-8") as f:
            agents[key] = f.read()
    return agents

def ask(role, prompt, max_tokens=2000):
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = client.models.generate_content(
                model=MODEL,
                contents=prompt,
                config={"system_instruction": role, "max_output_tokens": max_tokens}
            )
            return response.text or ""
        except errors.APIError as exc:
            status = getattr(exc, "code", None) or getattr(exc, "status_code", None)
            if status not in RETRYABLE_STATUS or attempt >= MAX_ATTEMPTS:
                raise
            # Exponential backoff (2, 4, 8, 16 seconds) plus small jitter.
            delay = min(30, 2 ** attempt) + random.uniform(0, 1)
            print(f"Gemini temporary error ({status}); retry {attempt}/{MAX_ATTEMPTS - 1} in {delay:.1f}s")
            time.sleep(delay)

def write(path, content):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return ""
