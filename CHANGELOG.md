# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.2.1] - 2026-02-07
### Added
- `doctor` command — health check for dependencies, config, sites, allowed roots, and www-data membership warnings

## [0.2.0] - 2026-02-06
### Added
- `cleanup` command now safely targets only `.timer` units and pairs associated `.service`
- `build_validated_paths()` extracted as a testable function for path security guardrails
- Path canonicalization via `realpath` with three-tier fallback (GNU `-m`, plain `realpath`, pure-bash lexical)
- Symlink escape detection (paths resolved through symlinks are checked against allowed roots)
- Duration validation with whitespace trimming (leading/trailing only; internal spaces rejected)
- Timer rollback now resolves the running binary via `BASH_SOURCE` instead of hardcoding `/usr/local/bin/keycard`
- Security tests: allowed roots enforcement, `..` traversal, symlink escape, exact root match, `/` rejection
- Common Pitfalls section in README (www-data group membership, filesystem-only security)

### Changed
- `doctor` is platform-aware: missing systemd/ACL tools are warnings (not errors) on non-Linux
- `doctor` exits 1 when issues are found (scriptable / CI-friendly)
- `doctor` does not require `sudo` — README reflects this
- `list` passes timer glob directly to `systemctl` instead of post-filtering with `awk`
- Allowed roots comparison now matches exact root (`$P == $ar`) in addition to children (`$P == $ar/*`)
- www-data membership warning phrased to reduce false alarms
- Timer binary fallback handles relative `BASH_SOURCE` without `realpath` (prepends `$PWD`)
- `install.sh` checks for both `setfacl` and `getfacl`, nudges `keycard doctor` on completion
- Removed unused `STATE_DIR` (`/var/lib/keycard`)

## [0.1.0] - 2026-02-06
### Added
- `keycard` CLI: `in`, `out`, `status`, `list`, `cleanup`
- YAML config via Mike Farah `yq`
- `allowed_roots` safety guardrail with canonical path validation
- Duration validation matching systemd suffixes (no spaces between groups)
- Bats test suite covering config parsing, durations, usage, and security guardrails
