#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# keycard test suite
#
# Requires: bats-core, yq (Mike Farah's Go version)
#   brew install bats-core yq        # macOS
#   apt install bats && snap install yq   # Ubuntu
#
# Run:
#   bats test/keycard.bats
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_DIR="$(cd "$TEST_DIR/.." && pwd)"
  KEYCARD="$PROJECT_DIR/bin/keycard"
}

# Helper: source the script so we can call functions directly.
# Sets KEYCARD_CONFIG to the given fixture (default: keycard.yml).
load_keycard() {
  export KEYCARD_CONFIG="${1:-$TEST_DIR/fixtures/keycard.yml}"
  source "$KEYCARD"
}

# ===========================================================================
#  Config parsing  (requires yq)
# ===========================================================================

@test "get_root: returns correct root for known site" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  result="$(get_root "mysite")"
  [ "$result" = "/var/www/mysite" ]
}

@test "get_root: returns empty string for unknown site" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  result="$(get_root "nonexistent")"
  [ -z "$result" ]
}

@test "get_root: handles multiple sites" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  r1="$(get_root "mysite")"
  r2="$(get_root "other")"
  [ "$r1" = "/var/www/mysite" ]
  [ "$r2" = "/var/www/other" ]
}

@test "get_paths: returns paths for known site/mode" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  run get_paths "mysite" "theme"
  [ "$status" -eq 0 ]
  [ "$output" = "wp-content/themes/mytheme" ]
}

@test "get_paths: returns paths for a different mode" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  run get_paths "mysite" "all"
  [ "$status" -eq 0 ]
  [ "$output" = "wp-content" ]
}

@test "get_paths: returns empty for unknown mode" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  run get_paths "mysite" "nonexistent"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "get_paths: returns empty for unknown site" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard
  run get_paths "ghost" "theme"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "get_allowed_roots: defaults to /var/www when key is absent" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard "$TEST_DIR/fixtures/keycard.yml"
  run get_allowed_roots
  [ "$status" -eq 0 ]
  [ "$output" = "/var/www" ]
}

@test "get_allowed_roots: reads configured roots" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  load_keycard "$TEST_DIR/fixtures/keycard-custom-roots.yml"
  result="$(get_allowed_roots)"
  [[ "$result" == *"/var/www"* ]]
  [[ "$result" == *"/opt/apps"* ]]
  line_count="$(echo "$result" | wc -l | tr -d ' ')"
  [ "$line_count" = "2" ]
}

# ===========================================================================
#  Duration validation
# ===========================================================================

@test "validate_duration: accepts 15m" {
  load_keycard
  validate_duration "15m"
}

@test "validate_duration: accepts 1h" {
  load_keycard
  validate_duration "1h"
}

@test "validate_duration: accepts 2h30m" {
  load_keycard
  validate_duration "2h30m"
}

@test "validate_duration: accepts 1day" {
  load_keycard
  validate_duration "1day"
}

@test "validate_duration: accepts 90s" {
  load_keycard
  validate_duration "90s"
}

@test "validate_duration: accepts 500ms" {
  load_keycard
  validate_duration "500ms"
}

@test "validate_duration: accepts 500msec" {
  load_keycard
  validate_duration "500msec"
}

@test "validate_duration: accepts 30seconds" {
  load_keycard
  validate_duration "30seconds"
}

@test "validate_duration: accepts 2weeks" {
  load_keycard
  validate_duration "2weeks"
}

@test "validate_duration: accepts compound 1h30m15s" {
  load_keycard
  validate_duration "1h30m15s"
}

@test "validate_duration: rejects bare number" {
  load_keycard
  run validate_duration "15"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects invalid suffix" {
  load_keycard
  run validate_duration "15x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects alpha string" {
  load_keycard
  run validate_duration "abc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects empty string" {
  load_keycard
  run validate_duration ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects negative number" {
  load_keycard
  run validate_duration "-1h"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects decimal" {
  load_keycard
  run validate_duration "1.5h"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

@test "validate_duration: rejects spaces between groups" {
  load_keycard
  run validate_duration "1h 30m"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
  [[ "$output" == *"no spaces"* ]]
}

@test "validate_duration: trims leading/trailing whitespace" {
  load_keycard
  validate_duration "  30m  "
}

@test "validate_duration: trims whitespace but still rejects internal spaces" {
  load_keycard
  run validate_duration "  1h 30m  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid duration"* ]]
}

# ===========================================================================
#  Usage / argument parsing  (no root or system tools required)
# ===========================================================================

@test "no arguments shows usage" {
  run bash "$KEYCARD"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown action shows usage" {
  run bash "$KEYCARD" bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "in without all required flags shows usage" {
  run bash "$KEYCARD" in --site mysite
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "in with only --site and --mode shows usage" {
  run bash "$KEYCARD" in --site mysite --mode theme
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "usage text includes cleanup command" {
  run bash "$KEYCARD"
  [[ "$output" == *"cleanup"* ]]
}

@test "usage text includes doctor command" {
  run bash "$KEYCARD"
  [[ "$output" == *"doctor"* ]]
}

# ===========================================================================
#  Doctor command
# ===========================================================================

@test "do_doctor: reports on dependencies and config" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/mysite"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www

sites:
  mysite:
    root: $tmpdir/www/mysite
    modes:
      data:
        paths:
          - .
YAML

  load_keycard "$tmpdir/config.yml"

  # Mock commands that may not exist on macOS
  systemd-run() { :; }
  systemctl()   { :; }
  setfacl()     { :; }
  getfacl()     { :; }
  getent()      { return 1; }  # no www-data group on macOS

  run do_doctor
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keycard doctor"* ]]
  [[ "$output" == *"yq"* ]]
  [[ "$output" == *"readable"* ]]
  [[ "$output" == *"mysite"* ]]
}

@test "do_doctor: warns about missing config" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  export KEYCARD_CONFIG="/tmp/keycard-nonexistent-config-$$"
  source "$KEYCARD"

  # Mock commands
  systemd-run() { :; }
  systemctl()   { :; }
  setfacl()     { :; }
  getfacl()     { :; }

  run do_doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"not readable"* ]]
}

