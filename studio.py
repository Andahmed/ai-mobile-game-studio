import os, json, datetime
from company import load_agents, ask, write, read
agents=load_agents()
if not agents:
    raise SystemExit("No agent role files found in agents/")
phase_file="studio_state.json"
state=json.load(open(phase_file,encoding="utf-8")) if os.path.exists(phase_file) else {"phase":"plan","sprint":0}
state["sprint"]+=1
today=datetime.date.today().isoformat()
if state["phase"]=="plan":
    plan=ask(agents.get("ceo","You are a game studio director."),read("brief.md")+"\nCreate a scoped mobile game plan with milestones and engine choice.")
    write("docs/plan.md",plan)
    state["phase"]="design"
elif state["phase"]=="design":
    gdd=ask(agents.get("designer","You are a game designer."),read("docs/plan.md")+"\nCreate a practical GDD for a small mobile game.")
    write("docs/GDD.md",gdd)
    state["phase"]="build"
elif state["phase"]=="build":
    build=ask(agents.get("programmer","You are a game programmer."),read("docs/GDD.md")+"\nGenerate a Godot 4 starter project. Return files as: === FILE: path === then content then === END ===.")
    import re
    for path,body in re.findall(r"=== FILE: (.+?) ===\n(.*?)(?=\n=== END ===|\Z)",build,re.S):
        path=path.strip()
        if ".." not in path.split("/"):
            write("game/"+path,body.strip()+"\n")
    qa=ask(agents.get("qa","You are QA. Be honest about what was not run."), "Review the generated source files for bugs and testability.")
    write("docs/qa_report.md",qa)
    state["phase"]="build"
else:
    state["phase"]="build"
state["last_run"]=today
json.dump(state,open(phase_file,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
write("meetings/sprint-"+str(state["sprint"]).zfill(3)+".md",f"# Sprint {state['sprint']}\nPhase: {state['phase']}\n")
print("Studio run complete:",state)
