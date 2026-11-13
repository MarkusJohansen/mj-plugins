#!/usr/bin/env python3
"""Mine ~/.claude for a usage + configuration snapshot. Writes one JSON file.

Usage: python3 -I mine.py [--days N] [--out PATH] [--claude-dir DIR]
Stdlib only. Streams transcripts line by line, so the full history is fine.
"""
import argparse, collections, json, os, re, sys, time
from datetime import datetime, timezone
from pathlib import Path

C = collections.Counter
CORRECTION = re.compile(r"^(no[,. ]|nope|wrong|that's not|that is not|don't|do not|stop|why did you|you (forgot|missed|didn't)|undo|revert)", re.I)
INTERRUPT = "[Request interrupted"


def load_json(p, default=None):
    try:
        return json.loads(Path(p).read_text())
    except Exception:
        return default


def frontmatter(p):
    try:
        txt = Path(p).read_text(errors="replace")
    except Exception:
        return {}, 0
    meta = {}
    if txt.startswith("---"):
        end = txt.find("\n---", 3)
        for line in txt[3:end].splitlines():
            if ":" in line and (not line.startswith(" ") or line.strip().startswith("type:")):
                k, v = line.split(":", 1)
                meta[k.strip()] = v.strip().strip('"')[:200]
    return meta, txt.count("\n") + 1


