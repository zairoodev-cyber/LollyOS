# LollyOS Ubuntu Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build LollyOS 0.2.0 as an Ubuntu 24.04 LTS Noble based XFCE live/install ISO.

**Architecture:** Keep live-build, switch it to Ubuntu Noble mode, replace Debian-only packages and metadata, add LollyOS-owned Calamares settings, and update CI to build natively on Ubuntu 24.04.

**Tech Stack:** Ubuntu 24.04 LTS, live-build, XFCE, LightDM, Calamares, Brave, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-08-28-ubuntu-base-design.md`

## Global Constraints
- Base: Ubuntu 24.04 LTS (Noble)
- Architecture: amd64
- Desktop: XFCE + LightDM
- Default browser: Brave
- Installer: Calamares
- Build output: ISO-hybrid + SHA256

---

### Task 1: Switch live-build to Noble
- [x] Replace Debian mode/Trixie with Ubuntu mode/Noble.
- [x] Enable main, restricted, universe and multiverse.
- [x] Keep the Lolly live username and hostname.

### Task 2: Replace Debian-specific packages
- [x] Remove `live-task-xfce`, `calamares-settings-debian`, and `firefox-esr`.
- [x] Add Ubuntu Calamares common settings and VirtualBox guest packages.
- [x] Keep XFCE, network, audio, Bluetooth, developer and recovery tools.

### Task 3: Add LollyOS Calamares configuration
- [x] Add LollyOS branding.
- [x] Add installer sequence and essential Ubuntu/live-build module settings.
- [x] Keep the desktop installer launcher using `pkexec calamares`.

### Task 4: Update release identity and CI
- [x] Change OS metadata to Ubuntu-like LollyOS 0.2.0.
- [x] Build directly on Ubuntu 24.04 in GitHub Actions.
- [x] Validate shell/YAML syntax and package-list formatting.
