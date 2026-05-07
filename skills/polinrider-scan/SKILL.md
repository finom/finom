---
name: polinrider-scan
description: >-
  Scan a project or machine for the PolinRider DPRK/Lazarus supply-chain
  malware (March–April 2026 npm + VS Code campaign). Use whenever the user
  asks to scan, audit, or check for PolinRider, the postcss / tailwind /
  webpack / next config infection, the `temp_auto_push.bat` /
  `config.bat` propagation, the StakingGame `.vscode/tasks.json` dropper
  (UUID `e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9`), or any IOC listed in
  `references/iocs.md`. Trigger proactively when the user reports
  unexplained `node -e` processes, `createRequire` showing up in simple
  ESM build configs, unfamiliar `tailwindcss-*-animate*` packages in
  `package.json` or lockfiles, `.vscode/tasks.json` with `runOn:
  folderOpen`, font files that read as plain text, or `*.bat` files
  appearing in JavaScript repo roots. Also trigger when the user mentions
  the DPRK / Lazarus npm supply-chain attack or the
  `OpenSourceMalware/PolinRider` repository.
---

# PolinRider Malware Scan

PolinRider is a DPRK/Lazarus supply-chain malware (March–April 2026 campaign) targeting JavaScript/Node.js developers. The infection chain:

1. A malicious npm package in the `tailwindcss-*-animate*` family (or a compromised legitimate package) gets pulled into a project, often transitively.
2. During `postinstall` / `preinstall` or the first build, the package appends an obfuscated payload to a build config file — `postcss.config.mjs`, `tailwind.config.js`, `webpack.config.js`, `next.config.mjs`, `vite.config.js`, etc. The payload is hidden behind **hundreds of trailing spaces** on the same line as `module.exports = ...` so editors render it off-screen.
3. Alternative dropper: a malicious `.vscode/tasks.json` with `runOn: folderOpen` runs the payload silently the first time the project is opened in VS Code, Cursor, or any other VS Code-derived IDE.
4. Once active, the payload spawns a detached `node -e` process that decrypts XOR-encrypted strings, exfiltrates crypto wallets, SSH keys, browser-stored secrets, and env vars to `*.vercel.app` C2 endpoints and on-chain dead-drops (TRON, Aptos, BSC), and propagates by silently rewriting git history and force-pushing through a dropped `temp_auto_push.bat` / `config.bat` script.
5. Compiled bundles in build caches (`.next/`, `.turbo/`, `.cache/`, `.parcel-cache/`, `.vite/`) preserve the payload after source cleanup, so the next dev-server start re-infects.

**You are the scanner.** Run every check below directly via the Bash tool against the user's machine. This skill bundles only documentation — there is nothing to install, fetch, or execute beyond the standard `find`, `grep`, `ps`, `lsof`, `awk`, and `file` utilities already on the system. Read [`references/iocs.md`](references/iocs.md) once at the start of the scan and keep the IOC tables in mind for interpreting ambiguous matches.

## Step 1 — Decide the scope

Pick scope in this order:

1. If the user passed an argument:
   - `local` → scope=local, root=`$PWD`
   - `global` → scope=global, root=`$HOME`
   - An absolute or `~`-prefixed path → scope=local, root=that path
2. Otherwise, infer from where the skill is installed:
   - `.claude/skills/polinrider-scan/` inside the project → **local**, root=`$PWD`
   - `~/.claude/skills/polinrider-scan/` → **global**, root=`$HOME`

State the resolved scope and root in one sentence before running checks. **Local** scope skips Phases 11 and 12 (system persistence and GitHub repo search). **Global** scope runs everything.

Set the resolved root in your shell environment for the rest of the scan:

```bash
ROOT="<resolved path>"
```

## Step 2 — Load the IOC reference

