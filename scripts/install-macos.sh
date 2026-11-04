#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
    echo 'This installer requires macOS.' >&2
    exit 1
fi
release='https://github.com/aryacooks/private-presenter-/releases/latest/download'
asset='PrivatePresenter-macos-universal.zip'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fLsS "$release/$asset" -o "$work/$asset"
curl -fLsS "$release/SHA256SUMS" -o "$work/SHA256SUMS"
expected="$(awk -v name="$asset" '$2 == name {print $1}' "$work/SHA256SUMS")"
actual="$(shasum -a 256 "$work/$asset" | awk '{print $1}')"
if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    echo 'Download checksum verification failed.' >&2
    exit 1
fi
if pgrep -x PrivatePresenter >/dev/null; then
    echo 'Quit Private Presenter from its menu-bar menu, then run this installer again.' >&2
    exit 1
fi
ditto -x -k "$work/$asset" "$work/unpacked"
codesign --verify --deep --strict "$work/unpacked/Private Presenter.app"
mkdir -p "$HOME/Applications"
ditto "$work/unpacked/Private Presenter.app" "$HOME/Applications/Private Presenter.app"
echo "Installed in $HOME/Applications/Private Presenter.app"
open "$HOME/Applications/Private Presenter.app"
