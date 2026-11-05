#!/bin/bash
set -euo pipefail

if [[ $# -gt 1 || (${1:-} != "" && ${1:-} != --test) ]]; then
    printf 'Usage: %s [--test]\n' "$0" >&2
    exit 2
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$repo_dir/build"
mkdir -p "$build_dir"

sdk="$(xcrun --sdk macosx --show-sdk-path)"
swiftc="$(xcrun --sdk macosx --find swiftc)"
minimum_macos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$repo_dir/Info.plist")"
target="$(uname -m)-apple-macos$minimum_macos"
swift_args=(-sdk "$sdk" -target "$target" -module-cache-path "$build_dir/module-cache")

"$swiftc" "${swift_args[@]}" \
    "$repo_dir/Sources/SpaceCycle.swift" "$repo_dir/Sources/PointerWrap.swift" "$repo_dir/Tests/SpaceCycleCheck.swift" \
    -o "$build_dir/SpaceCycleCheck"
"$build_dir/SpaceCycleCheck"
if [[ ${1:-} == --test ]]; then
    exit 0
fi

app_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$repo_dir/Info.plist")"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$repo_dir/Info.plist")"
staging_dir="$(mktemp -d "$build_dir/.less-pain-code.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
staged_app="$staging_dir/$app_name.app"
resources="$staged_app/Contents/Resources"
mkdir -p "$staged_app/Contents/MacOS" "$resources"

"$swiftc" "${swift_args[@]}" -O \
    "$repo_dir/Sources/MouseNav.swift" "$repo_dir/Sources/MacSpaces.swift" \
    "$repo_dir/Sources/SpaceCycle.swift" "$repo_dir/Sources/PointerWrap.swift" -o "$staged_app/Contents/MacOS/$executable_name"
cp "$repo_dir/Info.plist" "$staged_app/Contents/"
cp "$repo_dir/Resources/AppIcon.icns" "$repo_dir/Resources/WhiteCat.png" \
    "$repo_dir/LICENSE" "$repo_dir/THIRD_PARTY_NOTICES.md" "$resources/"
cp -R "$repo_dir/licenses" "$resources/"
codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --strict "$staged_app"

app="$build_dir/$app_name.app"
rm -rf "$app"
mv "$staged_app" "$app"
printf 'Built %s\n' "$app"
