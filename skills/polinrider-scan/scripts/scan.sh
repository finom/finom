#!/usr/bin/env bash
# PolinRider malware scanner
#
# Step 1 runs the official OSM scanner from OpenSourceMalware/PolinRider.
# Step 2 runs extended IOC/variant checks that complement the upstream scanner.
#
# Usage: scan.sh <scope> [scan_root]
#   scope      "local" or "global"
#   scan_root  absolute path (default: cwd for local, $HOME for global)
#
# Output is organized as == SECTION == blocks so the calling agent can parse
# findings cleanly. Exit code is always 0; detection state lives in the output.

set -u

SCOPE="${1:-}"
if [[ "$SCOPE" != "local" && "$SCOPE" != "global" ]]; then
  echo "usage: scan.sh <local|global> [scan_root]" >&2
  exit 2
fi

SCAN_ROOT="${2:-}"
if [[ -z "$SCAN_ROOT" ]]; then
  if [[ "$SCOPE" == "local" ]]; then SCAN_ROOT="$PWD"; else SCAN_ROOT="$HOME"; fi
fi

EXCLUDES=( -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/build/*" )
CODE_NAMES=( -name "*.js" -o -name "*.mjs" -o -name "*.cjs" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.bat" -o -name "*.sh" )

echo "== META =="
echo "scope=$SCOPE"
echo "scan_root=$SCAN_ROOT"
echo "host=$(uname -s) $(uname -r)"
echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# ---------- Step 1: Official OSM scanner ----------
echo "== OSM_SCANNER =="
OSM_URL="https://raw.githubusercontent.com/OpenSourceMalware/PolinRider/main/polinrider-scanner.sh"
OSM_TMP="$(mktemp -t polinrider-scanner.XXXXXX.sh)"
if curl -fsSL --max-time 30 "$OSM_URL" -o "$OSM_TMP" 2>/dev/null; then
  echo "downloaded: $OSM_TMP"
  # Best-effort: pass scan root if the scanner accepts it, otherwise run with no args.
  bash "$OSM_TMP" "$SCAN_ROOT" 2>&1 || bash "$OSM_TMP" 2>&1
else
  echo "skipped: could not download $OSM_URL"
fi
rm -f "$OSM_TMP"
echo

# ---------- Step 2a: Active threats ----------
echo "== PROCESSES =="
ps aux 2>/dev/null | grep -E "node -e|global\['!'\]|global\['_V'\]|_\\\$_1e42|MDy|rmcej|2857687|1111436" | grep -v grep || echo "none"
echo
echo "-- reparented node (ppid=1) --"
ps -eo pid,ppid,comm,args 2>/dev/null | awk '$2 == 1 && /node/ {print}' || echo "none"
echo

echo "== NETWORK_C2 =="
C2_DOMAINS=(
  260120.vercel.app
  default-configuration.vercel.app
  vscode-settings-bootstrap.vercel.app
  vscode-settings-config.vercel.app
  vscode-bootstrapper.vercel.app
  vscode-load-config.vercel.app
  api.trongrid.io
  fullnode.mainnet.aptoslabs.com
  bsc-dataseed.binance.org
  bsc-rpc.publicnode.com
)
if command -v lsof >/dev/null 2>&1; then
  lsof -i -n -P 2>/dev/null | grep -i "node" | grep -v localhost || echo "no node network connections"
else
  echo "lsof unavailable"
fi
echo "-- known C2 domains (informational) --"
printf '%s\n' "${C2_DOMAINS[@]}"
echo

# ---------- Step 2b: Payload signatures in source ----------
echo "== SIGNATURES =="
SIGS=(
  "rmcej%otb%"
  "_\$_1e42"
  "2857687"
  "2667686"
  "global\['!'\]"
  "global\['r'\] = require"
  "global\['m'\] = module"
  "Cot%3t=shtP"
  "function MDy"
  "var MDy="
  "1111436"
  "3896884"
  "global\['_V'\]"
  "2\[gWfGj;<:-93Z\^C"
  "m6:tTh\^D)cBz?NM\]"
  "TMfKQEd7TJJa5xNZJZ2Lep838vrzrs7mAP"
  "TXfxHUet9pJVU1BgVkBAbrES4YUc1nGzcG"
  "0xbe037400670fbf1c32364f762975908dc43eeb38759263e7dfcdabc76380811e"
  "0x3f0e5781d0855fb460661ac63257376db1941b2bb522499e4757ecb3ebd5dce3"
)
PATTERN=$(IFS='|'; echo "${SIGS[*]}")
find "$SCAN_ROOT" -type f \( "${CODE_NAMES[@]}" \) "${EXCLUDES[@]}" \
  ! -name "polinrider-scanner*" ! -name "scan.sh" ! -name "SKILL.md" ! -name "iocs.md" -print0 2>/dev/null \
  | xargs -0 grep -lE "$PATTERN" 2>/dev/null || echo "none"
echo

# ---------- Step 2c: Config file infection ----------
echo "== CONFIG_FILES =="
CONFIG_GLOBS=(
  "postcss.config.*" "tailwind.config.*" "eslint.config.*" "next.config.*"
  "vite.config.*" "webpack.config.*" "astro.config.*" "gridsome.config.*"
  "vue.config.*" "rollup.config.*" "babel.config.*" "truffle.js" ".eslintrc*"
)
for glob in "${CONFIG_GLOBS[@]}"; do
  find "$SCAN_ROOT" -type f -name "$glob" "${EXCLUDES[@]}" -print 2>/dev/null
done | while read -r f; do
  [[ -z "$f" ]] && continue
  maxlen=$(awk '{ if(length > max) max=length } END { print max+0 }' "$f" 2>/dev/null)
  has_long_ws=$(grep -cE ' {50,}' "$f" 2>/dev/null || echo 0)
  has_sig=$(grep -cE "global\['!'\]|global\['_V'\]|_\\\$_1e42|function MDy|rmcej" "$f" 2>/dev/null || echo 0)
  has_cr=$(grep -cE "createRequire" "$f" 2>/dev/null || echo 0)
  if (( maxlen > 200 )) || (( has_long_ws > 0 )) || (( has_sig > 0 )) || (( has_cr > 0 )); then
    echo "SUSPECT: $f (max_line=$maxlen, long_ws=$has_long_ws, sig=$has_sig, createRequire=$has_cr)"
  fi
done
echo

# ---------- Step 2d: Build cache infection ----------
echo "== BUILD_CACHES =="
for cache in .next .cache .turbo .parcel-cache .vite; do
  find "$SCAN_ROOT" -type d -name "$cache" -not -path "*/node_modules/*" 2>/dev/null | while read -r d; do
    hit=$(grep -rlE "global\['!'\]|_\\\$_1e42|rmcej|global\['_V'\]|MDy" "$d/" 2>/dev/null | head -3)
    [[ -n "$hit" ]] && echo "INFECTED: $hit"
  done
done || true
echo

# ---------- Step 2e: VS Code droppers ----------
echo "== VSCODE_DROPPERS =="
find "$SCAN_ROOT" -name "tasks.json" -path "*/.vscode/*" -not -path "*/node_modules/*" -print 2>/dev/null | while read -r f; do
  if grep -qE "folderOpen|e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9|\.woff2|\.bat|node -e|curl.*\|.*bash|wget.*\|.*sh" "$f" 2>/dev/null; then
    echo "SUSPECT: $f"
  fi
done
echo

echo "== FAKE_BINARIES =="
find "$SCAN_ROOT" -type f \( -name "*.woff2" -o -name "*.woff" -o -name "*.ttf" -o -name "*.eot" -o -name "*.otf" -o -name "*.ico" -o -name "*.dat" -o -name "*.bin" \) "${EXCLUDES[@]}" -size -1M -print 2>/dev/null | while read -r f; do
  ft=$(file -b "$f" 2>/dev/null)
  if echo "$ft" | grep -qiE "text|ascii|javascript|utf-8|script"; then
    echo "FAKE: $f ($ft)"
  fi
done
echo

# ---------- Step 2f: Propagation artifacts ----------
echo "== PROPAGATION_ARTIFACTS =="
find "$SCAN_ROOT" \( -name "temp_auto_push.bat" -o -name "temp_interactive_push.bat" -o -name "config.bat" \) -not -path "*/node_modules/*" -print 2>/dev/null || echo "none"
echo "-- .gitignore injection --"
find "$SCAN_ROOT" -name ".gitignore" -not -path "*/node_modules/*" -print 2>/dev/null | xargs grep -lE "config\.bat|temp_auto_push|temp_interactive_push" 2>/dev/null || echo "none"
echo "-- infected git hooks --"
find "$SCAN_ROOT" -path "*/.git/hooks/*" -type f -not -name "*.sample" 2>/dev/null | while read -r f; do
  grep -qE "config\.bat|temp_auto|force.*push|amend.*no-verify" "$f" 2>/dev/null && echo "HOOK: $f"
done
find "$SCAN_ROOT" -path "*/.husky/*" -type f 2>/dev/null | while read -r f; do
  grep -qE "config\.bat|temp_auto|force.*push|amend.*no-verify" "$f" 2>/dev/null && echo "HUSKY: $f"
done
echo

# ---------- Step 2g: Malicious npm packages ----------
echo "== NPM_PACKAGES =="
BAD_PKGS=(
  tailwindcss-style-animate tailwind-mainanimation tailwind-autoanimation
  tailwind-animationbased tailwindcss-typography-style tailwindcss-style-modify
  tailwindcss-animate-style
)
for pkg in "${BAD_PKGS[@]}"; do
  find "$SCAN_ROOT" -path "*/node_modules/$pkg" -type d 2>/dev/null
done || true
echo "-- suspicious lifecycle scripts --"
find "$SCAN_ROOT" -path "*/node_modules/*/package.json" -maxdepth 7 2>/dev/null | xargs grep -lE "(postinstall|preinstall).*(node -e|curl|eval)" 2>/dev/null || echo "none"
echo

# ---------- Step 2h: Obfuscation / novel variants ----------
echo "== OBFUSCATION_HEURISTICS =="
find "$SCAN_ROOT" \( -name "*.config.*" -o -name ".eslintrc*" \) "${EXCLUDES[@]}" -print 2>/dev/null | xargs grep -lE "eval\(|new Function\(|child_process|spawn\(|exec\(" 2>/dev/null || echo "none"
echo "-- recently modified configs (last 7 days) --"
find "$SCAN_ROOT" -name "*.config.*" -mtime -7 "${EXCLUDES[@]}" -print 2>/dev/null || echo "none"
echo

# ---------- Step 2i: Global-only phases ----------
if [[ "$SCOPE" == "global" ]]; then
  echo "== PERSISTENCE =="
  case "$(uname -s)" in
    Darwin)
      echo "-- ~/Library/LaunchAgents --"
      ls -la "$HOME/Library/LaunchAgents/" 2>/dev/null | tail -n +2 || echo "none"
      echo "-- /Library/LaunchDaemons --"
      ls -la "/Library/LaunchDaemons/" 2>/dev/null | tail -n +2 || echo "none"
      ;;
    Linux)
      echo "-- /etc/cron.d --"
      ls -la /etc/cron.d 2>/dev/null || echo "none"
      echo "-- running systemd services --"
      systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -40 || echo "n/a"
      ;;
  esac
  echo "-- crontab --"
  crontab -l 2>/dev/null || echo "none"
  echo "-- shell profiles --"
  for rc in ~/.zshrc ~/.bashrc ~/.zprofile ~/.profile ~/.bash_profile ~/.zshenv; do
    [[ -f "$rc" ]] || continue
    grep -nE "eval |curl .*\| *bash|wget .*\| *sh|node -e|base64 -d" "$rc" 2>/dev/null \
      | sed "s|^|$rc:|" || true
  done
  echo "-- git/npm/ssh config --"
  grep -nE "core\.hooksPath|credentialHelper" "$HOME/.gitconfig" 2>/dev/null | sed "s|^|~/.gitconfig:|" || true
  grep -nE "registry|ProxyCommand" "$HOME/.npmrc" "$HOME/.yarnrc" "$HOME/.ssh/config" 2>/dev/null | head -40 || true
  echo "-- env leaks --"
  env | grep -iE "LAST_COMMIT|USER_NAME|USER_EMAIL|CURRENT_BRANCH" || echo "none"
  echo

  echo "== GITHUB_SCAN =="
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    USER=$(gh api /user --jq '.login' 2>/dev/null)
    echo "user=$USER"
    for q in \
      "_\$_1e42+user:$USER" \
      "%22global%5B'!'%5D%22+user:$USER+-filename:polinrider-scanner" \
      "%22global%5B'_V'%5D%22+user:$USER" \
      "rmcej+user:$USER+-filename:polinrider-scanner" \
      "%22Cot%253t%3DshtP%22+user:$USER" \
      "%22260120.vercel.app%22+user:$USER" \
      "filename:temp_auto_push.bat+user:$USER" \
      "createRequire+user:$USER+filename:postcss.config" \
      "folderOpen+user:$USER+filename:tasks.json" \
      "%22e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9%22+user:$USER" \
      "%22tailwindcss-style-animate%22+user:$USER"
    do
      count=$(gh api "/search/code?q=$q" --jq '.total_count' 2>/dev/null || echo "?")
      printf '%s\t%s\n' "$count" "$q"
    done
  else
    echo "skipped: gh not installed or not authenticated"
  fi
  echo
fi

echo "== DONE =="
echo "finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
