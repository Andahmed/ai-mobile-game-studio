import os, glob, re, json, time, random, subprocess, urllib.request, urllib.error
from google import genai
from google.genai import errors

# ---- إعداد السلسلة: MODEL_CHAIN="gemini:gemini-3.8-flash,gemini:gemini-3.7-flash,anthropic:claude-haiku-5-5" ----
MODEL = os.getenv("GEMINI_MODEL") or "gemini-3.8-flash"
FALLBACKS = [m.strip() for m in os.getenv("GEMINI_FALLBACK_MODELS", "gemini-3.7-flash,gemini-2.5-flash").split(",")
             if m.strip() and m.strip() != MODEL]
MAX_ATTEMPTS = int(os.getenv("GEMINI_MAX_ATTEMPTS", "3"))
RETRYABLE_STATUS = {0, 429, 500, 502, 503, 504}
TEXT_EXT = (".gd", ".tscn", ".tres", ".godot", ".cfg", ".cs", ".shader", ".gdshader", ".svg", ".json", ".md", ".txt")

FILEFMT = ("\n\nاكتب كل ملف بهذه الصيغة بالضبط، بدون علامات ``` وبدون شرح خارج الملفات:\n"
           "=== FILE: المسار/الملف.ext ===\nمحتوى الملف\n=== END ===\n"
           "المسارات نسبية لمجلد game/ (مثل project.godot أو scripts/player.gd). أرسل الملفات كاملة، مش أجزاء.")

KEYS = {"gemini": "GEMINI_API_KEY", "anthropic": "ANTHROPIC_API_KEY", "openai": "OPENAI_API_KEY",
        "groq": "GROQ_API_KEY", "openrouter": "OPENROUTER_API_KEY"}
OPENAI_COMPAT = {"openai": os.getenv("OPENAI_BASE_URL") or "https://api.openai.com/v1",
                 "groq": "https://api.groq.com/openai/v1", "openrouter": "https://openrouter.ai/api/v1"}

class LLMError(Exception):
    def __init__(self, status, msg=""):
        self.status = status
        super().__init__(f"{status} {msg}".strip())

def build_chain():
    raw = os.getenv("MODEL_CHAIN", "").strip() or ",".join("gemini:" + m for m in [MODEL] + FALLBACKS)
    chain = []
    for item in [x.strip() for x in raw.split(",") if x.strip()]:
        prov, _, m = item.partition(":")
        if prov not in KEYS:
            prov, m = "gemini", item
        if os.getenv(KEYS[prov], "").strip():
            chain.append((prov, m))
        else:
            print(f"تخطي {prov}:{m} (مفيش {KEYS[prov]})")
    return chain

CHAIN = build_chain()
LAST_MODEL = ""          # آخر موديل رد فعلاً (للعرض في STATUS.md)
DOWN = set()             # موديلات فشلت في التشغيل ده، نتخطاها

_gc = None
def _gemini(model, role, prompt, max_tokens):
    global _gc
    if _gc is None:
        _gc = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    try:
        r = _gc.models.generate_content(model=model, contents=prompt,
                                        config={"system_instruction": role, "max_output_tokens": max_tokens})
    except errors.APIError as exc:
        raise LLMError(getattr(exc, "code", None) or getattr(exc, "status_code", None) or 0, str(exc)[:200])
    return (r.text or "").strip()

def _post(url, headers, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=300).read())
    except urllib.error.HTTPError as e:
        raise LLMError(e.code, e.read().decode(errors="ignore")[:200])
    except Exception as e:
        raise LLMError(0, str(e)[:200])

def _anthropic(model, role, prompt, max_tokens):
    d = _post("https://api.anthropic.com/v1/messages",
              {"x-api-key": os.environ["ANTHROPIC_API_KEY"], "anthropic-version": "2023-06-01"},
              {"model": model, "max_tokens": max_tokens, "system": role,
               "messages": [{"role": "user", "content": prompt}]})
    return "".join(b.get("text", "") for b in d.get("content", [])).strip()

def _openai_compat(prov, model, role, prompt, max_tokens):
    key = "max_completion_tokens" if prov == "openai" else "max_tokens"
    d = _post(OPENAI_COMPAT[prov] + "/chat/completions", {"Authorization": "Bearer " + os.environ[KEYS[prov]]},
              {"model": model, key: max_tokens,
               "messages": [{"role": "system", "content": role}, {"role": "user", "content": prompt}]})
    return ((d.get("choices") or [{}])[0].get("message", {}).get("content") or "").strip()

def _call(prov, model, role, prompt, max_tokens):
    if prov == "gemini":
        text = _gemini(model, role, prompt, max_tokens)
    elif prov == "anthropic":
        text = _anthropic(model, role, prompt, max_tokens)
    else:
        text = _openai_compat(prov, model, role, prompt, max_tokens)
    if not text:
        raise LLMError(0, "رد فاضي")
    return text

def load_agents():
    agents = {}
    for path in sorted(glob.glob("agents/*.md")):
        key = os.path.basename(path)[:-3]
        with open(path, encoding="utf-8") as f:
            agents[key] = f.read()
    return agents

def ask(role, prompt, max_tokens=4000):
    global LAST_MODEL
    if not CHAIN:
        raise SystemExit("مفيش أي مفتاح شغال: ضيف GEMINI_API_KEY أو ANTHROPIC_API_KEY أو غيرهم")
    if all(c in DOWN for c in CHAIN):
        DOWN.clear()
    last = None
    for prov, model in CHAIN:
        if (prov, model) in DOWN:
            continue
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                text = _call(prov, model, role, prompt, max_tokens)
                LAST_MODEL = f"{prov}:{model}"
                return text
            except LLMError as e:
                last = e
                if e.status in RETRYABLE_STATUS and attempt < MAX_ATTEMPTS:
                    delay = min(60, 8 * 2 ** (attempt - 1)) + random.uniform(0, 2)
                    print(f"{prov}:{model} خطأ مؤقت {e.status}؛ محاولة {attempt}/{MAX_ATTEMPTS - 1} بعد {delay:.0f} ثانية")
                    time.sleep(delay)
                    continue
                print(f"فشل {prov}:{model} ({e}) -> بجرّب الموديل اللي بعده")
                DOWN.add((prov, model))
                break
    raise last or RuntimeError("كل الموديلات فشلت")

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
