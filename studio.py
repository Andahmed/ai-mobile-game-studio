import os, json, time, datetime
import company
from company import *

STATE = "studio_state.json"
state = json.load(open(STATE, encoding="utf-8")) if os.path.exists(STATE) else {"phase": "plan", "sprint": 0}
for k, v in {"qa_rounds": 0, "gate": None, "notes": "", "history": []}.items():
    state.setdefault(k, v)

agents = load_agents()
DEFAULT = {"ceo": "You are a game studio director.", "designer": "You are a game designer.",
           "programmer": "You are an expert game programmer.",
           "qa": "You are a strict QA engineer. Be honest about what was not run."}
NAMES = {"ceo": "🧑‍💼 المدير العام", "designer": "🎲 مصمم اللعبة", "programmer": "💻 المبرمج", "qa": "🐞 مختبر الجودة"}
role = lambda k: agents.get(k) or DEFAULT[k]
now = datetime.datetime.now(datetime.timezone.utc)
today = now.date().isoformat()
brief = read("brief.md")
ACT, info = [], {"log": "", "result": ""}

def call(key, prompt, mt=4000):
    t = time.time()
    try:
        out = ask(role(key), prompt, mt)
        ACT.append((key, "✅", round(time.time() - t), len(out), out.strip().splitlines()[0][:70], company.LAST_MODEL))
        return out
    except BaseException as e:
        ACT.append((key, "❌", round(time.time() - t), 0, str(e)[:120], "-"))
        raise

