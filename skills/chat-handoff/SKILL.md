---
name: chat-handoff
description: >-
  Generate a complete machine-transfer handoff when the current
  conversation must continue on another computer or in a fresh session
  with zero shared context. Produces two deliverables: a self-contained
  markdown handoff document (mission, verified repo state, decision log
  with reversals, verbatim requirements, communication profile,
  artifacts and account access, machine-transfer checklist, knowledge
  gained, dead ends, next steps, boot sequence) and a short chat reply
  with what to do on the old machine plus the clone command for the new
  one. Use whenever the user wants to hand off, migrate, or transfer
  this chat, session, or work to another machine or a new laptop, asks
  for a handover/handoff document, or says they are switching computers
  and need to continue the work there.
---

# chat-handoff

This conversation is moving to a different computer. A brand-new session there picks up the work with ZERO context — no chat history, no session memory, no user-scope configuration, none of this machine's local state, possibly a fresh clone. Produce two deliverables: **(A)** a handoff document, written as a markdown file the user carries across and feeds to the new session as its first input; **(B)** a short chat reply telling the user what to do — anything that must happen on THIS machine before leaving, the clone command for the new machine, and the steps to start the new session. The bar for A is compaction-grade: nothing may be lost.

## Step 0 — Context integrity

If any part of this conversation is no longer visible to you (compaction, truncation, summarized history), you must say so: add a **Context integrity** note right after Section 0 of the document, naming the earliest point you can actually see and what is therefore reconstructed rather than known. Recover what you can from durable evidence (git log, files created, plan/TODO diffs, scratch files) and mark it `[BELIEVED]`. Never present a partially-visible conversation as fully known.

## Step 1 — Collect

Re-read everything visible, from the earliest message. Collect every: requirement (stated or implied); decision with its why and its rejected alternatives; instruction that was later overturned, and what replaced it; artifact produced or touched; link, PR, issue, ticket, id; command that mattered and its outcome; discovered gotcha or dead end; unresolved thread; preference the user expressed. Facts that came from tool output rather than from the user are first-class: queries run, values measured, ids discovered. Subagent results exist only as their summaries — capture what each helper was asked, what it concluded, and where its output landed (file, branch, PR).

## Step 2 — Verify with tools (don't trust memory)

If the work involves repos or files, check reality before describing it (read-only). Your own session-start snapshot may already be stale — treat it as unverified.

- **Repo identity**: `gh repo view --json nameWithOwner,url,isPrivate,defaultBranchRef` (fallback: derive `owner/repo` from `git remote -v`). Note extra remotes and private vs public.
- **Exact state**: `git rev-parse HEAD`, `git status --porcelain`, `git branch --show-current`, `git log --oneline -15`, `git stash list`, `git worktree list`, sync vs remote (`git fetch` then `git status -sb`).
- **PRs / CI**: for open PRs, `gh pr view <n> --json title,state,reviewDecision,comments` plus unresolved review-thread contents; for failing CI, `gh run list` then `gh run view <id> --log-failed` — transcribe the failing step and a verbatim error excerpt into the document (logs expire; a link is not enough).
- The current content of any file central to in-progress work.
- Background processes/dev servers started this session: ports, restart commands, still running or not.
- **Tool versions measured, not recalled**: run `node -v`, `npm -v`, etc. for whatever the stack needs and use the real output.

Skip what doesn't apply. Pure-discussion chats: skip all of it without narrating the skip, and mark facts `[BELIEVED]` accordingly.

## Step 3 — Write the handoff document

Addressed to the new assistant ("You are continuing…"), fully self-contained: no "as discussed above". Repo files by repo-relative path; absolute paths only where they name things to copy off the old machine, flagged "old machine, do not replicate". Relative dates → absolute; stamp the document `As of <YYYY-MM-DD HH:MM TZ>`. Write in English; if the chat ran in another language, quote the user in the original with a translation alongside.

