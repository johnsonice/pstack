#!/usr/bin/env python3
"""Lint pstack's skills for the two rules this fork needs outside Cursor.

1. A SKILL.md `name:` equals its folder name. The skills CLI and Codex look a
   skill up by that name.
2. A skill that another skill routes to has no `disable-model-invocation: true`.
   Claude Code refuses Skill-tool calls to a flagged skill and tells the model
   not to work around it, which would break poteto-mode's routing to how,
   unslop, the principles, and the rest. Entry-point skills nothing routes to
   keep the flag.

Usage: scripts/check-skills.py [--fix] [--graph]
  --fix    remove the flag from routed skills (rule 2); rule 1 is reported only
  --graph  print which skills each skill routes to
Exit 1 when a problem remains, else 0.
"""
import re
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parent.parent / "skills"
FLAG = re.compile(r"^disable-model-invocation:[ \t]*true[ \t]*\n", re.M)


def frontmatter(text):
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---", 4)
    fields = {}
    for line in text[4:end].splitlines():
        if line[:1].isspace() or ": " not in line:
            continue
        key, value = line.split(": ", 1)
        fields[key.strip()] = value.strip().strip("\"'")
    return fields


def routes(skill, text, plain, principles):
    targets = set()
    for name in plain:
        if name == skill:
            continue
        n = re.escape(name)
        if re.search(rf"\*\*{n}\*\*|`/?{n}`|(?<![\w/-])/{n}\b|\b{n} skill", text):
            targets.add(name)
    for short, full in principles.items():
        if full == skill:
            continue
        if re.search(rf"\*\*{re.escape(short)}\*\*|\b{re.escape(full)}\b", text):
            targets.add(full)
    return targets


def main(argv):
    fix = "--fix" in argv
    graph = "--graph" in argv
    names = sorted(p.name for p in SKILLS.iterdir() if (p / "SKILL.md").is_file())
    principles = {n[len("principle-"):]: n for n in names if n.startswith("principle-")}
    plain = [n for n in names if not n.startswith("principle-")]

    routed = set()
    for skill in names:
        text = "\n".join(p.read_text() for p in sorted((SKILLS / skill).rglob("*.md")))
        targets = routes(skill, text, plain, principles)
        routed |= targets
        if graph and targets:
            print(f"{skill}: {', '.join(sorted(targets))}")

    problems = []
    for skill in names:
        path = SKILLS / skill / "SKILL.md"
        text = path.read_text()
        name = frontmatter(text).get("name")
        if name != skill:
            problems.append(f"{path.relative_to(SKILLS.parent)}: name is {name!r}, expected {skill!r}")
        if skill in routed and FLAG.search(text):
            if fix:
                path.write_text(FLAG.sub("", text, count=1))
                print(f"fixed {skill}: removed disable-model-invocation")
            else:
                problems.append(
                    f"{path.relative_to(SKILLS.parent)}: disable-model-invocation: true, but another skill routes to it"
                )

    for problem in problems:
        print(problem, file=sys.stderr)
    print(f"{len(names)} skills, {len(routed)} routed, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