def write_status(error=None, waiting=None):
    files = sorted(os.path.relpath(os.path.join(d, f), "game") for d, _, fs in os.walk("game") for f in fs if f != ".gitkeep")
    qa = read("docs/qa_report.md").strip().splitlines()
    L = ["# 📊 حالة الاستوديو", "", f"- **آخر تشغيل:** {now:%Y-%m-%d %H:%M} UTC",
         f"- **السبرنت:** {state['sprint']}  |  **المرحلة الجاية:** `{state['phase']}`  |  **جولات QA:** {state['qa_rounds']}"]
    if waiting:
        L.append(f"- ⏳ **الاستوديو مستني قرارك:** افتح Issue رقم #{waiting}، علّق بتعديلاتك ثم اقفله.")
    if error:
        L += ["", "## ❌ فشل التشغيل", f"```\n{error}\n```"]
    if ACT:
        L += ["", "## نشاط الوكلاء في آخر تشغيل", "| الوكيل | النتيجة | الموديل | ثواني | حجم الرد | أول سطر |", "|---|---|---|---|---|---|"]
        L += [f"| {NAMES.get(k, k)} | {s} | {m} | {t} | {n} | {p.replace('|', '/')} |" for k, s, t, n, p, m in ACT]
    L += ["", f"## ملفات اللعبة في `game/` ({len(files)})"] + ([f"- `{f}`" for f in files[:40]] or ["- (لسه مفيش)"])
    L += ["", "## آخر تقرير QA", qa[0] if qa else "لسه مفيش", "", "## السجل"]
    L += [f"- سبرنت {h['sprint']} ({h['date']}): {h['phase']} → {h['result']}" for h in state["history"][-10:][::-1]] or ["- فاضي"]
    text = "\n".join(L) + "\n"
    write("STATUS.md", text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8").write(text)

def save_state():
    state["last_run"] = today
    json.dump(state, open(STATE, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

def gate(title, body, nxt):
    n = open_issue(title, body)
    if n is None:
        print("تحذير: تعذر فتح Issue، هيكمل تلقائي"); state["phase"] = nxt; return
    state["gate"] = {"issue": n, "next": nxt}

def work():
    ph, notes = state["phase"], state.get("notes", "")
    info["log"] = f"# Sprint {state['sprint']}\nPhase: {ph}\n"
    if ph == "plan":
        write("docs/plan.md", call("ceo", f"{brief}\nملاحظات المالك: {notes}\nCreate a scoped mobile game plan with milestones and engine choice (prefer Godot 4).", 3000))
        state["phase"] = "design"; info["result"] = "اتكتبت الخطة docs/plan.md"
    elif ph == "design":
        write("docs/GDD.md", call("designer", f"{read('docs/plan.md')}\nملاحظات المالك: {notes}\nCreate a practical GDD for a small mobile game, detailed enough for a programmer to implement directly.", 4000))
        state["phase"] = "build"; info["result"] = "اتكتب docs/GDD.md"
    elif ph in ("build", "fix"):
        extra = f"\nتقرير QA المطلوب إصلاحه:\n{read('docs/qa_report.md')}\n" if ph == "fix" else ""
        out = call("programmer", f"Plan:\n{read('docs/plan.md')}\nGDD:\n{read('docs/GDD.md')}\nملاحظات المالك: {notes}{extra}\n"
                   f"المشروع الحالي (عدّله ولا تبدأ من الصفر):\n{snapshot()}\n\n"
                   "Generate or update a complete, runnable Godot 4 project (project.godot, scenes, GDScript)." + FILEFMT, 16000)
        files = save_files(out)
        if files:
            info["log"] += "Files: " + ", ".join(files) + "\n"; state["phase"] = "qa"; info["result"] = f"كتب {len(files)} ملف"
        else:
            write("docs/last_programmer_output.md", out)
            info["log"] += "WARNING: no files parsed (saved to docs/last_programmer_output.md)\n"
            state["phase"] = "build"; info["result"] = "⚠️ مفيش ملفات اتكتبت (الرد بصيغة غلط)"
    elif ph == "qa":
        qa = call("qa", f"GDD:\n{read('docs/GDD.md')}\nProject source files:\n{snapshot()}\n\n"
                  "Review these actual files for bugs, missing files, Godot 4 syntax errors and broken gameplay logic. "
                  "State clearly that you did not run the game. First line exactly: RESULT: PASS or RESULT: FAIL, then the issues ordered by severity.", 4000)
        write("docs/qa_report.md", qa)
        state["qa_rounds"] += 1
        state["phase"] = "release" if ("RESULT: PASS" in qa or state["qa_rounds"] >= 3) else "fix"
        info["result"] = qa.splitlines()[0][:60] + f" (جولة {state['qa_rounds']})"; info["log"] += info["result"] + "\n"
    elif ph == "release":
        write("docs/release.md", call("ceo", f"Write release notes and exact steps to open and run this Godot project on a phone/PC.\nQA report:\n{read('docs/qa_report.md')}", 2000))
        state["qa_rounds"] = 0; info["result"] = "اللعبة جاهزة للمراجعة"
        gate("اللعبة جاهزة للمراجعة", "جرّب اللعبة (docs/release.md فيها الطريقة). اكتب تعليقك بالتعديلات المطلوبة ثم **أغلق الـ Issue** ليبدأ سبرنت تحسين جديد.", "build")

g = state.get("gate")
if g:
    gi = json.loads(gh("issue", "view", str(g["issue"]), "--json", "state,comments") or "{}")
    if not gi or gi.get("state") == "OPEN":
        print("بانتظار قرار المالك في Issue رقم", g["issue"])
        write_status(waiting=g["issue"]); raise SystemExit
    state["notes"] = "\n".join(c["body"] for c in gi.get("comments", []))
    state["phase"], state["gate"] = g["next"], None

state["sprint"] += 1
ph0 = state["phase"]
try:
    work()
except Exception as e:
    state["history"].append({"sprint": state["sprint"], "date": today, "phase": ph0, "result": f"❌ {str(e)[:80]}"})
    save_state(); write_status(error=str(e)); raise
state["history"].append({"sprint": state["sprint"], "date": today, "phase": ph0, "result": info["result"]})
write(f"meetings/sprint-{state['sprint']:03d}.md", info["log"])
save_state(); write_status(waiting=(state["gate"] or {}).get("issue"))
print("Studio run complete:", state["phase"])