**Pointer rule.** Where a fact lives in a durable file INSIDE the repo (the project's own instruction file, plan, README) that is committed, pushed, and still accurate, point to it instead of duplicating. If this session made it stale or it is uncommitted, say so at the pointer and inline the delta. **User-scope configuration does not travel**: global instruction files, custom commands, per-project memory, connected tool servers — they exist only on this machine. Restate their operative rules verbatim inline; commit/PR/branch-naming conventions are the highest-risk case: quote them.

Sections — every one either populated or explicitly `none — <reason>`. Silently omitting a section is a failure.

**0. Read this first** — five lines max, written LAST: mission in one sentence; repo + branch + the exact HEAD SHA this document describes; one-sentence current state; the single next action. Everything below is reference.
1. **Mission** — project; canonical repo(s) as `owner/repo` + URL; default and working branch; whether HEAD is pushed; a paragraph on why this workstream exists. No clone command here — that lives in deliverable B.
2. **State of play** — DONE (and how verified), IN PROGRESS (exact stopping point: file, function, what half-finished looks like), BLOCKED (on what). Then **Already done — do NOT repeat**: every one-time side-effecting action (migrations run, assets uploaded, messages sent, purchases, renames).
3. **Time-sensitive** — deadlines and what they are bound to; anything that expires (tokens, trials, preview URLs, CI log retention) with dates; scheduled/recurring jobs created this session and where they run; background processes still running on the old machine and the command to stop each. "None" is a valid answer — state it.
4. **Decision log** — each decision: what, why, alternatives rejected and why. Then a **Reversals** subsection: instructions adopted then overturned — original ask, what replaced it, and what residue the abandoned direction left (files, branches, config, stale plan lines) that must not be mistaken for live work. Latest instruction wins. Date entries when it matters.
5. **Requirements, constraints & working style** — everything asked for, incl. small preferences and explicit non-goals ("do NOT…"). QUOTE the user verbatim where wording matters, each quote with its place in the timeline — never quote a retracted instruction without marking it retracted. Restate standing rules the task depends on (see Pointer rule). Then a **Communication profile**:
   - **Language** — chat language; whether the user writes in a non-native language (read past typos, don't mirror or remark on them); preferred reply language if stated.
   - **Technical register, by domain** — expert domains (skip basics; never explain the user's own tools back to them) vs beginner domains (justify choices so they can sanity-check the reasoning, not the specifics). State each domain separately; never average them.
   - **Response shape** — verbosity, formatting, tone, how the user signals corrections.
   - **Permission posture** — what may be done unasked vs what needs a check-in (edit? commit? push? open PRs? merge? run migrations? spend money?), with the user's actual approval phrasings.
   - Every claim above carries one short quote or observed behavior as evidence.
6. **Artifacts & links** — PRs (number, title, state, review status, unresolved thread contents), issues, deployments, dashboards, docs, spreadsheets, designs; commits from this work (hash + subject + **pushed or not** — note rebases, since unpushed hashes won't resolve); files created/modified/deleted, one line each; published pages or artifacts (URL + the local source file that produced them). Then **Access & accounts**: for each external service — the exact resource (name/id), which identity owns it, and what the user must do on the new machine to regain access (login command, browser sign-in, tool-server re-auth, extension re-pairing). Flag anything whose ONLY copy lives in a cloud tool rather than the repo.
7. **Machine-transfer checklist** — what git will NOT carry, stated as **what was already prepared** (deliverable B made it happen on this machine), not as advice: the WIP branch pushed and its name; untracked paths listed INDIVIDUALLY with keep/drop verdicts (never "there are untracked files"); stashes materialized into a branch/patch or declared abandoned; local files/dirs outside the repo (absolute path + size); env/secret files (path + variable NAMES + where each value is issued — never values); local databases; config hidden by a global gitignore (inline small files in full); required tools with measured versions; platform constraints — including anything that has never been built or run on this machine and is therefore unverified.
8. **Knowledge gained** — non-obvious facts: root causes, API quirks, version constraints, workarounds, ordering traps. For tool-derived facts: the command that produced it, the value, and when it was true. Cheap to re-derive → give the command; expensive, rate-limited, paid, or gone (expired logs, one-shot output, a subagent's search) → transcribe the value in full.
9. **Dead ends — do NOT retry** — fixed shape per entry: what was tried → exact failure (error text, command) → why it is not being retried → what to do instead. Include approaches the user vetoed, dead remote branches, closed/abandoned PRs, reverted commits. This section is never abbreviated.
10. **Next steps** — ordered; item 1 is exactly what you would do next if you kept working. Acceptance criteria where known.
11. **Open questions** — everything that still needs the user.
12. **Boot sequence** — exact commands in order. Step 0 verifies location AND revision: `git remote -v` matches Mission; `git log --oneline -1` shows the documented SHA or a descendant of it; `git status --porcelain` matches the described tree — on any mismatch, STOP and report the difference before acting on State of play. Then: branch checkout, WIP fetch, deps install, and the build/tests that should already pass — each as a literal command with its expected result.

End the document with: "Before doing anything else: state your understanding of the mission, current state, and immediate next step in a few bullets; flag anything on this machine that contradicts this document; then run the Boot sequence. If any boot step fails or differs from what this document predicts, stop and report it — the failure is not the task unless Next steps says so."

## Rules

- Exact things exactly: full URLs, ids, hashes, versions, error messages, commands with flags, precise paths. Never "the config file" — always the path.
- **Secrets override exactness.** Never inline credentials, tokens, keys, connection strings, or URLs/log lines that embed them — redact to shape (`postgres://<user>:<pw>@<host>/<db>`) plus where to re-obtain (which console, which page). Assume the file will be shared across devices and synced through clouds: treat it as untrusted storage. Never write the handoff file inside a repo working tree.
- Mark facts with literal tokens: `[VERIFIED <YYYY-MM-DD>]` — you ran the check this session; say which command — or `[BELIEVED]` — recalled, unchecked. The default is `[BELIEVED]`.
- **Repo-name rule.** Identify repos as `owner/repo` exactly as the host spells them — assume the user does not remember the names. This machine's folder name may differ from the repo name; that is an artifact of this machine — never reproduce it, never build a clone command that renames the target. In-repo paths always repo-relative. Multi-repo work: identify each repo, state the required on-disk relationship (siblings under one parent? nested? path-dependent config?), and which repo is the new chat's project directory.
- Pure-discussion work gets the same rigor: conclusions, arguments, positions taken, next steps.

## Deliverable A — the file

- Path: `~/Desktop/handoffs/<slug>-<timestamp>.md` (or a folder the user prefers) — `<slug>` a short kebab-case workstream name (project + topic), `<timestamp>` from `date +%Y-%m-%d-%H%M`. Create the directory if needed. Never inside a repo.
- Plain markdown addressed to the new assistant; normal triple-backtick blocks inside; no clone command and no shell bootstrap — the repo exists before this document is ever read.
- If a file-sending tool is available, send the file too so the user can download it directly.

## Deliverable B — the chat reply

Addressed to the human. Short — setup instructions, not a summary of the document. Unless the user has said they launch sessions from a terminal, assume they create sessions through an app GUI: the clone is then the ONLY terminal step, and you must not emit session-launch commands or app-internal slash commands. In order:

1. **On THIS machine first** — if the tree is dirty, has unpushed commits, or has stashes: the exact snapshot commands (`git checkout -b wip/<slug> && git add -A && git commit -m "wip: handoff snapshot" && git push -u origin wip/<slug>`) and an offer to run them now, plus any local-only files that must be copied by hand. If everything is clean and pushed, say "nothing to carry" explicitly.
2. The absolute path of the file you wrote + a 3–5 bullet TL;DR.
3. **The clone** — one `bash` block: `cd <parent-dir> && gh repo clone owner/repo` (pick a concrete parent and note the user may substitute their own — keeping the same parent path across machines helps anything that keys state off absolute paths; real `owner/repo` from Step 2, never a placeholder; every repo the work spans; add `--recurse-submodules` if submodules exist). Prose notes, not command blocks: this creates a folder named exactly `<repo>` (the old machine's folder name is deliberately not reused); `gh auth login` must precede it for private repos; `git lfs install` if the repo uses LFS.
4. **Starting the new session**: copy the `.md` over (AirDrop, drive, sync) → new session with the cloned folder as its project directory → first message: `Read <path where you copied it> and follow it.` (attaching the file works too). Warn that a first session on a new machine re-shows folder-trust prompts, and list any connected tool servers or browser-extension pairings to re-authorize before starting.

## Final check

Walk sections 0–12 and confirm each is populated or marked `none — <reason>`. Then answer to yourself: why is each major decision the way it is? what already failed and must not be retried? what must not be re-run? who owns each external account? what is the single next command? If any answer requires the conversation you are about to lose, add it to the document.

Text appended after this skill invocation is additional emphasis — it deepens coverage of the named area and never removes sections or shrinks coverage of anything else.
