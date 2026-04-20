---
name: polinrider-scan
description: Scan for the PolinRider DPRK/Lazarus supply-chain malware (March–April 2026 campaign). Use when the user asks to check for PolinRider, audit a project or machine for the DPRK npm/VS Code supply-chain compromise, or verify that postcss/next/webpack/tailwind config files, build caches, VS Code tasks.json droppers, or git hooks are clean. Triggers on phrases like "scan for PolinRider", "check for the DPRK supply-chain malware", "audit my repos for the config.bat/temp_auto_push stuff", or any reference to the IOCs in references/iocs.md. Run this proactively if the user reports unexplained `node -e` processes, mysterious `createRequire` imports in config files, unknown `tailwindcss-style-animate`-style packages, or unexpected `.vscode/tasks.json` with `folderOpen`.
---

# PolinRider Malware Scan

This skill performs a two-step security scan for the **PolinRider** malware — a DPRK/Lazarus supply-chain attack (March–April 2026) that targets JavaScript/Node.js developers, steals cryptocurrency wallets, and propagates via git force-push.

The heavy lifting lives in [`scripts/scan.sh`](scripts/scan.sh), which:

1. Downloads and runs the official [`polinrider-scanner.sh`](https://github.com/OpenSourceMalware/PolinRider/blob/main/polinrider-scanner.sh) from OpenSourceMalware — the authoritative, regularly updated IOC scanner.
2. Runs extended checks that complement the upstream scanner: build-cache persistence, VS Code droppers, fake binary payloads, git/husky hook injection, obfuscation heuristics, system persistence, and (in global scope) GitHub repository search.

Your job is to decide the scope, invoke the script, interpret the structured output, and drive remediation when infections are found.

## Step 1: Decide the scope

Determine scope in this order:

1. If the user passed an explicit argument, honor it:
   - `local` → scope = local, scan_root = cwd
   - `global` → scope = global, scan_root = `$HOME`
   - An absolute or `~`-prefixed path → scope = local, scan_root = that path
2. Otherwise, detect install location:
   - This skill resolved from `$CLAUDE_PROJECT_DIR/.claude/skills/polinrider-scan/` or `./.claude/skills/polinrider-scan/` → **local**. scan_root = `$PWD`. Skips `PERSISTENCE` and `GITHUB_SCAN` sections.
   - This skill resolved from `~/.claude/skills/polinrider-scan/` → **global**. scan_root = `$HOME`. Runs everything.

State the resolved scope and `scan_root` in one sentence before running the script.

## Step 2: Run the scanner

```bash
bash "$(dirname "$0")/scripts/scan.sh" <scope> <scan_root>
```

In practice, invoke it with the absolute path to `scan.sh` inside the installed skill directory. The script writes a structured report to stdout, organized as `== SECTION ==` blocks. Sections include:

- `META` — scope, host, timestamps
- `OSM_SCANNER` — output of the official scanner (Step 1)
- `PROCESSES`, `NETWORK_C2` — active threats
- `SIGNATURES`, `CONFIG_FILES`, `BUILD_CACHES` — payload detection
- `VSCODE_DROPPERS`, `FAKE_BINARIES` — VS Code-based droppers
- `PROPAGATION_ARTIFACTS`, `NPM_PACKAGES`, `OBFUSCATION_HEURISTICS`
- `PERSISTENCE`, `GITHUB_SCAN` — global-scope only

Capture the output. The script always exits 0 — the presence or absence of findings is encoded in the text of each section.

## Step 3: Interpret the output

For each section, check whether findings are real or benign:

- **Signature hits on the skill itself, the IOC reference file, or known scanners** (`polinrider-scanner*`, `scan.sh`, `iocs.md`, OSM repo) are benign — these files deliberately reference the patterns.
- **`CONFIG_FILES` `SUSPECT` entries** — open the file. If the long line is a minified bundle (legitimate for some build artifacts) it's a false positive. If it's a plain config file with `createRequire` + trailing whitespace + high max-line length, it's infected.
- **`BUILD_CACHES` `INFECTED` entries** — always real. The cache preserves compiled infected code even after source cleanup.
- **`PROCESSES` matches** — real if the command line contains any IOC; this is an active infection, handle it first.
- **`GITHUB_SCAN` counts > 0** — real unless the file is a documented scanner. Report repo + path.

If you need to look up what a given signature means, read [`references/iocs.md`](references/iocs.md).

## Step 4: Remediate (only if infections are found)

In this order:

1. **Kill active processes** — `kill -9 <pid>` for any process in `PROCESSES` with IOCs in its args.
2. **Stop running dev servers** (`next dev`, `vite`, etc.) before clearing caches, or they'll immediately rewrite them.
3. **Delete build caches** — `.next/`, `.cache/`, `.turbo/`, `.parcel-cache/`, `.vite/` in any directory flagged by `BUILD_CACHES`.
4. **Clean config files** — remove everything after the trailing-whitespace bomb on the `export` line, and remove any `createRequire` import the malware injected into otherwise-simple ESM configs.
5. **Delete propagation scripts** — `config.bat`, `temp_auto_push.bat`, `temp_interactive_push.bat` wherever found, plus their entries in `.gitignore`.
6. **Delete VS Code droppers** — malicious `.vscode/tasks.json` and any fake font/binary payload file (check with `file -b <path>`).
7. **Clean git hooks** — `.git/hooks/*` and `.husky/*` entries containing `config.bat`, `temp_auto_push`, force-push, or `amend --no-verify`.
8. **Remove malicious npm packages** — delete from `package.json`, remove the `node_modules` directory, regenerate the lock file.
9. **Commit and push fixes** to each affected repo (regular push; never `--force`).
10. **Tell the user to rotate credentials** — any API keys, tokens, SSH keys, or crypto seed phrases accessible from this machine should be considered compromised. Recommend revoking them even if no active exfiltration is visible.
11. **Tell the user to notify collaborators** — anyone who cloned their repos may be infected.

Do every applicable step automatically; confirm only before destructive actions the user might object to (force-pushes, mass credential rotation).

## Step 5: Report

Emit this structure (fill every section, even if empty):

```
## PolinRider Scan Results (scope: LOCAL|GLOBAL, root: <path>)

### Step 1 — Official OSM scanner
<exit status and any findings from the upstream script, or "skipped (offline)">

### Step 2 — Extended checks

**Active threats**
| Type | Location | Action taken |
|---|---|---|

**Infections found**
| Category | File/Location | Details | Remediated? |
|---|---|---|---|

**Clean checks**
- [ ] Processes
- [ ] C2 network connections
- [ ] Source signatures
- [ ] Config files
- [ ] Build caches
- [ ] VS Code droppers
- [ ] Fake binaries
- [ ] Propagation scripts / .gitignore / git hooks
- [ ] npm packages
- [ ] Obfuscation heuristics
- [ ] System persistence (global only)
- [ ] GitHub repos (global only)
```

If anything was remediated, end with a short action list for the user: credentials to rotate, collaborators to notify, repos that still need a push.
