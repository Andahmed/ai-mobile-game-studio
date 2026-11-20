import os, glob
from google import genai

MODEL = os.getenv("GEMINI_MODEL") or "gemini-3.8-flash"
client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

def load_agents():
    agents = {}
    for path in sorted(glob.glob("agents/*.md")):
        key = os.path.basename(path)[:-3]
        with open(path, encoding="utf-8") as f:
            agents[key] = f.read()
    return agents

def ask(role, prompt, max_tokens=2000):
    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={"system_instruction": role, "max_output_tokens": max_tokens}
    )
    return response.text or ""

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
