# 🍭 LollyOS

LollyOS is an Ubuntu-based desktop Linux distribution focused on a lightweight XFCE experience and simple VirtualBox testing.

## 0.2.0 Ubuntu Preview
- Ubuntu 24.04 LTS (Noble) base
- XFCE desktop + LightDM
- NetworkManager with graphical Wi-Fi management
- PipeWire + WirePlumber audio
- Bluetooth tools
- Calamares graphical installer with LollyOS-owned settings
- Brave Browser installed during ISO build and selected as the web-browser alternative
- Lolly Update utility using GitHub Releases
- VirtualBox guest utilities

## Build on GitHub
Push to `main` or manually run **Build LollyOS Ubuntu ISO**. The resulting `LollyOS-0.2.0-ubuntu-noble-amd64.iso` and SHA256 file are uploaded under the `LollyOS-Ubuntu-ISO` artifact.

A tag such as `v0.2.0` also publishes those files to a GitHub Release.

## VirtualBox
Recommended VM: Linux / Ubuntu 64-bit, 4 GB RAM, 2 CPUs, 40 GB dynamically allocated disk. EFI can be enabled, but the first preview should be tested without Secure Boot.

## Updates
`Lolly Update` checks GitHub Releases for newer LollyOS versions. 0.2.0 still opens the release page for upgrades; automatic signed OTA installation remains a later layer.
