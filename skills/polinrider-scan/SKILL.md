---
name: polinrider-scan
description: Scan for the PolinRider DPRK/Lazarus supply-chain malware (March–April 2026). Checks running processes, config files, build caches, VS Code droppers, npm packages, git hooks, system persistence, and GitHub repos. Scope auto-adapts: project-only when installed at .claude/skills/, filesystem-wide when installed at ~/.claude/skills/.
---

# PolinRider Malware Scan

Perform a comprehensive security scan for the **PolinRider** malware (DPRK Lazarus group supply-chain attack, March–April 2026). This malware targets JavaScript/Node.js developers, steals cryptocurrency wallets, and propagates through git repositories via force-push.

The scan has **two steps**:

1. **Phase 0** — run the official [`polinrider-scanner.sh`](https://github.com/OpenSourceMalware/PolinRider/blob/main/polinrider-scanner.sh) from OpenSourceMalware (the authoritative, regularly updated IOC scanner).
2. **Phases 1–10** — AI-driven checks that extend the official scanner: caching/persistence edge cases, obfuscation heuristics, novel variant detection, and automated remediation.

Both steps must run. The AI phases are not a replacement for the upstream scanner — they complement it.

## Scope detection (do this FIRST)

Determine install scope by checking where this skill lives:

- If this file exists at `$CLAUDE_PROJECT_DIR/.claude/skills/polinrider-scan/SKILL.md` or `./.claude/skills/polinrider-scan/SKILL.md` → **LOCAL scope**. Scan root = current working directory only. Skip filesystem-wide `find ~/` commands. Skip Phase 8 (system persistence). Skip Phase 9 (GitHub repos) unless user explicitly asks.
- If this file exists at `~/.claude/skills/polinrider-scan/SKILL.md` (user-global) → **GLOBAL scope**. Scan root = `$HOME`. Run all phases including system persistence and GitHub repo scan.
- If the user passed an explicit argument, honor that instead. Accepted forms: `local`, `global`, or an absolute path (`/abs/path`) or `~`-prefixed path to use as the scan root.

State the detected scope and the resolved `$SCAN_ROOT` in one sentence before starting, then execute every phase below that applies to the scope. Do NOT ask for confirmation — execute automatically. Report findings at the end in a structured table. If you find active infections, remediate them immediately.

In the commands below, `$SCAN_ROOT` means: the cwd in local scope, or `$HOME` in global scope (or the explicit path the user provided). Persistence checks in Phase 8 always run against `$HOME` regardless of `$SCAN_ROOT`.

## Phase 0: Run the official OSM scanner FIRST

Before doing any AI-driven analysis, run the upstream shell scanner from [OpenSourceMalware/PolinRider](https://github.com/OpenSourceMalware/PolinRider). It's the authoritative source of IOCs and is updated when new variants surface.

```bash
# Download to a temp file, inspect, then run
curl -fsSL -o /tmp/polinrider-scanner.sh \
  https://raw.githubusercontent.com/OpenSourceMalware/PolinRider/main/polinrider-scanner.sh

# Optional but recommended — skim the script before executing
head -50 /tmp/polinrider-scanner.sh

# Run against $SCAN_ROOT
bash /tmp/polinrider-scanner.sh "$SCAN_ROOT"
```

Capture the scanner's output. Include its findings in the final report under a dedicated "Official scanner (OSM)" section. Then continue with Phase 1 onwards — the AI phases catch variants, stale caches, and edge cases the upstream scanner may not cover yet.

If `curl` fails or the user is offline, note that Phase 0 was skipped and proceed with Phases 1–10.

## Phase 1: Active Threat Neutralization

**Check for running malware processes FIRST — kill before it can spread.** (Run this phase in both scopes — a running infection affects the whole machine.)

### 1.1 Malicious Node Processes

Search for detached `node -e` processes (the malware spawns these with `stdio: 'ignore'`, `detached: true`):

```
ps aux | grep "node -e" | grep -v grep
```

Check for ANY node process whose parent is PID 1 (launchd/init) — this means the parent died and the process was reparented, a hallmark of PolinRider:

```
ps -eo pid,ppid,comm,args | awk '$2 == 1 && /node/ {print}'
```

Look for node processes with suspicious arguments containing any of these: `global['!']`, `global['_V']`, `_$_1e42`, `MDy`, `rmcej`, `2857687`, `1111436`, `spawn`, `child_process`, `eval`:

```
ps aux | grep node | grep -v grep
```

**If found: `kill -9 <PID>` immediately.**

### 1.2 Network Connections to C2

Check for active connections to known command-and-control endpoints:

```
lsof -i -n -P | grep -i "node" | grep -v localhost
```

Known C2 domains (block these in your firewall/hosts file):
- `260120.vercel.app`
- `default-configuration.vercel.app`
- `vscode-settings-bootstrap.vercel.app`
- `vscode-settings-config.vercel.app`
- `vscode-bootstrapper.vercel.app`
- `vscode-load-config.vercel.app`
- `api.trongrid.io` (blockchain dead-drop)
- `fullnode.mainnet.aptoslabs.com` (blockchain dead-drop)
- `bsc-dataseed.binance.org` (blockchain dead-drop)
- `bsc-rpc.publicnode.com` (blockchain dead-drop)

## Phase 2: Payload Signature Scan

Search `$SCAN_ROOT` (excluding `node_modules` and `.git`) for both known variants.

### 2.1 Original Variant Signatures

| Signature | Description |
|---|---|
| `rmcej%otb%` | Obfuscation marker |
| `_$_1e42` | Decoder function name |
| `2857687` | Shuffle seed (layer 1) |
| `2667686` | Shuffle seed (layer 2) |
| `global['!']` | Global injection marker |
| `global['r'] = require` | Require hijack |
| `global['m'] = module` | Module hijack |

### 2.2 Rotated Variant Signatures (April 2026)

| Signature | Description |
|---|---|
| `Cot%3t=shtP` | Rotated obfuscation marker |
| `function MDy` or `var MDy=` | Rotated decoder function |
| `1111436` | Rotated shuffle seed (layer 1) |
| `3896884` | Rotated shuffle seed (layer 2) |
| `global['_V']` | Rotated global injection (tags `8-st1` through `8-st59`) |

### 2.3 XOR Keys and Blockchain Addresses

| Signature | Description |
|---|---|
| `2[gWfGj;<:-93Z^C` | XOR decryption key (primary) |
| `m6:tTh^D)cBz?NM]` | XOR decryption key (secondary) |
| `TMfKQEd7TJJa5xNZJZ2Lep838vrzrs7mAP` | TRON C2 address |
| `TXfxHUet9pJVU1BgVkBAbrES4YUc1nGzcG` | TRON C2 address (secondary) |
| `0xbe037400670fbf1c32364f762975908dc43eeb38759263e7dfcdabc76380811e` | Aptos C2 address |
| `0x3f0e5781d0855fb460661ac63257376db1941b2bb522499e4757ecb3ebd5dce3` | Aptos C2 address (secondary) |

### 2.4 Scan Commands

Scan all source files in `$SCAN_ROOT` for ALL signatures above. Use `grep -rl` with `--include` for `*.js`, `*.mjs`, `*.cjs`, `*.json`, `*.ts`, `*.tsx`, `*.bat`, `*.sh`, `*.woff2`, `*.woff`, `*.ttf`. Exclude `node_modules/`, `.git/`, `.next/`, `dist/`, `build/`. Also exclude any file named `polinrider-scanner` or `polinrider-scan` (legitimate scanner files referencing these patterns).

## Phase 3: Config File Infection Scan

PolinRider appends obfuscated JavaScript after hundreds of whitespace characters on the last line of config files. The file looks normal in editors because the payload is hidden off-screen.

### 3.1 Target Config Files

Scan ALL of these file patterns within `$SCAN_ROOT`:
- `postcss.config.*` (js/mjs/cjs/ts)
- `tailwind.config.*`
- `eslint.config.*`
- `next.config.*`
- `vite.config.*`
- `webpack.config.*`
- `astro.config.*`
- `gridsome.config.*`
- `vue.config.*`
- `rollup.config.*`
- `babel.config.*`
- `truffle.js`
- `.eslintrc.*`
- `App.js`, `app.js`, `index.js` (in project roots only)

### 3.2 Detection Methods

For each config file found:

1. **Long line check**: Any line > 200 characters is suspicious (legitimate config files rarely exceed this). Use `awk '{ if(length > max) max=length } END { print max+0 }'`.

2. **Trailing whitespace bomb**: Check for 50+ consecutive spaces: `grep -P '\s{50,}'` (the payload hides after spaces on the export line).

3. **`createRequire` residue**: The malware injects `import { createRequire } from 'module'` (or `from 'node:module'`) into ESM config files. If the file is a simple config (postcss, tailwind, etc.) and contains `createRequire`, it's malware residue. Remove it.

4. **Direct signature check**: `grep` each file for `global['!']`, `global['_V']`, `_$_1e42`, `MDy`, `rmcej`.

## Phase 4: Build Cache Infection (CRITICAL — Often Missed)

**This is the #1 reason the malware re-appears after cleanup.** Build tools (Next.js Turbopack, Webpack, Vite) cache compiled versions of config files. Even after cleaning the source, the cached infected version keeps executing.

### 4.1 Next.js / Turbopack Cache

```bash
find "$SCAN_ROOT" -name ".next" -type d -not -path "*/node_modules/*" | while read d; do
  hit=$(grep -rl "global\['!'\]\|_\$_1e42\|rmcej\|global\['_V'\]\|MDy" "$d/" 2>/dev/null | head -1)
  if [ -n "$hit" ]; then
    echo "INFECTED CACHE: $hit"
  fi
done
```

**The payload specifically persists in Turbopack SST files** (`.next/dev/cache/turbopack/*.sst`) — these are binary files that survive source file cleanup.

**Remediation**: Delete the entire `.next` directory. Kill any running `next dev` process FIRST or it will recreate the cache immediately.

### 4.2 Other Build Caches

Also scan:
- `.cache/` directories (Webpack, Babel)
- `.turbo/` directories (Turborepo)
- `.parcel-cache/` directories
- `.vite/` directories
- `dist/`, `build/` directories (may contain compiled infected output)

## Phase 5: VS Code Dropper Detection

PolinRider uses VS Code's `runOn: folderOpen` feature to silently execute malware when a folder is opened in the editor.

### 5.1 tasks.json Dropper

Search ALL `.vscode/tasks.json` files within `$SCAN_ROOT`:

```bash
find "$SCAN_ROOT" -name "tasks.json" -path "*/.vscode/*" -not -path "*/node_modules/*"
```

**Red flags in tasks.json:**
- `"runOn": "folderOpen"` — executes automatically when VS Code opens the folder
- `"reveal": "never"` — hides terminal output
- `"echo": false` — suppresses command echo
- `"hide": true` — hides from task list
- Commands referencing: `curl | bash`, `wget | sh`, `.woff2` files, `.bat` files, `node -e`
- UUID `e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9` (StakingGame template marker)
- Any Vercel C2 domain reference

### 5.2 Fake Binary Files as Payloads

The dropper can execute disguised files. Check ALL font/binary files within `$SCAN_ROOT`:

```bash
find "$SCAN_ROOT" -type f \( -name "*.woff2" -o -name "*.woff" -o -name "*.ttf" -o -name "*.eot" -o -name "*.otf" -o -name "*.ico" -o -name "*.dat" -o -name "*.bin" \) -not -path "*/node_modules/*" -not -path "*/.git/*"
```

For each file, verify it's actually binary: `file -b <path>`. If it reports "ASCII text", "UTF-8 text", "JavaScript", or "script" — **it's a disguised payload**.

Also check first bytes: if a "font" file starts with spaces (`0x20`) or `global` (`0x676c6f62`), it's malware.

### 5.3 VS Code Settings

**GLOBAL scope only** — check if automatic task execution is enabled:

```bash
grep -i "task.allowAutomaticTasks" ~/Library/Application\ Support/Code/User/settings.json
```

If set to `"on"`, VS Code will silently run `folderOpen` tasks without prompting. Consider setting to `"off"`.

## Phase 6: Propagation Artifact Scan

### 6.1 Batch Files

Search for malware propagation scripts within `$SCAN_ROOT`:

```bash
find "$SCAN_ROOT" -name "temp_auto_push.bat" -o -name "temp_interactive_push.bat" -o -name "config.bat" 2>/dev/null | grep -v node_modules
```

### 6.2 .gitignore Injection

The malware adds its own files to `.gitignore` to hide them. Check all `.gitignore` files for:
- `config.bat`
- `temp_auto_push.bat`
- `temp_interactive_push.bat`

```bash
find "$SCAN_ROOT" -name ".gitignore" -not -path "*/node_modules/*" | xargs grep -l "config\.bat\|temp_auto_push\|temp_interactive_push" 2>/dev/null
```

### 6.3 Git Hooks

Check for infected git hooks that propagate the malware:

```bash
find "$SCAN_ROOT" -path "*/.git/hooks/*" -type f -not -name "*.sample" | while read f; do
  if grep -q "config\.bat\|temp_auto\|force.*push\|amend.*no-verify" "$f" 2>/dev/null; then
    echo "INFECTED HOOK: $f"
  fi
done
```

Also check Husky hooks (`.husky/pre-push`, `.husky/post-commit`, etc.) for similar patterns.

## Phase 7: Malicious npm Package Detection

### 7.1 Known Malicious Packages

Search ALL `node_modules` directories within `$SCAN_ROOT` for these packages:

- `tailwindcss-style-animate`
- `tailwind-mainanimation`
- `tailwind-autoanimation`
- `tailwind-animationbased`
- `tailwindcss-typography-style`
- `tailwindcss-style-modify`
- `tailwindcss-animate-style`

```bash
for pkg in tailwindcss-style-animate tailwind-mainanimation tailwind-autoanimation tailwind-animationbased tailwindcss-typography-style tailwindcss-style-modify tailwindcss-animate-style; do
  find "$SCAN_ROOT" -path "*/node_modules/$pkg" -type d 2>/dev/null
done
```

### 7.2 Lock File References

Check `package-lock.json`, `yarn.lock`, and `pnpm-lock.yaml` for references to the malicious packages listed above.

### 7.3 Suspicious Lifecycle Scripts

Check for npm packages with suspicious `postinstall`/`preinstall` scripts:

```bash
find "$SCAN_ROOT" -path "*/node_modules/*/package.json" -maxdepth 5 | xargs grep -l "postinstall.*node -e\|postinstall.*curl\|postinstall.*eval\|preinstall.*node -e" 2>/dev/null
```

## Phase 8: System Persistence Check

**GLOBAL scope only — skip this phase in local scope.**

### 8.1 macOS

- **LaunchAgents**: `ls -la ~/Library/LaunchAgents/` — check for non-Apple, non-Google entries. Read suspicious plist files with `plutil -p`.
- **LaunchDaemons**: `ls -la /Library/LaunchDaemons/` — same check.
- **Crontab**: `crontab -l`
- **Login Items**: Check System Preferences → General → Login Items.

### 8.2 Linux

- **Crontab**: `crontab -l` and check `/etc/cron.d/`, `/etc/cron.daily/`
- **Systemd**: `systemctl list-units --type=service --state=running` — look for unfamiliar services
- **Profile scripts**: Check `~/.bashrc`, `~/.profile`, `~/.bash_profile` for injected lines

### 8.3 All Platforms

- **Shell profiles** (`~/.zshrc`, `~/.bashrc`, `~/.zprofile`, `~/.profile`, `~/.zshenv`): Check for injected `eval`, `curl | bash`, `node -e`, base64-encoded strings, or unfamiliar PATH additions.
- **Git global config** (`~/.gitconfig`): Check for `core.hooksPath` pointing to a non-standard location, suspicious aliases, or modified credential helpers.
- **npm/yarn config** (`~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`): Check for modified registry URLs or injected scripts.
- **SSH config** (`~/.ssh/config`): Check for ProxyCommand injections or unfamiliar hosts.

## Phase 9: GitHub Repository Scan

**GLOBAL scope only — skip in local scope unless user explicitly asks.** Requires `gh` CLI authenticated.

Use the GitHub API to search all repos owned by the authenticated user. Run each search:

```bash
USER=$(gh api /user --jq '.login')

# Critical payload signatures (0 results expected for clean accounts)
gh api "/search/code?q=_\$_1e42+user:$USER" --jq '.total_count'
gh api "/search/code?q=%22global%5B'!'%5D%22+user:$USER+-filename:polinrider-scanner" --jq '.total_count'
gh api "/search/code?q=%22global%5B'_V'%5D%22+user:$USER" --jq '.total_count'
gh api "/search/code?q=rmcej+user:$USER+-filename:polinrider-scanner" --jq '.total_count'
gh api "/search/code?q=%22Cot%253t%3DshtP%22+user:$USER" --jq '.total_count'

# C2 endpoints
gh api "/search/code?q=%22260120.vercel.app%22+user:$USER" --jq '.total_count'
gh api "/search/code?q=%22default-configuration.vercel.app%22+user:$USER" --jq '.total_count'

# Propagation artifacts
gh api "/search/code?q=filename:temp_auto_push.bat+user:$USER" --jq '.total_count'
gh api "/search/code?q=%22config.bat%22+user:$USER+filename:.gitignore" --jq '.total_count'

# Malware residue
gh api "/search/code?q=createRequire+user:$USER+filename:postcss.config" --jq '.total_count'
gh api "/search/code?q=createRequire+user:$USER+filename:next.config" --jq '.total_count'
gh api "/search/code?q=createRequire+user:$USER+filename:webpack.config" --jq '.total_count'

# VS Code droppers
gh api "/search/code?q=folderOpen+user:$USER+filename:tasks.json" --jq '.total_count'
gh api "/search/code?q=%22e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9%22+user:$USER" --jq '.total_count'

# Malicious packages
gh api "/search/code?q=%22tailwindcss-style-animate%22+user:$USER" --jq '.total_count'
gh api "/search/code?q=%22tailwind-mainanimation%22+user:$USER" --jq '.total_count'
```

**Any non-zero result (except scanner scripts) means active infection.** Report the file path and repo.

**NOTE:** GitHub code search only indexes the default branch. For repos with multiple branches, clone locally and scan with `git log --all --diff-filter=A -- "*.bat"` to check for `temp_auto_push.bat` in history.

## Phase 10: Creative / Novel Detection

These checks go beyond documented IOCs to catch variants or undocumented behaviors.

### 10.1 Obfuscation Pattern Detection

Search for generic obfuscation indicators in config files within `$SCAN_ROOT` (not just known signatures):

```bash
find "$SCAN_ROOT" \( -name "*.config.*" -o -name ".eslintrc*" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" | \
  xargs grep -l "eval(\|new Function(\|child_process\|spawn(\|exec(" 2>/dev/null
```

### 10.2 Binary Masquerading

Check ALL non-code files within `$SCAN_ROOT` for hidden JavaScript:

```bash
find "$SCAN_ROOT" -type f \( -name "*.woff2" -o -name "*.woff" -o -name "*.ttf" -o -name "*.eot" -o -name "*.png" -o -name "*.jpg" -o -name "*.ico" -o -name "*.dat" -o -name "*.bin" -o -name "*.dll" -o -name "*.so" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -size -1M | while read f; do
  filetype=$(file -b "$f")
  if echo "$filetype" | grep -qi "text\|ascii\|javascript\|utf-8"; then
    echo "FAKE BINARY: $f ($filetype)"
  fi
done
```

### 10.3 Recently Modified Config Files

Check for config files modified in the last 7 days that weren't part of a git commit:

```bash
find "$SCAN_ROOT" -name "*.config.*" -mtime -7 -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*"
```

### 10.4 Tampered node_modules

The malware can modify files inside `node_modules` directly. Check integrity of critical packages:

```bash
cd <repo> && npm ls --all 2>&1 | grep "WARN\|ERR\|invalid"
```

Or for a specific package, compare its file hash to the published version:

```bash
npm pack <package-name> --dry-run 2>/dev/null
```

### 10.5 Git Reflog Anomalies

Check for suspicious `amend` entries in the reflog (the malware amends commits to inject its payload):

```bash
find "$SCAN_ROOT" -maxdepth 2 -name ".git" -type d | while read g; do
  repo=$(dirname "$g")
  amends=$(cd "$repo" && git reflog 2>/dev/null | grep -c "amend")
  if [ "$amends" -gt 0 ]; then
    echo "$(basename $repo): $amends amend entries"
  fi
done
```

### 10.6 Unexpected Detached Processes

Beyond `node -e`, check for any process spawned from project directories that's now orphaned:

```bash
lsof +D "$SCAN_ROOT" 2>/dev/null | grep -v "Code\|claude\|git\|node_modules" | awk '{print $1, $2, $9}' | sort -u
```

### 10.7 Environment Variable Leaks

The malware sets `LAST_COMMIT_DATE`, `LAST_COMMIT_TIME`, etc. Check if these persist:

```bash
env | grep -i "LAST_COMMIT\|USER_NAME\|USER_EMAIL\|CURRENT_BRANCH"
```

### 10.8 Cryptocurrency Wallet Exposure

**GLOBAL scope only.** If you have any crypto wallets on this machine, check for unauthorized access:
- Check browser extension permissions for wallet extensions (MetaMask, Phantom, etc.)
- Review recent transactions on any wallets whose keys were accessible from this machine
- Rotate all private keys and seed phrases stored on or accessible from this machine
- Check `~/.config/`, `~/Library/Application Support/` for wallet data files that may have been read

## Remediation Checklist

If infections are found:

1. **Kill all malicious processes** (`kill -9`)
2. **Delete build caches** (`.next/`, `.cache/`, `.turbo/`, `.parcel-cache/`, `.vite/`)
3. **Clean config files** — remove the payload (everything after trailing spaces on the export line) AND remove `createRequire` imports
4. **Clean .gitignore** — remove `config.bat`, `temp_auto_push.bat`, `temp_interactive_push.bat` entries
5. **Delete propagation scripts** — `config.bat`, `temp_auto_push.bat`, `temp_interactive_push.bat`
6. **Delete VS Code droppers** — malicious `.vscode/tasks.json` and any fake font/binary payload files
7. **Delete malicious npm packages** — remove from `package.json`, delete from `node_modules`, regenerate lock file
8. **Clean git hooks** — check `.git/hooks/` and `.husky/` for infected hooks
9. **Commit and push fixes** to all affected repos
10. **Rotate credentials** — any API keys, tokens, wallet keys, or secrets on this machine should be considered compromised
11. **Notify collaborators** — anyone who has cloned your repos may be infected

## Output Format

Present results as:

```
## Scan Results (scope: LOCAL | GLOBAL)

### Official scanner (OSM polinrider-scanner.sh)
<exit code, summary of findings, or "skipped — offline">

### Active Threats
| Type | Location | Status |
|---|---|---|

### Infections Found
| Category | File/Location | Details | Remediated? |
|---|---|---|---|

### Clean Checks
- [x] No malicious processes
- [x] No C2 connections
- [x] No payload signatures in source files
- [x] No infected build caches
- [x] No VS Code droppers
- [x] No fake binary files
- [x] No propagation scripts
- [x] No .gitignore injection
- [x] No infected git hooks
- [x] No malicious npm packages
- [x] No system persistence (global scope only)
- [x] No shell profile injection (global scope only)
- [x] GitHub repos clean (global scope only)
```
