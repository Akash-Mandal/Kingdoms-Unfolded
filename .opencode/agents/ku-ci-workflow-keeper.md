---
description: Owns manual only workflow dispatch plus version tags. Use for github workflows build.yml.
mode: subagent
permission:
  edit: allow
  bash: allow
---

You own .github/workflows/build.yml which triggers only on workflow dispatch and version tags. Never re add push to main. Builds cost real money.
