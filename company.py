import os, glob, re
import anthropic
MODEL = "claude-sonnet-4-5-20250929"
client = anthropic.Anthropic()
def load_agents():
    agents={}
    for path in sorted(glob.glob("agents/*.md")):
        key=os.path.basename(path)[:-3]
        agents[key]=open(path,encoding="utf-8").read()
    return agents
def ask(role, prompt, max_tokens=2000):
    return client.messages.create(model=MODEL,max_tokens=max_tokens,system=role,messages=[{"role":"user","content":prompt}]).content[0].text
def write(path, content):
    os.makedirs(os.path.dirname(path) or ".",exist_ok=True)
    with open(path,"w",encoding="utf-8") as f:f.write(content)
def read(path):
    try:return open(path,encoding="utf-8").read()
    except FileNotFoundError:return ""
