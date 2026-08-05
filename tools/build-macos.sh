#!/usr/bin/env bash
set -euo pipefail

version="${1:-dev}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_project="$project_root/godot"
dist_root="$project_root/dist"
package_name="narra-macos-universal-unsigned"
package_dir="$dist_root/$package_name"
app_path="$package_dir/Narra.app"
runtime_dir="$app_path/Contents/MacOS"
release_scenario="tianqi"
release_scenario_id="tianqi_t00"
archive_name="$package_name.zip"
if [[ "$version" != "dev" ]]; then
  archive_name="narra-macos-universal-${version}-unsigned.zip"
fi
archive_path="$dist_root/$archive_name"

for command_name in go godot git lipo ditto shasum; do
  command -v "$command_name" >/dev/null || {
    echo "Required command is missing: $command_name" >&2
    exit 1
  }
done

case "$package_dir" in
  "$dist_root"/*) ;;
  *)
    echo "Refusing to modify a path outside dist: $package_dir" >&2
    exit 1
    ;;
esac
case "$archive_path" in
  "$dist_root"/*) ;;
  *)
    echo "Refusing to modify a path outside dist: $archive_path" >&2
    exit 1
    ;;
esac

temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

rm -rf "$package_dir"
rm -f "$archive_path"
mkdir -p "$package_dir"

cd "$project_root"
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  go test ./...
fi

CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o "$temporary_dir/narra-server-amd64" ./cmd/server
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o "$temporary_dir/narra-server-arm64" ./cmd/server
lipo -create -output "$temporary_dir/narra-server" "$temporary_dir/narra-server-amd64" "$temporary_dir/narra-server-arm64"
lipo "$temporary_dir/narra-server" -verify_arch x86_64 arm64

godot --headless --path "$godot_project" --editor --quit
godot --headless --path "$godot_project" --export-release "macOS" "$app_path"

[[ -d "$runtime_dir" ]] || {
  echo "Godot did not create the expected application bundle: $app_path" >&2
  exit 1
}
install -m 0755 "$temporary_dir/narra-server" "$runtime_dir/narra-server"
mkdir -p "$runtime_dir/data"
cp -R "$project_root/data/$release_scenario" "$runtime_dir/data/$release_scenario"

git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
source_dirty=false
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  source_dirty=true
fi
built_at_utc="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf '%s\n' \
  '{' \
  '  "application": "Narra",' \
  "  \"version\": \"$version\"," \
  "  \"commit\": \"$git_commit\"," \
  "  \"source_dirty\": $source_dirty," \
  "  \"built_at_utc\": \"$built_at_utc\"," \
  '  "platform": "macos-universal",' \
  "  \"scenario\": \"$release_scenario\"," \
  "  \"scenario_id\": \"$release_scenario_id\"" \
  '}' >"$runtime_dir/build-info.json"

printf '%s\n' \
  'Narra for macOS (unsigned build)' \
  '' \
  'This Universal 2 application supports Intel and Apple Silicon Macs.' \
  'The bundled local rules service starts and stops with the application.' \
  'This automated build is not signed or notarized; Gatekeeper may block it.' \
  'Only the story 《天启邪抄》 is included in this release.' >"$package_dir/README.txt"

if [[ "${SKIP_SMOKE_TEST:-0}" != "1" ]]; then
  "$project_root/tools/smoke-test-macos.sh" "$app_path" "$release_scenario" "$release_scenario_id"
fi

(
  cd "$package_dir"
  find Narra.app -type f -print | LC_ALL=C sort | while IFS= read -r file_path; do
    shasum -a 256 "$file_path"
  done
) >"$package_dir/SHA256SUMS.txt"

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
echo "macOS package built successfully: $archive_path"
