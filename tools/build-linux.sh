#!/usr/bin/env bash
set -euo pipefail

version="${1:-dev}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_project="$project_root/godot"
dist_root="$project_root/dist"
package_name="narra-linux-x86_64"
package_dir="$dist_root/$package_name"
client_path="$package_dir/Narra.x86_64"
release_scenario="tianqi"
release_scenario_id="tianqi_t00"
archive_name="$package_name.tar.gz"
if [[ "$version" != "dev" ]]; then
  archive_name="narra-linux-x86_64-${version}.tar.gz"
fi
archive_path="$dist_root/$archive_name"

for command_name in go godot git sha256sum tar; do
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

rm -rf "$package_dir"
rm -f "$archive_path"
mkdir -p "$package_dir"

cd "$project_root"
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  go test ./...
fi

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o "$package_dir/narra-server" ./cmd/server

godot --headless --path "$godot_project" --editor --quit
godot --headless --path "$godot_project" --export-release "Linux" "$client_path"

[[ -f "$client_path" ]] || {
  echo "Godot did not create the expected Linux executable: $client_path" >&2
  exit 1
}
chmod 0755 "$client_path" "$package_dir/narra-server"
mkdir -p "$package_dir/data"
cp -R "$project_root/data/$release_scenario" "$package_dir/data/$release_scenario"

resolved_version="$version"
git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
source_dirty=false
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  source_dirty=true
fi
built_at_utc="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf '%s\n' \
  '{' \
  '  "application": "Narra",' \
  "  \"version\": \"$resolved_version\"," \
  "  \"commit\": \"$git_commit\"," \
  "  \"source_dirty\": $source_dirty," \
  "  \"built_at_utc\": \"$built_at_utc\"," \
  '  "platform": "linux-x86_64",' \
  "  \"scenario\": \"$release_scenario\"," \
  "  \"scenario_id\": \"$release_scenario_id\"" \
  '}' >"$package_dir/build-info.json"

printf '%s\n' \
  'Narra for Linux x86_64' \
  '' \
  'Run ./Narra.x86_64 to start the game.' \
  'The bundled local rules service starts and stops with the application.' \
  'Logs, saves, and crash diagnostics are stored under ~/.local/share/Narra by default.' \
  'Only the story 《天变邸抄》 is included in this release.' >"$package_dir/README.txt"

if [[ "${SKIP_SMOKE_TEST:-0}" != "1" ]]; then
  "$project_root/tools/smoke-test-linux.sh" "$package_dir" "$release_scenario" "$release_scenario_id"
fi

(
  cd "$package_dir"
  find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
) >"$package_dir/SHA256SUMS.txt"

tar -C "$dist_root" -czf "$archive_path" "$package_name"
echo "Linux package built successfully: $archive_path"