@test "usage text includes duration examples" {
  run bash "$KEYCARD"
  [[ "$output" == *"15m"* ]]
  [[ "$output" == *"1day"* ]]
}

# ===========================================================================
#  Security: path validation via build_validated_paths()
#
#  These tests call build_validated_paths() directly — no need to mock
#  preflight, id, setfacl, systemd-run, etc.  Each test creates real temp
#  directories and a minimal config, then exercises the guardrails.
# ===========================================================================

@test "build_validated_paths: allows path under an allowed root" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/safe/content"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"

  PATHS=()
  build_validated_paths "$tmpdir/www/safe" "content"
  rm -rf "$tmpdir"
  [ "${#PATHS[@]}" -eq 1 ]
  [[ "${PATHS[0]}" == *"/www/safe/content" ]]
}

@test "build_validated_paths: allows path that equals an allowed root exactly" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/site"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www/site
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"

  # rp="." resolves to the root itself — should match the exact root
  PATHS=()
  build_validated_paths "$tmpdir/www/site" "."
  rm -rf "$tmpdir"
  [ "${#PATHS[@]}" -eq 1 ]
}

@test "build_validated_paths: rejects path outside allowed roots" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/apps/other"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"
  die() { echo "ERROR: $*"; exit 1; }

  run build_validated_paths "$tmpdir/apps/other" "."
  rm -rf "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not under any allowed root"* ]]
}

@test "build_validated_paths: rejects path traversal via .." {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/safe"
  mkdir -p "$tmpdir/escape"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"
  die() { echo "ERROR: $*"; exit 1; }

  # ../../escape from $tmpdir/www/safe resolves to $tmpdir/escape
  # which is NOT under $tmpdir/www
  run build_validated_paths "$tmpdir/www/safe" "../../escape"
  rm -rf "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not under any allowed root"* ]]
}

@test "build_validated_paths: rejects traversal to non-existent target" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/safe"
  # $tmpdir/escape intentionally NOT created

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"
  die() { echo "ERROR: $*"; exit 1; }

  run build_validated_paths "$tmpdir/www/safe" "../../ghost"
  rm -rf "$tmpdir"
  [ "$status" -ne 0 ]
  # Caught by either "does not exist" or "not under any allowed root"
  [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"not under any allowed root"* ]]
}

@test "build_validated_paths: rejects symlink escaping allowed root" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"
  command -v realpath >/dev/null 2>&1 || skip "realpath not available"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/safe"
  mkdir -p "$tmpdir/secret"
  # 'content' is a symlink pointing outside the allowed root
  ln -s "$tmpdir/secret" "$tmpdir/www/safe/content"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"
  die() { echo "ERROR: $*"; exit 1; }

  run build_validated_paths "$tmpdir/www/safe" "content"
  rm -rf "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not under any allowed root"* ]]
}

@test "build_validated_paths: rejects root path '/'" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  load_keycard
  die() { echo "ERROR: $*"; exit 1; }

  run build_validated_paths "/var/www/site" "/"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to operate on '/'"* ]]
}

@test "build_validated_paths: validates multiple paths in one call" {
  command -v yq >/dev/null 2>&1 || skip "yq not installed"

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/www/safe/a"
  mkdir -p "$tmpdir/www/safe/b"

  cat > "$tmpdir/config.yml" <<YAML
allowed_roots:
  - $tmpdir/www
sites: {}
YAML

  load_keycard "$tmpdir/config.yml"

  PATHS=()
  build_validated_paths "$tmpdir/www/safe" "a" "b"
  rm -rf "$tmpdir"
  [ "${#PATHS[@]}" -eq 2 ]
}
