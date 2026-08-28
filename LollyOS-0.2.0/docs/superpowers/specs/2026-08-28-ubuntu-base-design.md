# LollyOS Ubuntu Base Design

## Goal
Move LollyOS from Debian 13 to Ubuntu 24.04 LTS (Noble) while preserving XFCE, LightDM, Brave, Lolly Update, VirtualBox usability, Calamares installation, GitHub Actions ISO artifacts, and LollyOS branding.

## Architecture
LollyOS continues to use Debian live-build tooling, but configures live-build in Ubuntu mode with Noble repositories and Ubuntu archive components. The live image remains an amd64 ISO-hybrid image. LollyOS-owned configuration lives in `config/includes.chroot`, while third-party software such as Brave is installed by a chroot hook.

## Installer
Calamares is installed from Ubuntu Noble together with `calamares-settings-ubuntu-common`. LollyOS supplies its own top-level settings, branding, and essential module configuration rather than inheriting Debian-specific settings.

## Release
The first Ubuntu-based preview is LollyOS 0.2.0. GitHub Actions builds on an Ubuntu 24.04 runner, uploads the ISO and SHA256 checksum as an artifact, and publishes them for `v*` tags.