def ts(v):
    if isinstance(v, (int, float)):
        return v / 1000 if v > 1e12 else v
    try:
        return datetime.fromisoformat(str(v).replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


# ---------------------------------------------------------------- inventory
def scan_components(root, origin):
    """Skills, commands, agents, hooks under a plugin/config root."""
    out = {"skills": [], "commands": [], "agents": [], "hooks": False, "mcp": False}
    root = Path(root)
    for sk in sorted(root.glob("skills/**/SKILL.md")):
        m, n = frontmatter(sk)
        out["skills"].append({"name": m.get("name", sk.parent.name), "origin": origin, "lines": n,
                              "description": m.get("description", "")[:160]})
    for cmd in sorted(root.glob("commands/**/*.md")):
        out["commands"].append({"name": cmd.stem, "origin": origin})
    for ag in sorted(root.glob("agents/**/*.md")):
        m, _ = frontmatter(ag)
        out["agents"].append({"name": m.get("name", ag.stem), "origin": origin,
                              "description": m.get("description", "")[:160]})
    out["hooks"] = (root / "hooks" / "hooks.json").exists() or (root / "hooks.json").exists()
    out["mcp"] = (root / ".mcp.json").exists()
    return out


def inventory(cd):
    settings = load_json(cd / "settings.json", {}) or {}
    enabled = settings.get("enabledPlugins", {}) or {}
    installed = (load_json(cd / "plugins/installed_plugins.json", {}) or {}).get("plugins", {})
    plugins = []
    for key, entries in installed.items():
        e = entries[0] if entries else {}
        comp = scan_components(e.get("installPath", "/nonexistent"), key.split("@")[0])
        plugins.append({"id": key, "enabled": enabled.get(key, False), "version": e.get("version"),
                        "scope": e.get("scope"), "projectPath": e.get("projectPath"),
                        "installed": e.get("installedAt"), "updated": e.get("lastUpdated"),
                        **{k: comp[k] for k in ("hooks", "mcp")},
                        "skills": [s["name"] for s in comp["skills"]],
                        "commands": [c["name"] for c in comp["commands"]],
                        "agents": [a["name"] for a in comp["agents"]],
                        "_skill_detail": comp["skills"], "_agent_detail": comp["agents"]})

    markets = []
    for mp in sorted((cd / "plugins/marketplaces").glob("*/.claude-plugin/marketplace.json")):
        d = load_json(mp, {}) or {}
        name = mp.parent.parent.name
        offered = [{"name": p.get("name"), "description": (p.get("description") or "")[:140],
                    "installed": f"{p.get('name')}@{name}" in installed}
                   for p in d.get("plugins", [])]
        markets.append({"name": name, "plugin_count": len(offered), "plugins": offered})

    user = scan_components(cd, "user")
    user_skills = []
    for sk in sorted((cd / "skills").glob("*/SKILL.md")):  # follows symlinks
        m, n = frontmatter(sk)
        target = os.path.realpath(sk.parent)
        user_skills.append({"name": m.get("name", sk.parent.name), "lines": n, "source": target,
                            "description": m.get("description", "")[:160]})

    hooks = {ev: len(v) for ev, v in (settings.get("hooks") or {}).items()}
    perms = settings.get("permissions", {}) or {}
    mcp_user = load_json(Path.home() / ".claude.json", {}) or {}
    return {
        "settings": {"model": settings.get("model"), "effortLevel": settings.get("effortLevel"),
                     "hooks_by_event": hooks, "statusLine": bool(settings.get("statusLine")),
                     "allow_rules": len(perms.get("allow", [])), "deny_rules": len(perms.get("deny", [])),
                     "defaultMode": perms.get("defaultMode"), "env_keys": sorted((settings.get("env") or {}).keys()),
                     "skillOverrides": settings.get("skillOverrides"),
                     "other_keys": sorted(settings.keys())},
        "user_mcp_servers": sorted((mcp_user.get("mcpServers") or {}).keys()),
        "plugins": plugins,
        "marketplaces": markets,
        "user_skills": user_skills,
        "user_agents": user["agents"],
        "rules": [p.name for p in (cd / "rules").glob("**/*.md")],
        "claude_md_lines": frontmatter(cd / "CLAUDE.md")[1],
    }


def memory(cd):
    out = []
    for mem in sorted((cd / "projects").glob("*/memory")):
        files = [f for f in mem.glob("*.md") if f.name != "MEMORY.md"]
        if not files:
            continue
        types = C()
        items = []
        for f in files:
            m, n = frontmatter(f)
            t = m.get("type") or (m.get("metadata") and "?") or f.name.split("_")[0]
            types[t] += 1
            items.append({"file": f.name, "type": t, "lines": n, "description": m.get("description", "")[:140]})
        idx = mem / "MEMORY.md"
        out.append({"project": mem.parent.name, "count": len(files), "types": dict(types),
                    "index_lines": frontmatter(idx)[1] if idx.exists() else 0, "items": items})
    agent_mem = sorted(p.name for p in (cd / "agent-memory").glob("*")) if (cd / "agent-memory").exists() else []
    return {"projects": out, "agent_memory_dirs": agent_mem}


# ---------------------------------------------------------------- usage
def first_prompt(f):
    for line in f.open(errors="replace"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        c = (d.get("message") or {}).get("content")
        if d.get("type") == "user" and isinstance(c, str) and not d.get("isMeta") and not c.startswith("<"):
            return c[:30]
    return None


def automated_sessions(files, threshold=5):
    """Sessions whose opening prompt shares a 30-char prefix with >= threshold others: scripted runs."""
    prefix = {f: first_prompt(f) for f in files}
    counts = C(v for v in prefix.values() if v)
    return {f for f, v in prefix.items() if v and counts[v] >= threshold}


def usage(cd, since):
    tools, skills, agents, mcp, models, slash = C(), C(), C(), C(), C(), C()
    projects, hours, weekdays, days = C(), C(), C(), C()
    plugin_attr, skill_attr = C(), C()
    perm_modes, efforts, branches = C(), C(), C()
    sessions = {}
    tool_errors, interrupts, corrections, compactions = C(), 0, [], 0
    prompt_lens = []
    bash_heads = C()

    files = [f for f in (cd / "projects").glob("*/*.jsonl") if f.stat().st_mtime >= since]
    sub_files = [f for f in (cd / "projects").glob("*/*/subagents/*.jsonl") if f.stat().st_mtime >= since]
    auto = automated_sessions(files)
    auto_projects = C(f.parent.name for f in auto)
    auto_ids = {f.stem for f in auto}
    sub_tools, sub_mcp = C(), C()  # subagent transcripts live at <project>/<session>/subagents/
    for f in sub_files:
        if f.parent.parent.name in auto_ids:
            continue
        for line in f.open(errors="replace"):
            if '"tool_use"' not in line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            for c in (d.get("message") or {}).get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    sub_tools[c.get("name", "?")] += 1
                    if c.get("name", "").startswith("mcp__"):
                        sub_mcp[c["name"].split("__")[1]] += 1
    for f in files:
        if f in auto:
            continue
        try:
            fh = f.open(errors="replace")
        except Exception:
            continue
        sid = f.stem
        s = sessions.setdefault(sid, {"start": None, "end": None, "user_msgs": 0, "tool_calls": 0, "cwd": None})
        for line in fh:
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = ts(d.get("timestamp"))
            if t is None or t < since:
                continue
            s["start"] = min(s["start"] or t, t)
            s["end"] = max(s["end"] or t, t)
            if d.get("cwd") and not s["cwd"]:
                s["cwd"] = d["cwd"]
            if d.get("permissionMode"):
                perm_modes[d["permissionMode"]] += 1
            if d.get("effort"):
                efforts[str(d["effort"])] += 1
            if d.get("gitBranch"):
                branches[d["gitBranch"]] += 1
            if d.get("attributionPlugin"):
                plugin_attr[d["attributionPlugin"]] += 1
            if d.get("attributionSkill"):
                skill_attr[d["attributionSkill"]] += 1
            if isinstance(d.get("totalCostUSD"), (int, float)):
                s["cost"] = max(s.get("cost", 0), d["totalCostUSD"])
            if isinstance(d.get("totalLinesAdded"), int):
                s["lines_added"] = max(s.get("lines_added", 0), d["totalLinesAdded"])
            if d.get("type") == "system" and "compact" in str(d.get("subtype", "")).lower():
                compactions += 1
            msg = d.get("message") or {}
            content = msg.get("content")
            if d.get("type") == "assistant":
                if msg.get("model"):
                    models[msg["model"]] += 1
                for c in content if isinstance(content, list) else []:
                    if not isinstance(c, dict) or c.get("type") != "tool_use":
                        continue
                    name, inp = c.get("name", "?"), c.get("input") or {}
                    tools[name] += 1
                    s["tool_calls"] += 1
                    if name == "Skill":
                        skills[inp.get("skill", "?")] += 1
                    elif name in ("Agent", "Task"):
                        agents[inp.get("subagent_type") or "general-purpose"] += 1
                    elif name == "Bash":
                        for seg in re.split(r"&&|;|\|\|", inp.get("command") or ""):
                            w = seg.strip().split()
                            if w and w[0] not in ("cd", "set", "export") and not re.match(r"^\w+=", w[0]):
                                bash_heads[os.path.basename(w[0])] += 1
                                break
                    if name.startswith("mcp__"):
                        mcp[name.split("__")[1]] += 1
            elif d.get("type") == "user" and not d.get("isSidechain") and not d.get("isMeta"):
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get("type") == "tool_result" and c.get("is_error"):
                            tool_errors["tool_result_error"] += 1
                        if isinstance(c, dict) and c.get("type") == "text" and INTERRUPT in c.get("text", ""):
                            interrupts += 1
                    continue
                if not isinstance(content, str) or content.startswith("<"):
                    continue
                if INTERRUPT in content:
                    interrupts += 1
                    continue
                s["user_msgs"] += 1
                prompt_lens.append(len(content))
                if CORRECTION.match(content.strip()) and len(corrections) < 60:
                    corrections.append(content.strip()[:200])
                lt = datetime.fromtimestamp(t)
                hours[lt.hour] += 1
                weekdays[lt.strftime("%a")] += 1
                days[lt.strftime("%Y-%m-%d")] += 1
        fh.close()

    for s in sessions.values():
        if s["cwd"]:
            projects[s["cwd"].replace(str(Path.home()), "~")] += 1
    real = [s for s in sessions.values() if s["start"]]
    durations = sorted((s["end"] - s["start"]) / 60 for s in real)
    # history.jsonl: what the user actually typed, incl. slash commands
    hist = cd / "history.jsonl"
    typed = 0
    if hist.exists():
        for line in hist.open(errors="replace"):
            try:
                d = json.loads(line)
            except Exception:
                continue
            if (ts(d.get("timestamp")) or 0) < since:
                continue
            typed += 1
            disp = (d.get("display") or "").strip()
            if disp.startswith("/"):
                slash[disp.split()[0]] += 1

    pl = sorted(prompt_lens)
    med = lambda xs: xs[len(xs) // 2] if xs else 0
    return {
        "sessions": len(real),
        "automated_sessions_excluded": len(auto), "automated_by_project": auto_projects.most_common(),
        "user_prompts": len(pl), "typed_history_entries": typed,
        "prompt_len_median": med(pl), "prompt_len_p90": pl[int(len(pl) * .9)] if pl else 0,
        "session_minutes_median": round(med(durations), 1),
        "session_minutes_p90": round(durations[int(len(durations) * .9)], 1) if durations else 0,
        "total_cost_usd": round(sum(s.get("cost", 0) for s in real), 2),
        "total_lines_added": sum(s.get("lines_added", 0) for s in real),
        "tools": tools.most_common(), "skills_via_tool": skills.most_common(),
        "slash_commands": slash.most_common(60), "subagents": agents.most_common(),
        "mcp_servers": mcp.most_common(), "models": models.most_common(),
        "subagent_transcripts": len(sub_files), "subagent_tools": sub_tools.most_common(30),
        "subagent_mcp_servers": sub_mcp.most_common(),
        "bash_commands": bash_heads.most_common(40),
        "plugin_attribution": plugin_attr.most_common(), "skill_attribution": skill_attr.most_common(),
        "permission_modes": perm_modes.most_common(), "effort": efforts.most_common(),
        "projects": projects.most_common(40), "branches_top": branches.most_common(15),
        "hour_of_day": [hours.get(h, 0) for h in range(24)],
        "weekday": {k: weekdays.get(k, 0) for k in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]},
        "active_days": len(days), "busiest_days": days.most_common(10),
        "interrupts": interrupts, "tool_errors": sum(tool_errors.values()),
        "compactions": compactions,
        "correction_samples": corrections,
    }


def gaps(inv, use):
    """Things available but never (or barely) used in the window."""
    used_skills = {k.split(":")[-1] for k, _ in use["skills_via_tool"]}
    used_skills |= {k.lstrip("/").split(":")[-1] for k, _ in use["slash_commands"]}
    used_agents = {k.split(":")[-1] for k, _ in use["subagents"]}
    unused_skills, unused_agents, disabled = [], [], []
    for s in inv["user_skills"]:
        if s["name"] not in used_skills:
            unused_skills.append(f"user:{s['name']}")
    for p in inv["plugins"]:
        if not p["enabled"]:
            disabled.append(p["id"])
            continue
        unused_skills += [f"{p['id']}:{n}" for n in p["skills"] + p["commands"] if n not in used_skills]
        unused_agents += [f"{p['id']}:{n}" for n in p["agents"] if n not in used_agents]
    unused_agents += [f"user:{a['name']}" for a in inv["user_agents"] if a["name"] not in used_agents]
    builtin = ["Agent", "Skill", "TaskCreate", "WebSearch", "WebFetch", "Monitor", "CronCreate",
               "EnterPlanMode", "AskUserQuestion", "Workflow", "Artifact", "LSP", "NotebookEdit", "ScheduleWakeup"]
    tool_counts = dict(use["tools"])
    return {"unused_skills": unused_skills, "unused_agents": unused_agents, "disabled_plugins": disabled,
            "builtin_tools_rarely_used": {t: tool_counts.get(t, 0) for t in builtin if tool_counts.get(t, 0) < 5}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=90)
    ap.add_argument("--claude-dir", default=str(Path.home() / ".claude"))
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    cd = Path(a.claude_dir)
    since = time.time() - a.days * 86400
    t0 = time.time()
    inv = inventory(cd)
    use = usage(cd, since)
    report = {"generated": datetime.now(timezone.utc).isoformat(), "window_days": a.days,
              "inventory": inv, "memory": memory(cd), "usage": use, "gaps": gaps(inv, use)}
    for p in inv["plugins"]:  # keep the JSON readable; details stay in skill lists above
        p.pop("_skill_detail"); p.pop("_agent_detail")
    out = Path(a.out or f"claude-usage-{datetime.now():%Y%m%d}.json")
    out.write_text(json.dumps(report, indent=1, default=str))
    print(f"wrote {out} ({out.stat().st_size // 1024} KB) in {time.time() - t0:.1f}s: "
          f"{use['sessions']} sessions, {use['user_prompts']} prompts, {len(inv['plugins'])} plugins", file=sys.stderr)


if __name__ == "__main__":
    main()
