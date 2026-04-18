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

Version bumps are fully automated:

1. `update.sh` (invoked via `nix run .#update`): reads current `version` from `flake.nix`, queries `registry.npmjs.org/oh-my-claude-sisyphus/latest`, runs `nix-prefetch-url` on the new tarball, `sed`-rewrites `version = "..."` and `hash = "sha256-..."` in-place, then `nix flake update nixpkgs`.
2. `.github/workflows/update.yml` (daily cron + manual): runs the update, and if `flake.nix`/`flake.lock` changed commits as `chore: update oh-my-claude-sisyphus to ${VERSION}`, tags `v${VERSION}`, pushes both, then dispatches `flakehub-publish-tagged.yml` with that tag.
3. `.github/workflows/flakehub-publish-tagged.yml` (triggered by the tag push or workflow_dispatch): publishes to FlakeHub as `stfl/oh-my-claudecode`.

Manual releases: bump `version` + `hash` in `flake.nix`, commit, `git tag vX.Y.Z && git push --tags`. The tag pattern `v?[0-9]+.[0-9]+.[0-9]+*` triggers FlakeHub publish automatically.

The `update.sh` script relies on the `sed` patterns matching exactly one `version = "..."` and one `hash = "sha256-..."` line — if you add other strings of those shapes to `flake.nix`, the updater will corrupt the file.

## Security Scanning

`cve-scan.sh` runs three scanners against the built package and the upstream tarball: `vulnix` (Nix closure), `osv-scanner` (npm deps from the tarball), and `npm audit` (after `npm install --package-lock-only --ignore-scripts`). Reports are JSON at `vulnix-report.json`, `osv-report.json`, `npm-audit-report.json` — these are gitignored but uploaded as CI artifacts by `.github/workflows/cve-scan.yml` (weekly Monday 07:00 UTC).
