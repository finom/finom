# PolinRider IOCs

Reference list of known indicators of compromise for the PolinRider DPRK/Lazarus supply-chain campaign (March–April 2026). Consult this file when interpreting ambiguous scanner output, when triaging a potential novel variant, or when documenting a finding for the user.

## Affected IDEs

The VS Code dropper (`runOn: folderOpen` in `.vscode/tasks.json`) executes in any IDE that consumes the `.vscode/tasks.json` schema:

- VS Code (Microsoft)
- Cursor
- Windsurf
- VSCodium
- code-server (browser-based VS Code)

Treat all of them as equally vulnerable to the dropper. The malware does not check IDE flavor before executing.

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
| `global['_V']` | Rotated global injection marker |

The rotated variant tags individual injections with sequential identifiers `8-st1`, `8-st2`, … `8-st59` (and counting). A grep for `'_V'\]='8-st` will find them.

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
| Package | Last known version |
|---|---|
| `tailwindcss-style-animate` | 1.1.6 (primary ShoeVista dep) |
| `tailwind-mainanimation` | 2.3.3 |
| `tailwind-autoanimation` | 2.3.6 |
| `tailwind-animationbased` | — |
| `tailwindcss-typography-style` | 0.8.2 |
| `tailwindcss-style-modify` | 0.8.3 |
| `tailwindcss-animate-style` | 1.2.5 |

The malware family follows a naming convention: `tailwind*` + `*animat*` or `*style*`. Treat any unfamiliar package matching that shape as a candidate for manual review.

## Propagation artifacts
- `temp_auto_push.bat` — silent rewrite + force-push driver
- `temp_interactive_push.bat` — interactive variant of the above
- `config.bat` — orchestrator that chains the propagation steps; usually added to `.gitignore` to hide from `git status`

## VS Code / Cursor dropper markers
- `"runOn": "folderOpen"` in `.vscode/tasks.json` combined with hidden-output flags (`"reveal": "never"`, `"echo": false`, `"hide": true`)
- Template UUID: `e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9` (StakingGame template)
- Any of the Vercel C2 domains referenced from a task `command` or `args`
- Disguised font/binary files (`.woff2`, `.ttf`, `.eot`, `.otf`, `.bin`, `.dat`) whose first bytes are ASCII space (`0x20`), the literal text `global` (`0x676c6f62`), or otherwise printable JavaScript instead of the expected magic bytes (`wOF2`, `00 01 00 00`, etc.)

## Targeted config files

The payload is appended to `module.exports = ...` (CommonJS) or `export default ...` (ESM) after **hundreds of trailing spaces** on the same line. Editors render the line as normal; the payload is off-screen to the right. Known targets:

- `postcss.config.{js,mjs,cjs,ts}`
- `tailwind.config.{js,mjs,cjs,ts}`
- `eslint.config.{js,mjs,cjs,ts}` and legacy `.eslintrc*`
- `next.config.{js,mjs,ts}`
- `vite.config.{js,mjs,ts}`
- `webpack.config.{js,mjs,ts}`
- `astro.config.{js,mjs,ts}`
- `gridsome.config.js`
- `vue.config.js`
- `rollup.config.{js,mjs,ts}`
- `babel.config.{js,mjs}`
- `svelte.config.{js,mjs}`
- `nuxt.config.{js,ts,mjs}`
- `remix.config.js`
- `qwik.config.{js,ts}`
- `solid.config.{js,ts}`
- `prettier.config.{js,mjs}`
- `stylelint.config.{js,mjs}`
- `commitlint.config.{js,mjs}`
- `jest.config.{js,mjs,ts}`
- `vitest.config.{js,mjs,ts}`
- `truffle.js` (legacy)

The presence of `createRequire` in a simple ESM config that has no native reason for it (postcss, tailwind, prettier, stylelint) is residue left behind after partial cleanup — investigate.

## Exfiltration targets

When live, the malware reads and ships:

- Crypto wallet keystore files (Metamask, Phantom, Solflare, Atomic, Exodus, Trust Wallet)
- Browser-saved logins (Chrome, Brave, Edge, Firefox profile data)
- SSH private keys (`~/.ssh/id_*`)
- npm tokens (`~/.npmrc`)
- Cloud credential files (`~/.aws/credentials`, `~/.config/gcloud/`, `~/.docker/config.json`)
- Environment variables matching `*TOKEN*`, `*KEY*`, `*SECRET*`, `*PASSWORD*`
- Recent shell history (`~/.zsh_history`, `~/.bash_history`)
- Clipboard contents — including a clipboard hijacker that replaces copied wallet addresses with the attacker's

Any user whose machine ran the payload should rotate every credential and seed phrase listed above.

## Triage tips

**Confirmed infection** — at least one of:
- An explicit signature from the tables above appears in a config or source file
- A build cache contains any obfuscation marker
- A propagation artifact (`temp_auto_push.bat`, `config.bat`) exists
- A `.vscode/tasks.json` references the StakingGame UUID or a Vercel C2 domain
- A font/binary file is text-typed
- A node process is running with one of the IOCs in its command line

**High suspicion** — needs manual confirmation:
- Config file with 50+ consecutive spaces but no signature yet visible (read the line — the signature may be off-screen-right)
- Config file with `createRequire` in a tool that doesn't need it
- `package.json` with a package matching the `tailwind*animation*` / `tailwind*style*` shape that isn't in the known-good list
- Recently-modified config files combined with unexplained `node -e` processes

**Likely false positive** — exclude from reporting:
- Hits inside `polinrider-scan/`, `iocs.md`, `SKILL.md`, or any documentation about PolinRider
- Hits inside `OpenSourceMalware/PolinRider` clone or fork
- Long lines in `package-lock.json` (lockfiles legitimately have long lines)
- Long lines in `dist/` / `build/` minified bundles (excluded by default)
