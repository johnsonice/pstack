# Syncing this fork

This repo is a fork of [`backnotprop/pstack`](https://github.com/backnotprop/pstack). That repo mirrors [`cursor/plugins/pstack`](https://github.com/cursor/plugins/tree/main/pstack) and adds its own edits: the top of `README.md` and harness-neutral rewrites in some skills. This fork adds two small edits on top: the install command in `README.md` and this file.

```text
cursor/plugins/pstack  ->  backnotprop/pstack  ->  johnsonice/pstack
```

Two branches keep those edits safe:

- `upstream` holds Cursor's files exactly, with no local edits.
- `main` is `upstream` plus the mirror's edits and this fork's edits.

Never copy Cursor's files onto `main` directly. That erases the edits.

## Option A: pull from backnotprop (usual)

backnotprop already syncs Cursor and rewrites new Cursor-only text, so merging their `main` is usually enough.

1. Add their repo as a remote, once. If you cloned with `gh repo clone`, it already exists as `upstream`. Rename it with `git remote rename upstream backnotprop` so it doesn't clash with the `upstream` branch.

   ```bash
   git remote add backnotprop https://github.com/backnotprop/pstack.git
   ```

2. Merge their `main`, then mirror their `upstream` branch so Option B still works later:

   ```bash
   git fetch backnotprop
   git switch main
   git merge backnotprop/main
   git push origin main
   git push origin refs/remotes/backnotprop/upstream:refs/heads/upstream
   ```

   A conflict is usually in the top of `README.md`. Keep this fork's install command (`npx skills add johnsonice/pstack`) and take the rest of their change.

   If the last push is rejected as non-fast-forward, the two `upstream` branches diverged because this fork once synced Cursor itself (Option B). Skip that push, and use Option B when you need Cursor's latest.

## Option B: sync straight from Cursor

Use this when backnotprop falls behind Cursor.

1. Copy Cursor's latest `pstack/` folder onto the `upstream` branch:

   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git /tmp/cursor-plugins
   git -C /tmp/cursor-plugins sparse-checkout set pstack
   git fetch origin
   git switch -C upstream origin/upstream
   rsync -a --delete --exclude .git --exclude MIRROR.md /tmp/cursor-plugins/pstack/ ./
   git add -A
   git commit -m "upstream: cursor/plugins/pstack @ $(git -C /tmp/cursor-plugins rev-parse --short HEAD)"
   ```

2. Merge it into `main`. Git applies only what changed upstream and keeps the mirror's edits:

   ```bash
   git switch main
   git merge upstream
   ```

   A conflict means Cursor changed a line this mirror also changed. Keep Cursor's new meaning and reapply the harness-neutral wording.

3. Refresh the bundled Comment Sicko prompt, run this fork's lint with `--fix`, then check that no new Cursor-only instructions arrived:

   ```bash
   cp agents/comment-sicko.md skills/no-comments/references/comment-sicko.md
   python3 scripts/check-skills.py --fix
   git diff upstream@{1} upstream -- skills | grep -nE '\.cursor/|agent-transcripts|cursor-team-kit|create-skill|Task|AskQuestion|pstack/skills|git show origin/main'
   ```

   Rewrite any new hits the same way as the existing edits. The Harness section in `skills/poteto-mode/SKILL.md` lists the mappings. `pstack/skills` paths become `<pstack skills dir>` (the multi-phase-plan playbook explains it). `check-skills.py` enforces the fork's other two rules: a `name:` equals its folder name, and a skill another skill routes to has no `disable-model-invocation: true`. The lint fixes the second itself and reports the first.

4. Push both branches:

   ```bash
   git push origin main upstream
   ```
