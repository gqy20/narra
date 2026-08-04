#!/usr/bin/env bash
set -euo pipefail

app_path="${1:?usage: smoke-test-macos.sh APP_PATH EXPECTED_SCENARIO EXPECTED_SCENARIO_ID}"
expected_scenario="${2:?expected scenario is required}"
expected_scenario_id="${3:?expected scenario id is required}"
client_path="$app_path/Contents/MacOS/Narra"
runtime_dir="$app_path/Contents/MacOS"

[[ -x "$client_path" ]] || {
  echo "Narra executable is missing: $client_path" >&2
  exit 1
}
[[ -x "$runtime_dir/narra-server" ]] || {
  echo "Bundled server is missing or not executable" >&2
  exit 1
}
[[ -f "$runtime_dir/data/$expected_scenario/scenario.yml" ]] || {
  echo "Release scenario is missing" >&2
  exit 1
}
[[ -f "$runtime_dir/build-info.json" ]] || {
  echo "build-info.json is missing" >&2
  exit 1
}
lipo -verify_arch x86_64 arm64 "$client_path"
lipo -verify_arch x86_64 arm64 "$runtime_dir/narra-server"

scenario_count="$(find "$runtime_dir/data" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$scenario_count" == "1" ]] || {
  echo "The release must contain exactly one scenario" >&2
  exit 1
}
if pgrep -x narra-server >/dev/null 2>&1; then
  echo "A narra-server process is already running; stop it before the release smoke test." >&2
  exit 1
fi

"$client_path" --headless --quit-after 600 -- --scenario="$expected_scenario" >/dev/null 2>&1 &
client_pid=$!
cleanup() {
  if kill -0 "$client_pid" >/dev/null 2>&1; then
    kill "$client_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

health_passed=false
for _ in $(seq 1 40); do
  response="$(curl --silent --show-error --max-time 1 http://127.0.0.1:8787/api/v1/health 2>/dev/null || true)"
  if [[ "$response" == *'"api_version":"v1"'* && "$response" == *"\"id\":\"$expected_scenario_id\""* ]]; then
    health_passed=true
    break
  fi
  sleep 0.25
done

if ! wait "$client_pid"; then
  echo "Narra exited unsuccessfully during the macOS smoke test." >&2
  exit 1
fi
[[ "$health_passed" == "true" ]] || {
  echo "The bundled service did not report $expected_scenario_id" >&2
  exit 1
}
sleep 0.5
if pgrep -x narra-server >/dev/null 2>&1; then
  echo "The bundled service remained active after Narra exited." >&2
  exit 1
fi

user_data_dir="$HOME/Library/Application Support/Narra"
for log_name in client.log engine.log server.log; do
  [[ -f "$user_data_dir/logs/$log_name" ]] || {
    echo "Expected log is missing: $log_name" >&2
    exit 1
  }
done
grep -Fq '"source_dirty"' "$runtime_dir/build-info.json" || {
  echo "build-info.json is incomplete" >&2
  exit 1
}
grep -Fq "\"scenario_id\": \"$expected_scenario_id\"" "$runtime_dir/build-info.json" || {
  echo "build-info.json has the wrong scenario" >&2
  exit 1
}

trap - EXIT
echo "macOS release smoke test passed."
