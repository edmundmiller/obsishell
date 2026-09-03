# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-02

### Added

- Add guided vault setup to the bar panel, including remote vault selection and
  a local folder picker.
- Add an Obsidian icon that follows the active Omarchy theme and reflects sync
  status.

### Changed

- Limit terminal prompts during setup to confirmation, encryption credentials,
  and continuous-sync activation.

### Fixed

- Clear an expected service failure after continuous sync is stopped.

## [0.1.0] - 2026-09-02

### Added

- Add an Omarchy bar widget for monitoring and controlling Obsidian Headless
  Sync.
- Add opt-in installation of the official `obsidian-headless` client and its
  Node.js dependencies.
- Add continuous sync through a plugin-managed systemd user service.
- Add controls for starting, stopping, refreshing, and running one-time syncs,
  opening the selected vault, and following service logs.
- Add configurable vault selection and status refresh intervals.

[unreleased]: https://github.com/edmundmiller/obsishell/compare/bf6c64bd7ed4d6653c11651a6efa4ffbc225b5af...HEAD
[0.2.0]: https://github.com/edmundmiller/obsishell/compare/8ebd0ac15cd1166bc1fe4b507e976d0f67a7d00e...bf6c64bd7ed4d6653c11651a6efa4ffbc225b5af
[0.1.0]: https://github.com/edmundmiller/obsishell/commit/8ebd0ac15cd1166bc1fe4b507e976d0f67a7d00e
