#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "$script_dir"

swift build -c release

app_dir="$script_dir/dist/Private Presenter.app"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$script_dir/.build/release/PrivatePresenter" "$app_dir/Contents/MacOS/PrivatePresenter"

/usr/libexec/PlistBuddy -c "Clear dict" "$app_dir/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Private Presenter" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Private Presenter" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string in.aryab.private-presenter" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string PrivatePresenter" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$app_dir/Contents/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