Read [`references/iocs.md`](references/iocs.md) before starting Phase 1. The file lists every signature, decoder name, shuffle seed, XOR key, C2 domain, blockchain address, malicious package name, and dropper artifact. Several phases below grep for these strings; if you see a hit you don't immediately recognize, look it up there.

## Step 3 — Run the scan

Run phases in order. **Phases 1 and 2 (active threats) take priority** — if anything matches there, the infection is currently live and exfiltrating. Capture the findings, finish the scan, then remediate per Step 5.

For all `find` invocations, use these standard exclusions to avoid scanning irrelevant directories:

```
-not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*" \
-not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.cache/*" \
-not -path "*/.turbo/*" -not -path "*/.parcel-cache/*" -not -path "*/.vite/*"
```

And exclude this skill's own files (which legitimately contain IOC strings as detection patterns):

```
! -path "*/polinrider-scan/*" ! -name "iocs.md" ! -name "SKILL.md"
```

If running multiple independent phases, dispatch them as parallel Bash calls in a single message — they don't depend on each other and run faster in parallel.

### Phase 1 — Active processes (highest priority)

Look for the malware's runtime fingerprint in the process table:

```bash
ps -eo pid,ppid,user,command 2>/dev/null \
  | grep -iE "node -e|global\['!'\]|global\['_V'\]|_\\\$_1e42|MDy|rmcej|2857687|1111436|3896884|2667686|temp_auto_push|config\.bat" \
  | grep -v grep
```

Reparented `node` processes (parent PID 1) — the payload detaches from its parent so it survives the IDE/terminal closing:

```bash
ps -eo pid,ppid,command 2>/dev/null | awk '$2 == 1 && /node/'
```

Any hit is an **active infection**. Note PIDs and full command lines. Don't kill yet (you'd lose state useful for the rest of the scan) — kill in Step 5 alongside the other cleanup. Exception: if a process is actively writing to a repo config (`lsof -p <pid>` shows `postcss.config.*` or similar), kill it now to stop the bleed.

### Phase 2 — C2 network connections

Resolve any active connections held by node processes:

```bash
lsof -i -n -P 2>/dev/null | grep -i node
```

Cross-reference established connections against the C2 list in [`references/iocs.md`](references/iocs.md):

- Vercel HTTP C2: `260120.vercel.app`, `default-configuration.vercel.app`, `vscode-settings-bootstrap.vercel.app`, `vscode-settings-config.vercel.app`, `vscode-bootstrapper.vercel.app`, `vscode-load-config.vercel.app`
- Blockchain dead-drops: `api.trongrid.io`, `fullnode.mainnet.aptoslabs.com`, `bsc-dataseed.binance.org`, `bsc-rpc.publicnode.com`

Any current connection from a node process to one of those endpoints is **live exfiltration in progress**. If macOS and the user runs Little Snitch or LuLu, also check their logs for outbound connections to those domains over the last 30 days.

### Phase 3 — Source code signatures

Scan source files for known obfuscation markers, decoder names, shuffle seeds, XOR keys, and blockchain addresses. `grep -F` (fixed strings, no regex) is the safest match mode here:

```bash
find "$ROOT" -type f \
  \( -name "*.js" -o -name "*.mjs" -o -name "*.cjs" -o -name "*.ts" -o -name "*.tsx" \
     -o -name "*.jsx" -o -name "*.json" -o -name "*.bat" -o -name "*.sh" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*" \
  -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.cache/*" \
  ! -path "*/polinrider-scan/*" -print0 2>/dev/null \
  | xargs -0 grep -lF \
    -e 'rmcej%otb%' -e '_$_1e42' -e '2857687' -e '2667686' \
    -e "global['!']" -e "global['r'] = require" -e "global['m'] = module" \
    -e 'Cot%3t=shtP' -e 'function MDy' -e 'var MDy=' \
    -e '1111436' -e '3896884' -e "global['_V']" \
    -e '2[gWfGj;<:-93Z^C' -e 'm6:tTh^D)cBz?NM]' \
    -e 'TMfKQEd7TJJa5xNZJZ2Lep838vrzrs7mAP' \
    -e 'TXfxHUet9pJVU1BgVkBAbrES4YUc1nGzcG' \
    -e '0xbe037400670fbf1c32364f762975908dc43eeb38759263e7dfcdabc76380811e' \
    -e '0x3f0e5781d0855fb460661ac63257376db1941b2bb522499e4757ecb3ebd5dce3' \
    2>/dev/null
```

