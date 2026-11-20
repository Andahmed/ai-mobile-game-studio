import os, json, datetime
from company import *

STATE = "studio_state.json"
state = json.load(open(STATE, encoding="utf-8")) if os.path.exists(STATE) else {"phase": "plan", "sprint": 0}
for k, v in {"qa_rounds": 0, "gate": None, "notes": ""}.items():
    state.setdefault(k, v)

agents = load_agents()
DEFAULT = {"ceo": "You are a game studio director.", "designer": "You are a game designer.",
           "programmer": "You are an expert game programmer.",
           "qa": "You are a strict QA engineer. Be honest about what was not run."}
role = lambda k: agents.get(k) or DEFAULT[k]
today = datetime.date.today().isoformat()
brief = read("brief.md")

def save_state():
    state["last_run"] = today
    json.dump(state, open(STATE, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

def gate(title, body, nxt):
    n = open_issue(title, body)
    if n is None:
        print("تحذير: تعذر فتح Issue، هيكمل تلقائي"); state["phase"] = nxt; return
    state["gate"] = {"issue": n, "next": nxt}

# --- لو في قرار مفتوح للمالك: الاستوديو يستنى ---
g = state.get("gate")
if g:
    info = json.loads(gh("issue", "view", str(g["issue"]), "--json", "state,comments") or "{}")
    if not info or info.get("state") == "OPEN":
        print("بانتظار قرار المالك في Issue رقم", g["issue"]); raise SystemExit
    state["notes"] = "\n".join(c["body"] for c in info.get("comments", []))
    state["phase"], state["gate"] = g["next"], None

state["sprint"] += 1
ph, notes = state["phase"], state.get("notes", "")
log = f"# Sprint {state['sprint']}\nPhase: {ph}\n"

if ph == "plan":
    plan = ask(role("ceo"), f"{brief}\nملاحظات المالك: {notes}\nCreate a scoped mobile game plan with milestones and engine choice (prefer Godot 4).", 3000)
    write("docs/plan.md", plan)
    state["phase"] = "design"

elif ph == "design":
    gdd = ask(role("designer"), f"{read('docs/plan.md')}\nملاحظات المالك: {notes}\nCreate a practical GDD for a small mobile game, detailed enough for a programmer to implement directly.", 4000)
    write("docs/GDD.md", gdd)
    state["phase"] = "build"

elif ph in ("build", "fix"):
    extra = f"\nتقرير QA المطلوب إصلاحه:\n{read('docs/qa_report.md')}\n" if ph == "fix" else ""
    out = ask(role("programmer"),
              f"Plan:\n{read('docs/plan.md')}\nGDD:\n{read('docs/GDD.md')}\nملاحظات المالك: {notes}{extra}\n"
              f"المشروع الحالي (عدّله ولا تبدأ من الصفر):\n{snapshot()}\n\n"
              "Generate or update a complete, runnable Godot 4 project (project.godot, scenes, GDScript)." + FILEFMT, 16000)
    files = save_files(out)
    if files:
        log += "Files: " + ", ".join(files) + "\n"
        state["phase"] = "qa"
    else:
        write("docs/last_programmer_output.md", out)
        log += "WARNING: no files parsed from programmer output (saved to docs/last_programmer_output.md)\n"
        state["phase"] = "build"

elif ph == "qa":
    qa = ask(role("qa"), f"GDD:\n{read('docs/GDD.md')}\nProject source files:\n{snapshot()}\n\n"
             "Review these actual files for bugs, missing files, Godot 4 syntax errors and broken gameplay logic. "
             "State clearly that you did not run the game. First line exactly: RESULT: PASS or RESULT: FAIL, then the issues ordered by severity.", 4000)
    write("docs/qa_report.md", qa)
    state["qa_rounds"] += 1
    state["phase"] = "release" if ("RESULT: PASS" in qa or state["qa_rounds"] >= 3) else "fix"
    log += qa.splitlines()[0] + f" (round {state['qa_rounds']})\n"

elif ph == "release":
    rel = ask(role("ceo"), f"Write release notes and exact steps to open and run this Godot project on a phone/PC.\nQA report:\n{read('docs/qa_report.md')}", 2000)
    write("docs/release.md", rel)
    state["qa_rounds"] = 0
    gate("اللعبة جاهزة للمراجعة", "جرّب اللعبة (docs/release.md فيها الطريقة). اكتب تعليقك بالتعديلات المطلوبة ثم **أغلق الـ Issue** ليبدأ سبرنت تحسين جديد.", "build")

write(f"meetings/sprint-{state['sprint']:03d}.md", log)
save_state()
print("Studio run complete:", state)
