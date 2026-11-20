import os, glob, re, time, random, subprocess
from google import genai
from google.genai import errors

MODEL = os.getenv("GEMINI_MODEL") or "gemini-3.8-flash"
client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

MAX_ATTEMPTS = int(os.getenv("GEMINI_MAX_ATTEMPTS", "5"))
RETRYABLE_STATUS = {429, 500, 502, 503, 504}
TEXT_EXT = (".gd", ".tscn", ".tres", ".godot", ".cfg", ".cs", ".shader", ".gdshader", ".svg", ".json", ".md", ".txt")

FILEFMT = ("\n\nاكتب كل ملف بهذه الصيغة بالضبط، بدون علامات ``` وبدون شرح خارج الملفات:\n"
           "=== FILE: المسار/الملف.ext ===\nمحتوى الملف\n=== END ===\n"
           "المسارات نسبية لمجلد game/ (مثل project.godot أو scripts/player.gd). أرسل الملفات كاملة، مش أجزاء.")

def load_agents():
    agents = {}
    for path in sorted(glob.glob("agents/*.md")):
        key = os.path.basename(path)[:-3]
        with open(path, encoding="utf-8") as f:
            agents[key] = f.read()
    return agents

def ask(role, prompt, max_tokens=4000):
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = client.models.generate_content(
                model=MODEL,
                contents=prompt,
                config={"system_instruction": role, "max_output_tokens": max_tokens}
            )
            text = (response.text or "").strip()
            if not text:
                raise RuntimeError("Gemini رجّع رد فاضي (ممكن حجب أو حد توكنز)")
            return text
        except errors.APIError as exc:
            status = getattr(exc, "code", None) or getattr(exc, "status_code", None)
            if status not in RETRYABLE_STATUS or attempt >= MAX_ATTEMPTS:
                raise
            delay = min(30, 2 ** attempt) + random.uniform(0, 1)
            print(f"Gemini temporary error ({status}); retry {attempt}/{MAX_ATTEMPTS - 1} in {delay:.1f}s")
            time.sleep(delay)

def write(path, content):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def read(path, limit=15000):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()[:limit]
    except FileNotFoundError:
        return ""

def save_files(text, root="game"):
    saved = []
    for path, body in re.findall(r"=== FILE: (.+?) ===\n(.*?)(?=\n=== (?:FILE:|END)|\Z)", text, re.S):
        path = path.strip().lstrip("/")
        if not path or ".." in path.split("/"):
            continue
        write(os.path.join(root, path), body.rstrip() + "\n")
        saved.append(path)
    return saved

def snapshot(root="game", limit=40000):
    out, total = [], 0
    for dp, _, fs in os.walk(root):
        for f in sorted(fs):
            if not f.endswith(TEXT_EXT):
                continue
            p = os.path.join(dp, f)
            body = open(p, encoding="utf-8", errors="ignore").read()
            chunk = f"=== {os.path.relpath(p, root)} ===\n{body}\n"
            if total + len(chunk) > limit:
                out.append("(تم اقتطاع باقي الملفات)")
                return "\n".join(out)
            out.append(chunk); total += len(chunk)
    return "\n".join(out) or "(المشروع فاضي)"

def gh(*args):
    try:
        r = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=60)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""

def open_issue(title, body):
    gh("label", "create", "needs-owner", "--force", "--color", "d97757")
    url = gh("issue", "create", "--title", title, "--body", body, "--label", "needs-owner")
    m = re.search(r"/(\d+)\s*$", url)
    return int(m.group(1)) if m else None