For each file returned, open with the Read tool. Confirm the match is real (not a quoted string in a documentation file or a deliberately-named test fixture).

### Phase 4 — Config file infection (the trailing-whitespace bomb)

This is the primary infection vector. Find candidate config files:

```bash
find "$ROOT" -type f \
  \( -name "postcss.config.*" -o -name "tailwind.config.*" -o -name "eslint.config.*" \
     -o -name "next.config.*" -o -name "vite.config.*" -o -name "webpack.config.*" \
     -o -name "astro.config.*" -o -name "gridsome.config.*" -o -name "vue.config.*" \
     -o -name "rollup.config.*" -o -name "babel.config.*" -o -name "svelte.config.*" \
     -o -name "nuxt.config.*" -o -name "remix.config.*" -o -name "qwik.config.*" \
     -o -name "solid.config.*" -o -name "stylelint.config.*" -o -name "prettier.config.*" \
     -o -name "commitlint.config.*" -o -name ".eslintrc*" -o -name "truffle.js" \
     -o -name "jest.config.*" -o -name "vitest.config.*" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*" \
  -not -path "*/dist/*" -not -path "*/build/*" -print 2>/dev/null
```

For each candidate, compute four signals:

```bash
# max line length — clean configs rarely exceed ~120 chars
awk '{ if(length > max) max=length } END { print max+0 }' "<file>"

# any line with 50+ consecutive spaces (the trailing-whitespace bomb)
grep -cE ' {50,}' "<file>" 2>/dev/null

# explicit known signatures
grep -cF -e "global['!']" -e "global['_V']" -e '_$_1e42' -e 'function MDy' -e 'rmcej' -e 'Cot%3t=shtP' "<file>" 2>/dev/null

# createRequire residue — should not appear in a simple ESM build config
grep -c 'createRequire' "<file>" 2>/dev/null
```

A file is **suspect** if any of:

