# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Nix flake that repackages the upstream npm package `oh-my-claude-sisyphus` (published by `Yeachan-Heo/oh-my-claudecode`) for NixOS/home-manager consumption. This repo contains **no application code** — it wraps an npm tarball, exposes it as `pkgs.oh-my-claudecode.omc`, and publishes tagged releases to FlakeHub as `stfl/oh-my-claudecode`.

## Common Commands

```bash
nix build .#omc                     # build the package → ./result
nix flake check --no-build          # validate flake evaluation
nix run .#update                    # bump to latest npm version + refresh flake.lock
./cve-scan.sh [report_dir]          # vulnix + osv-scanner + npm audit, writes *-report.json
result/bin/omc --version            # must match `version = "..."` in flake.nix
```

After `nix build`, the CI smoke-test (see `.github/workflows/ci.yml`) asserts four binaries exist: `omc`, `oh-my-claudecode`, `omc-cli`, `omc-hud`, that `omc --version` equals the `version` string in `flake.nix`, and that `omc-hud` emits output containing `[OMC`.

## Architecture

**`flake.nix`** — single `mkOmcPkg` derivation that:
1. Fetches `oh-my-claude-sisyphus-${version}.tgz` from `registry.npmjs.org` with a pinned SRI `hash`.
2. Copies the tarball contents into `$out/lib/oh-my-claudecode/` (no build step — `dontConfigure` and `dontBuild` are set).
3. Uses `makeWrapper` to create two node-invoked entrypoints:
   - `omc` → wraps `bridge/cli.cjs` (the self-contained CLI bundle). Symlinked as `oh-my-claudecode` and `omc-cli`.
   - `omc-hud` → wraps `dist/hud/index.js` (the statusline HUD).

The flake exposes `packages.x86_64-linux.{default,omc,update}`, an `apps.update` entry, and `overlays.default` which puts `oh-my-claudecode.omc` into `pkgs`. Consumers use the overlay and reference `pkgs.oh-my-claudecode.omc` plus `${pkgs.oh-my-claudecode.omc}/lib/oh-my-claudecode` as the Claude Code plugin path (see `README.org` for the full home-manager recipe).

**Only `x86_64-linux` is built.** Any cross-platform support would need restructuring the flake output.

## Update Flow

This flake is a rolling release — every push to `main` is published to FlakeHub as a new rolling version. No tags.

1. `update.sh` (invoked via `nix run .#update`): reads current `version` from `flake.nix`, queries `registry.npmjs.org/oh-my-claude-sisyphus/latest`, runs `nix-prefetch-url` on the new tarball, `sed`-rewrites `version = "..."` and `hash = "sha256-..."` in-place, then `nix flake update nixpkgs`. The `version` field in `flake.nix` tracks the upstream npm package version (for the `--version` smoke test); it is not a git/flake release tag.
2. `.github/workflows/update.yml` (daily cron + manual): runs the update, and if `flake.nix`/`flake.lock` changed commits as `chore: update oh-my-claude-sisyphus to ${VERSION}`, pushes to `main`, then dispatches `flakehub-publish.yml`. The manual dispatch is required because GitHub does not trigger workflows from pushes made with `GITHUB_TOKEN`.
3. `.github/workflows/flakehub-publish.yml` (triggered by push to `main`, manual, or `workflow_dispatch` from `update.yml`): publishes a rolling release to FlakeHub as `stfl/oh-my-claudecode` via `flakehub-push` with `rolling: true`.

Manual releases: bump `version` + `hash` in `flake.nix` and push to `main` — push from a human/PAT fires `flakehub-publish.yml` automatically.

The `update.sh` script relies on the `sed` patterns matching exactly one `version = "..."` and one `hash = "sha256-..."` line — if you add other strings of those shapes to `flake.nix`, the updater will corrupt the file.

## Security Scanning

`cve-scan.sh` runs three scanners against the built package and the upstream tarball: `vulnix` (Nix closure), `osv-scanner` (npm deps from the tarball), and `npm audit` (after `npm install --package-lock-only --ignore-scripts`). Reports are JSON at `vulnix-report.json`, `osv-report.json`, `npm-audit-report.json` — these are gitignored but uploaded as CI artifacts by `.github/workflows/cve-scan.yml` (weekly Monday 07:00 UTC).
