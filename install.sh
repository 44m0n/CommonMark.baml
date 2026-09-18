#!/bin/sh
set -eu

repo=${BAMARK_REPO:-44m0n/CommonMark.baml}
version=${BAMARK_VERSION:-}
install_dir=${BAMARK_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}

fail() {
    printf 'bamark installer: %s\n' "$1" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v tar >/dev/null 2>&1 || fail 'tar is required'

case "$repo" in
    ''|*[!A-Za-z0-9._/-]*|*/*/*|/*|*/) fail 'BAMARK_REPO must be in owner/repository form' ;;
esac

case "$(uname -s)" in
    Linux) platform=linux ;;
    Darwin) platform=macos ;;
    *) fail 'this installer supports Linux and macOS' ;;
esac

case "$(uname -m)" in
    x86_64|amd64) arch=x86_64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
esac

if [ -z "$version" ]; then
    version=$(curl -fsSL \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$repo/releases/latest" \
        | awk -F '"' '/"tag_name"[[:space:]]*:/ { print $4; exit }')
fi

case "$version" in
    [0-9]*.[0-9]*.[0-9]*) version="v$version" ;;
    v[0-9]*.[0-9]*.[0-9]*) ;;
    *) fail "invalid release version: $version" ;;
esac

base_url=${BAMARK_BASE_URL:-https://github.com/$repo/releases/download/$version}
archive="bamark-${version}-${platform}-${arch}.tar.gz"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bamark-install.XXXXXX")

cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

curl -fL --retry 3 -o "$tmp/$archive" "$base_url/$archive"
curl -fL --retry 3 -o "$tmp/SHA256SUMS" "$base_url/SHA256SUMS"

expected=$(awk -v file="$archive" '$2 == file || $2 == "*" file { print $1; exit }' "$tmp/SHA256SUMS")
[ -n "$expected" ] || fail "no checksum found for $archive"

if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$archive" | awk '{print $1}')
else
    actual=$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')
fi

[ "$(printf '%s' "$actual" | tr 'A-F' 'a-f')" = "$(printf '%s' "$expected" | tr 'A-F' 'a-f')" ] \
    || fail 'checksum verification failed'

mkdir -p "$tmp/extract" "$install_dir"
tar -xzf "$tmp/$archive" -C "$tmp/extract"
test -f "$tmp/extract/bamark" || fail 'release archive did not contain bamark'
install -m 0755 "$tmp/extract/bamark" "$install_dir/bamark"

printf 'Installed bamark %s to %s/bamark\n' "$version" "$install_dir"
case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) printf 'Add %s to PATH to run bamark from any shell.\n' "$install_dir" ;;
esac