- Max line length > 200
- Any line has 50+ consecutive spaces
- Contains an explicit signature
- Contains `createRequire` in a context where the original file has no reason to use it (postcss, tailwind, prettier configs are ESM and don't need `createRequire`)

For each suspect, open with Read and inspect manually. Look at:

- The very last line of the file (`tail -c 4096 "<file>"` if the file is large)
- Any line longer than 200 chars
- The structure around `module.exports = ...` or `export default ...`

A real infection has long whitespace, then a string of `\x..`-encoded or base64-ish gibberish, then a call to `Buffer.from(...).toString()` and `eval(...)` or `new Function(...)`. A clean minified bundle does not appear in a `*.config.*` file under normal circumstances — if you see one, treat it as suspicious anyway.

### Phase 5 — Build cache infection

The malware survives source cleanup if the compiled bundle in the build cache still embeds the payload. The cache then runs again on the next build / dev-server start, re-infecting the source:

```bash
for cache in .next .cache .turbo .parcel-cache .vite .svelte-kit .nuxt .output; do
  find "$ROOT" -type d -name "$cache" -not -path "*/node_modules/*" 2>/dev/null
done
```

For each cache directory found:

```bash
grep -rlF \
  -e "global['!']" -e '_$_1e42' -e 'rmcej' -e "global['_V']" \
  -e 'function MDy' -e '2857687' -e '1111436' \
  "<cache_dir>" 2>/dev/null | head -20
```

Any hit means the cache must be deleted. Caches do not legitimately contain these strings.

### Phase 6 — VS Code / Cursor droppers

`.vscode/tasks.json` with `runOn: folderOpen` is the secondary PolinRider dropper — opening the project in VS Code, Cursor, or any VS Code-derived IDE auto-runs whatever is in the task. Find candidates:

```bash
find "$ROOT" -path "*/.vscode/tasks.json" -not -path "*/node_modules/*" -print 2>/dev/null
```

For each, inspect the contents:

```bash
grep -nE 'folderOpen|"reveal":\s*"never"|"echo":\s*false|"hide":\s*true|e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9|node -e|powershell|\.bat|\.woff2|260120\.vercel\.app|vscode-bootstrapper|vscode-settings|vscode-load-config' "<file>"
```

`folderOpen` alone is benign — many legitimate projects use it for setup. **The dropper signature is the combination** of `folderOpen` + hidden output (`reveal: never` / `echo: false`) + a download-and-execute pattern, OR any reference to the StakingGame UUID `e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9`, OR any reference to a Vercel C2 domain. Any of those by itself is sufficient evidence of the dropper.

Also check `.vscode/settings.json` for unusual `terminal.integrated.profiles.*` overrides, custom `npm.packageManager` paths pointing outside `/usr/local`, or `.vscode/extensions.json` recommending unfamiliar publishers.

### Phase 7 — Fake binaries

The dropper's second stage is sometimes hidden as a font file (`.woff2`, `.ttf`, `.eot`, `.otf`) or generic binary (`.bin`, `.dat`, `.ico`) in the repo. The file extension is a lie; the content is ASCII script:

```bash
find "$ROOT" -type f \
  \( -name "*.woff2" -o -name "*.woff" -o -name "*.ttf" -o -name "*.eot" \
     -o -name "*.otf" -o -name "*.ico" -o -name "*.dat" -o -name "*.bin" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -size -1M -print 2>/dev/null
```

For each result, sniff the type and first bytes (use `od -c -N 16` if `xxd` is not installed):

```bash
file -b "<path>"
xxd -l 16 "<path>" 2>/dev/null || od -An -c -N 16 "<path>"
```

A real woff2 reports `Web Open Font Format (Version 2) data` and starts with `wOF2` (`77 4f 46 32`). A real ttf starts with `00 01 00 00` or `74 72 75 65`. PolinRider fakes:

- `file` reports `ASCII text`, `UTF-8 text`, `JavaScript source`, or anything text-like
- First bytes are leading spaces (`0x20`), the ASCII text `global` (`67 6c 6f 62 61 6c`), or printable JavaScript

Any text-typed font/binary is a payload. Read the file and confirm.

### Phase 8 — Propagation artifacts and infected hooks

The malware drops batch files used to silently rewrite git history and force-push:

```bash
find "$ROOT" \
  \( -name "temp_auto_push.bat" -o -name "temp_interactive_push.bat" -o -name "config.bat" \) \
  -not -path "*/node_modules/*" -print 2>/dev/null
```

It also adds those files to `.gitignore` so `git status` won't reveal them:

```bash
find "$ROOT" -name ".gitignore" -not -path "*/node_modules/*" -print0 2>/dev/null \
  | xargs -0 grep -lE 'config\.bat|temp_auto_push|temp_interactive_push' 2>/dev/null
```

And it injects into git or husky hooks so every `git commit` triggers the propagation:

```bash
find "$ROOT" -path "*/.git/hooks/*" -type f -not -name "*.sample" 2>/dev/null
find "$ROOT" -path "*/.husky/*" -type f 2>/dev/null
```

For each hook file, check its body:

```bash
grep -lE 'config\.bat|temp_auto_push|temp_interactive_push|git push.*--force|amend.*--no-verify|node -e' "<hook>"
```

Any hit is malicious — none of these patterns belong in a project's git hooks.

### Phase 9 — Malicious npm packages

Scan for installed copies of known-malicious packages:

```bash
for pkg in tailwindcss-style-animate tailwind-mainanimation tailwind-autoanimation \
           tailwind-animationbased tailwindcss-typography-style tailwindcss-style-modify \
           tailwindcss-animate-style; do
  find "$ROOT" -path "*/node_modules/$pkg" -type d 2>/dev/null
done
```

Direct dependencies in `package.json`:

```bash
find "$ROOT" -name "package.json" -not -path "*/node_modules/*" -print0 2>/dev/null \
  | xargs -0 grep -lE '"tailwindcss-style-animate"|"tailwind-mainanimation"|"tailwind-autoanimation"|"tailwind-animationbased"|"tailwindcss-typography-style"|"tailwindcss-style-modify"|"tailwindcss-animate-style"' 2>/dev/null
```

Lockfiles (catch installations even if the package was later removed from `package.json`). The `-a` flag makes `grep` treat binary lockfiles like `bun.lockb` as text:

```bash
find "$ROOT" \
  \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" -o -name "bun.lockb" \) \
  -not -path "*/node_modules/*" -print0 2>/dev/null \
  | xargs -0 grep -alE 'tailwindcss-style-animate|tailwind-mainanimation|tailwind-autoanimation|tailwind-animationbased|tailwindcss-typography-style|tailwindcss-style-modify|tailwindcss-animate-style' 2>/dev/null
```

Suspicious lifecycle scripts in any package — `postinstall` / `preinstall` / `install` running `node -e`, `eval`, encoded payloads, or shell pipelines:

```bash
find "$ROOT" -path "*/node_modules/*/package.json" 2>/dev/null \
  | xargs grep -lE '"(post|pre)?install"\s*:\s*"[^"]*(node -e|eval |base64 -d |\| *bash|\| *sh)"' 2>/dev/null
```

Any returned `package.json` deserves a manual read — open it and inspect the `scripts` field.

### Phase 10 — Obfuscation heuristics (novel variants)

If the rotated signatures evolve again, the malware will still need to load encrypted code from a config file. Look for any config that does suspicious dynamic execution:

```bash
find "$ROOT" \( -name "*.config.*" -o -name ".eslintrc*" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null \
  | xargs -0 grep -lE 'eval\(|new Function\(|child_process|spawn\(|exec\(|Buffer\.from\([^)]+,[^)]*'"'"'hex'"'"'\)|Buffer\.from\([^)]+,[^)]*'"'"'base64'"'"'\)' 2>/dev/null
```

A legitimate `*.config.*` rarely needs `child_process`, `eval`, or `Buffer.from(..., 'hex' | 'base64')`. Any hit deserves manual review.

Recently-modified configs (last 7 days) — useful baseline of "what's new":

```bash
find "$ROOT" -name "*.config.*" -mtime -7 \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -print 2>/dev/null
```

### Phase 11 — System persistence (global scope only)

**Skip in local scope.** Run only when the resolved scope is global.

The malware sets up persistence so it re-runs on login or boot.

**macOS:**

```bash
ls -la ~/Library/LaunchAgents/ 2>/dev/null
ls -la /Library/LaunchAgents/ 2>/dev/null
ls -la /Library/LaunchDaemons/ 2>/dev/null
```

For every plist file, read it and look for `ProgramArguments` containing `node`, `/tmp/*`, `~/Library/Application Support/<unfamiliar>`, base64-encoded payloads, or Vercel C2 domains.

**Linux:**

```bash
ls -la /etc/cron.d /etc/cron.daily /etc/cron.hourly 2>/dev/null
crontab -l 2>/dev/null
systemctl list-units --type=service --state=running --no-pager 2>/dev/null
ls -la ~/.config/systemd/user/ 2>/dev/null
ls -la ~/.config/autostart/ 2>/dev/null
```

**Both platforms — user crontab:**

```bash
crontab -l 2>/dev/null
```

Any cron entry running `node`, a shell pipeline that fetches and pipes to `bash`/`sh`, or referencing a C2 domain is malicious.

**Shell rc files** — the malware can hook `cd`, alias `git`, or eval base64 on shell startup:

```bash
for rc in ~/.zshrc ~/.bashrc ~/.zprofile ~/.profile ~/.bash_profile ~/.zshenv ~/.config/fish/config.fish; do
  [[ -f "$rc" ]] && grep -nE 'eval |\| *bash|\| *sh|node -e|base64 -d|alias git=|alias cd=|cd\s*\(\s*\)' "$rc" 2>/dev/null
done
```

**Git, npm, ssh config:**

```bash
grep -nE 'core\.hooksPath|credentialHelper' ~/.gitconfig 2>/dev/null
grep -nE 'registry|//.+:_authToken|prefix' ~/.npmrc 2>/dev/null
grep -nE 'ProxyCommand|IdentityFile' ~/.ssh/config 2>/dev/null
ls -la ~/.ssh/authorized_keys 2>/dev/null
```

A `core.hooksPath` pointing outside the per-repo `.git/hooks/` (e.g., `~/.config/git/hooks`) lets the attacker swap in a malicious shared hook. Confirm contents.

**Env leaks** — the malware exports these to label exfiltrated batches:

```bash
env | grep -iE 'LAST_COMMIT|USER_NAME|USER_EMAIL|CURRENT_BRANCH'
```

Empty output is healthy. A populated set indicates a malicious shell wrapper.

### Phase 12 — GitHub repo search (global scope only)

**Skip in local scope. Skip if `gh` is not authenticated.**

Confirm `gh` works:

```bash
gh auth status 2>&1 | head -5
```

If authenticated, search the user's GitHub for known IOCs across all their repos:

```bash
USER=$(gh api /user --jq '.login')
echo "user=$USER"

for q in \
  '_$_1e42' \
  "global['!']" \
  "global['_V']" \
  'rmcej' \
  'Cot%3t=shtP' \
  '260120.vercel.app' \
  'temp_auto_push.bat' \
  'tailwindcss-style-animate' \
  'e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9'; do
  encoded=$(printf '%s' "$q" | jq -sRr @uri)
  count=$(gh api "/search/code?q=${encoded}+user:${USER}+-filename:polinrider-scanner+-filename:iocs.md+-filename:SKILL.md" --jq '.total_count' 2>/dev/null)
  printf '%s\t%s\n' "${count:-?}" "$q"
done
```

Any non-zero count outside this skill's own files is a real finding. Drill in with the full `gh api "/search/code?q=..."` to surface the repo + path.

## Step 4 — Interpret findings

Categorize each finding:

- **Active threat** — anything from Phase 1 (process) or Phase 2 (live C2 connection). Address immediately, before any other remediation.
- **Confirmed infection** — Phase 3 (signature in source), Phase 4 (suspect config with both whitespace bomb AND a signature), Phase 5 (build cache hit), Phase 6 (tasks.json with the dropper combination or StakingGame UUID), Phase 7 (text disguised as binary), Phase 8 (propagation artifact or infected hook).
- **High suspicion** — Phase 4 with one suspicious signal but no signature (long line OR long whitespace OR `createRequire` alone), Phase 9 (malicious npm package without a corresponding source signature — likely caught early), Phase 10 (obfuscation heuristic hit). Open the file and decide.
- **Informational** — recently-modified configs that look clean, persistence mechanisms that look standard, GitHub matches that resolve to documentation about PolinRider.

False-positive checklist before reporting:

- The skill's own files (`iocs.md`, `SKILL.md`, anything under `polinrider-scan/`) deliberately reference the patterns. Always exclude.
- Documentation about PolinRider in repos like `OpenSourceMalware/PolinRider` is not infection — same exclusion logic.
- A minified bundle in `dist/` or `build/` can trigger max-line-length checks; those folders are excluded by default. If a long line shows up in a `.config.*` file, that is **not** a normal minified bundle — config files are not minified output.
- A very long line in `package-lock.json` is normal (lockfiles are excluded from Phase 3 grep on purpose).

## Step 5 — Remediate

Confirm with the user before destructive actions. Order:

1. **Kill active processes** — for each PID from Phase 1 with IOCs in args:
   ```
   kill -9 <pid>
   ```
2. **Stop running dev servers** (`next dev`, `vite`, `webpack-dev-server`, `nuxt dev`, `astro dev`, etc.) — they re-emit the cache on hot-reload and re-infect.
3. **Delete infected build caches** — `rm -rf` each directory flagged by Phase 5.
4. **Clean infected configs** — for each suspect from Phase 4:
   - Open with Read.
   - Identify the legitimate end of the file (the last meaningful line of `module.exports` / `export default`).
   - Truncate to that point.
   - Remove any `createRequire` import the malware injected — postcss, tailwind, prettier ESM configs do not need it.
5. **Delete propagation scripts** — `rm` each `config.bat`, `temp_auto_push.bat`, `temp_interactive_push.bat`, and remove their entries from `.gitignore`.
6. **Delete VS Code droppers** — remove malicious task entries from `.vscode/tasks.json`, or delete the file if it's entirely the dropper. Delete fake-binary payload files identified in Phase 7.
7. **Clean git/husky hooks** — for each infected hook, restore from `*.sample` (git) or remove the malicious lines (husky).
8. **Remove malicious npm packages** — drop from `package.json`, delete the entire `node_modules/` directory, regenerate the lock file (`npm install` / `pnpm install` / `yarn install` / `bun install`).
9. **Commit and push fixes** — one focused commit per affected repo, message describing the cleanup. Use a normal `git push`. **Never `--force`** — force-push is exactly the propagation primitive the malware abuses, and a habit of force-pushing trains the user to ignore it in their reflog.
10. **Tell the user to rotate credentials** — anything accessible from this machine should be considered compromised. List candidates explicitly: GitHub Personal Access Tokens, npm tokens, AWS / GCP / Azure credentials, Cloudflare tokens, Vercel tokens, SSH private keys, browser-saved logins, crypto wallet seed phrases, password manager master password if it was unlocked while the malware was active.
11. **Tell the user to notify collaborators** — anyone who cloned an affected repo before cleanup is also exposed and needs the same scan run.

## Step 6 — Report

Output this structure. Fill every section, even when empty.

```
## PolinRider Scan Results

**Scope:** LOCAL or GLOBAL
**Root:** <path>
**Date:** <UTC timestamp>

### Active threats
| Type | Location | Action taken |
|---|---|---|

### Infections found
| Phase | Category | File / Location | Details | Remediated? |
|---|---|---|---|---|

### Clean checks
- [ ] Phase 1 — Active processes
- [ ] Phase 2 — C2 network connections
- [ ] Phase 3 — Source signatures
- [ ] Phase 4 — Config file infection
- [ ] Phase 5 — Build cache infection
- [ ] Phase 6 — VS Code / Cursor droppers
- [ ] Phase 7 — Fake binaries
- [ ] Phase 8 — Propagation artifacts (.bat / .gitignore / hooks)
- [ ] Phase 9 — Malicious npm packages
- [ ] Phase 10 — Obfuscation heuristics
- [ ] Phase 11 — System persistence (global only)
- [ ] Phase 12 — GitHub repo search (global only)

### Recommended actions
- Credentials to rotate: …
- Collaborators to notify: …
- Repos still needing a clean push: …
```

If everything is clean, say so explicitly and quote concrete numbers — e.g., "No PolinRider IOCs found in `~/Work`. Scanned N source files, M config files, K build caches, J node_modules trees."
