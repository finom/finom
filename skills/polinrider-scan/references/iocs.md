# PolinRider IOCs

Reference list of known indicators of compromise. Consult this file when interpreting ambiguous scanner output or when triaging a potential novel variant.

## Obfuscation signatures

### Original variant
| Signature | Meaning |
|---|---|
| `rmcej%otb%` | Obfuscation marker |
| `_$_1e42` | Decoder function name |
| `2857687` | Shuffle seed (layer 1) |
| `2667686` | Shuffle seed (layer 2) |
| `global['!']` | Global injection marker |
| `global['r'] = require` | Require hijack |
| `global['m'] = module` | Module hijack |

### Rotated variant (April 2026)
| Signature | Meaning |
|---|---|
| `Cot%3t=shtP` | Rotated obfuscation marker |
| `function MDy` / `var MDy=` | Rotated decoder function |
| `1111436` | Rotated shuffle seed (layer 1) |
| `3896884` | Rotated shuffle seed (layer 2) |
| `global['_V']` | Rotated global injection (tags `8-st1` through `8-st59`) |

## XOR keys
| Key | Role |
|---|---|
| ``2[gWfGj;<:-93Z^C`` | Primary XOR decryption key |
| ``m6:tTh^D)cBz?NM]`` | Secondary XOR decryption key |

## C2 endpoints (HTTP)
- `260120.vercel.app`
- `default-configuration.vercel.app`
- `vscode-settings-bootstrap.vercel.app`
- `vscode-settings-config.vercel.app`
- `vscode-bootstrapper.vercel.app`
- `vscode-load-config.vercel.app`

## C2 endpoints (blockchain dead-drop)
- `api.trongrid.io`
- `fullnode.mainnet.aptoslabs.com`
- `bsc-dataseed.binance.org`
- `bsc-rpc.publicnode.com`

## Blockchain addresses
| Chain | Address |
|---|---|
| TRON | `TMfKQEd7TJJa5xNZJZ2Lep838vrzrs7mAP` |
| TRON | `TXfxHUet9pJVU1BgVkBAbrES4YUc1nGzcG` |
| Aptos | `0xbe037400670fbf1c32364f762975908dc43eeb38759263e7dfcdabc76380811e` |
| Aptos | `0x3f0e5781d0855fb460661ac63257376db1941b2bb522499e4757ecb3ebd5dce3` |

## Malicious npm packages
- `tailwindcss-style-animate`
- `tailwind-mainanimation`
- `tailwind-autoanimation`
- `tailwind-animationbased`
- `tailwindcss-typography-style`
- `tailwindcss-style-modify`
- `tailwindcss-animate-style`

## Propagation artifacts
- `temp_auto_push.bat`
- `temp_interactive_push.bat`
- `config.bat`

## VS Code dropper markers
- `"runOn": "folderOpen"` in `.vscode/tasks.json` combined with hidden-output flags (`reveal: never`, `echo: false`, `hide: true`)
- Template UUID: `e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9` (StakingGame)
- Any of the Vercel C2 domains above referenced from a task
- Disguised font/binary files (`.woff2`, `.ttf`, `.bin`) whose first bytes are ASCII space (`0x20`) or `global` (`0x676c6f62`)

## Config file hiding technique

The payload is appended to `module.exports = ...` (or equivalent) after **hundreds of trailing spaces** on the same line. Editors render the line as normal; the payload is off-screen. The presence of `createRequire` in a simple ESM config file (postcss, tailwind, etc.) is residue left behind after a partial cleanup.
