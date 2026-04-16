## ⚠️ Security notice — PolinRider supply-chain compromise (resolved)

I was one of ~1,047 GitHub owners hit by the **PolinRider** DPRK supply-chain attack documented at [OpenSourceMalware/PolinRider](https://github.com/OpenSourceMalware/PolinRider). An obfuscated JS payload was silently appended to config files in four of my repos by a malicious npm package or VS Code extension — I didn't commit it and had no idea it was there.

**Affected repos (now cleaned and pushed):**

- [finom/vovk-hello-world](https://github.com/finom/vovk-hello-world) — Vovk.ts demo *(`postcss.config.mjs`)*
- [finom/realtime-kanban](https://github.com/finom/realtime-kanban) — Vovk.ts demo *(`postcss.config.mjs`)*
- [finom/blok](https://github.com/finom/blok) — personal project *(`postcss.config.mjs`)*
- [finom/opensource.gubanov.eu](https://github.com/finom/opensource.gubanov.eu) — my portfolio site *(`webpack.config.js`)*

A near-miss was also caught in review on [finom/prisma-zod-generator](https://github.com/finom/prisma-zod-generator/commit/05e169512fdfb8f3492f0a259b445b2d0d629cba).

### If you cloned or `npm install`ed from any of these before the cleanup

Please run the OSM scanner ([`polinrider-scanner.sh`](https://github.com/OpenSourceMalware/PolinRider/blob/main/polinrider-scanner.sh)) and follow the [mitigation steps](https://github.com/OpenSourceMalware/PolinRider#recommended-actions) — audit your config files, delete any `temp_auto_push.bat`, and rotate build-environment secrets.

Everything on my side is fixed. Apologies to anyone exposed through my repos, and thanks for your patience — stupid situation, but handled.

— Andrey


---

### Hi there 👋

My name is Andrey Gubanov. I live in the open-source universe since 2011. Most of my projects can be found on [opensource.gubanov.eu](https://opensource.gubanov.eu/). Feel free to follow my Github profile and star my repos!

  <img src="https://github-readme-stats-ten-zeta-25.vercel.app/api?username=finom&rank_icon=percentile&show_icons=true&theme=catppuccin_mocha" alt="GitHub Stats">

