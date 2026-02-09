# keycard 🔐

**Timed filesystem access for Linux servers.**

`keycard` is a small CLI tool that lets you temporarily "swipe in" write
permissions for specific directories and automatically revoke them after
a chosen duration --- similar to a digital keycard for your server.

It is designed for people who:

* Run WordPress or small apps on VPSes (DigitalOcean, Linode, Hetzner,
  etc.)
* Keep their filesystem locked down by default
* Want safe, temporary maintenance windows
* Prefer CLI-driven ops tooling over permanently relaxed permissions

---

## How It Works

`keycard` combines two Linux features:

* **ACLs (`setfacl`)** -- temporarily grant write access to a user or
  group
* **systemd timers** -- automatically revoke access after a timeout

Typical flow:

1. Swipe in for 30 minutes
2. Upload files / update plugins / run maintenance
3. Timer expires → permissions are removed
4. Filesystem is locked again

You can also swipe out manually at any time.

---

## Requirements

* Linux with `systemd`
* ACL support (`setfacl`, `getfacl`)
* [`yq`](https://github.com/mikefarah/yq) (Mike Farah's Go version) for config parsing

Ubuntu / Debian:

```
sudo apt-get update
sudo apt-get install -y acl
```

Install `yq` (pick one):

```
# Auto-detect arch (amd64 / arm64)
YQ_ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
sudo wget -qO /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}"
sudo chmod +x /usr/local/bin/yq

# or: sudo snap install yq
# or: brew install yq
```

> **Note:** `keycard` requires Mike Farah's Go-based `yq`, not the
> Python `yq` wrapper. The installer and preflight check will warn you
> if the wrong one is detected.

---

## Installation

Clone the repo:

```
git clone https://github.com/rickknowlton/keycard.git
cd keycard
```

Install:

```
./install.sh
```

This installs:

* Binary → `/usr/local/bin/keycard`
* Config → `/etc/keycard.yml` (if not already present)

The installer will warn you if `yq` or `setfacl/getfacl` are missing.

### After installing

The installer drops an **example config** at:

```
/etc/keycard.yml
```

Before using keycard:

1. Edit the file and replace the example site roots with real paths.
2. Run:

   keycard doctor

`doctor` will verify your dependencies and confirm your config is valid.

On a fresh install, `doctor` will usually warn that example site
directories do not exist yet — this is expected until you edit the
config.

---

## Configuration

Configuration lives in:

```
/etc/keycard.yml
```

> ⚠️ **The example config installed by `install.sh` uses placeholder
> paths. You must update them to match your server before using
> keycard.**

Example:

```yaml
# Allowed root paths — keycard refuses to touch anything outside these.
# Defaults to ["/var/www"] if omitted.
#
# allowed_roots:
#   - /var/www
#   - /opt/apps

sites:
  myblog:
    # ⚠️ Replace this with the real path to your site
    root: /var/www/CHANGE-ME
    modes:
      theme:
        paths:
          - wp-content/themes/starter-theme
      wp-content:
        paths:
          - wp-content

  shop:
    # ⚠️ Replace this with the real path to your site
    root: /var/www/CHANGE-ME
    modes:
      wp-content:
        paths:
          - wp-content
      core:
        paths:
          - .
```

### Concepts

Term                Meaning

---

**site**            Named project with a root directory
**mode**            A predefined set of paths under the site
**who**             User or group to grant access to
**paths**           Relative paths under the site root
**allowed_roots**   Directories keycard is allowed to touch

### Allowed Roots

By default, `keycard` only operates on paths under `/var/www/`. If your
sites live elsewhere (e.g. `/opt/apps/`), add an `allowed_roots` key to
the top of your config:

```yaml
allowed_roots:
  - /var/www
  - /opt/apps
```

This is a safety guardrail --- `keycard` will refuse to touch any path
that doesn't fall under one of these roots.

All paths are resolved to their canonical form (via `realpath`) before
the check runs.  This means:

* **Path traversal** (`../../etc`) is normalized and caught
* **Symlinks** that point outside the allowed tree are followed and
  rejected
* **Double slashes**, `.`, and other oddities are cleaned up

---

## Usage

### Swipe in for 30 minutes

```
sudo keycard in --site myblog --mode theme --who user:deploy --for 30m
```

### Check status

```
sudo keycard status --site myblog --mode theme --who user:deploy
```

### Swipe out early

```
sudo keycard out --site myblog --mode theme --who user:deploy
```

### List all active timers

```
sudo keycard list
```

### Clean up stale units

```
sudo keycard cleanup
```

Over time, completed systemd timer units can accumulate. The `cleanup`
command removes any inactive keycard-related units.  It is **safe to run
at any time** --- it only touches units that have already finished or
failed, never active timers.  Running it twice in a row is harmless
(idempotent).

```
sudo keycard cleanup
# Cleaning up inactive keycard units...
#   Removed: keycard-myblog-theme-user-deploy.timer (+ keycard-myblog-theme-user-deploy.service)
# Cleaned up 1 timer(s) and associated service(s).
```

Feel free to add it to a cron job or run it after every deploy.

### Run a health check

```
keycard doctor
```

The `doctor` command checks your setup and reports issues.  It does
**not** require `sudo` --- run it as any user to verify your setup:

* Correct `yq` flavor (Mike Farah's Go version)
* Required tools present (`setfacl`, `getfacl`, `systemd-run`, etc.)
* `realpath` availability and `-m` flag support
* Config file readable and well-formed
* All configured sites exist on disk, with their modes listed
* Allowed roots exist
* Warns if any users belong to `www-data` (see
  [Common Pitfalls](#common-pitfalls))

Example output:

```
keycard doctor
==============

Dependencies:
  ✅ yq (Mike Farah's Go version)
  ✅ setfacl
  ✅ getfacl
  ✅ systemd-run
  ✅ systemctl
  ✅ realpath (GNU, with -m support)

Config: /etc/keycard.yml
  ✅ readable

Sites:
  ✅ myblog → /var/www/example.com
     mode: theme
     mode: wp-content
  ✅ shop → /var/www/shop.example.com
     mode: wp-content
     mode: core

Allowed roots:
  ✅ /var/www

Group membership warnings:
  ✅ No users in www-data group (or group does not exist)

All checks passed. You're good to go. 🎉
```

Run `doctor` after installing, after editing your config, or whenever
something feels off.

---

## Duration Formats

`keycard` uses **flexible** duration validation --- it accepts any valid
[systemd time span](https://www.freedesktop.org/software/systemd/man/systemd.time.html),
including compound values:

* `15m`, `30m`
* `1h`, `2h30m`
* `12h`
* `1day`, `2days`
* `1week`
* `90s`, `500ms`, `500msec`
* `1h30m15s` (compound)

The full set of suffixes matches `systemd.time(7)`: `us`/`usec`, `ms`/`msec`,
`s`/`sec`/`seconds`, `m`/`min`/`minutes`, `h`/`hour`/`hours`,
`d`/`day`/`days`, `w`/`week`/`weeks`, `M`/`month`/`months`,
`y`/`year`/`years`.

> **Note:** Spaces between groups are **not** supported.  Use `2h30m`,
> not `2h 30m`.  (systemd itself accepts spaces, but they're awkward in
> CLI arguments and easy to misquote.)

Invalid durations (bare numbers, bad suffixes, decimals, spaces) are
caught **before** anything touches the filesystem or systemd.

---

## Security Model

`keycard` **does not secure WordPress or your app itself** --- it only
manages filesystem permissions.

Best practices:

* Keep SFTP users out of privileged groups like `www-data`
* Default state should be read-only
* Unlock only the smallest path necessary
* Avoid unlocking entire roots unless doing upgrades
* Prefer timed unlocks over permanent permission changes

---

## Common Pitfalls

### SFTP user is a member of `www-data`

If your SFTP user belongs to the `www-data` group (or whatever group
owns your web root), they likely have **permanent write access** through
standard Unix group permissions --- regardless of whether keycard has
granted any ACLs.

`keycard` manages *additional* access via ACLs.  It cannot revoke
permissions that come from group membership.

**Fix:** remove the SFTP user from `www-data` and grant access
exclusively through `keycard`:

```
sudo gpasswd -d deploy www-data
sudo keycard in --site myblog --mode theme --who user:deploy --for 30m
```

This way, when the timer expires, the user truly has no write access.

### Thinking keycard locks the app, not just the filesystem

`keycard` only controls filesystem permissions.  It does not lock
WordPress admin, disable SSH, or manage application-level access.
Combine it with other hardening measures (firewall rules, fail2ban,
WP security plugins) for a complete security posture.

---

## Recovery / Emergency Lock

If something goes wrong:

List active timers:

```
sudo systemctl list-timers | grep keycard
```

Force a lock:

```
sudo keycard out --site SITE --mode MODE --who user:NAME
```

Remove all ACLs on a path:

```
sudo setfacl -Rb /var/www/example
```

Clean up all stale units:

```
sudo keycard cleanup
```

---

## Testing

The test suite uses [bats-core](https://github.com/bats-core/bats-core).

Install dependencies:

```
# macOS
brew install bats-core yq

# Ubuntu / Debian
sudo apt-get install -y bats
sudo snap install yq
```

Run the tests:

```
bats test/keycard.bats
```

Tests cover:

* Config parsing via `yq` (site roots, mode paths, allowed roots, defaults)
* Duration validation (valid formats, invalid formats, edge cases)
* Usage / argument parsing (missing args, unknown actions)
* Security guardrails (allowed roots enforcement, `..` path traversal,
  symlink escape, non-existent traversal targets)

> The symlink escape test requires `realpath` and is skipped on systems
> without it.  All other security tests use the pure-bash lexical
> normalizer as a fallback.

---

## Uninstall

```
./uninstall.sh
```

This removes:

* `/usr/local/bin/keycard`

Config file remains at:

```
/etc/keycard.yml
```

---

## Why This Exists

Most VPS hardening guides say:

> "Disable writes everywhere."

That's good security... until you need to actually maintain the site.

`keycard` gives you:

* locked-by-default servers
* predictable maintenance windows
* zero guesswork about what's writable
* auditability via logs
* peace of mind

---

## License

MIT License.
