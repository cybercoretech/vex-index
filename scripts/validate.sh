#!/usr/bin/env bash
# Validates index.json for the Vex package index.
#
#   scripts/validate.sh [BASE_INDEX]
#
# Always checks structure: schema 1, valid names/versions, https URLs,
# 64-char lowercase hex SHA-256, sizes between 1 byte and 64 MiB.
#
# With BASE_INDEX (the index.json from the target branch), also enforces
# immutability: existing versions may not change or disappear, except that
# `yanked` may go from false to true. Every version that is new relative to
# BASE_INDEX is downloaded and its size and SHA-256 are checked.
set -euo pipefail

index=${INDEX:-index.json}
base=${1:-}
max=$((64 * 1024 * 1024))
fail=0
err() { echo "::error::$*" >&2; fail=1; }

jq -e . "$index" >/dev/null || { err "$index is not valid JSON"; exit 1; }

[[ $(jq -r '.schema' "$index") == 1 ]] || err "schema must be 1"
[[ $(jq -r '.packages | type' "$index") == object ]] || err "packages must be an object"

component='^[A-Za-z0-9_+][A-Za-z0-9._+-]{0,127}$'

while IFS=$'\t' read -r name version url sha size yanked; do
  where="$name@$version"
  [[ $name =~ $component ]] || err "$where: invalid package name"
  [[ $version =~ $component ]] || err "$where: invalid version"
  [[ $url == https://* ]] || err "$where: url must be https://"
  [[ $sha =~ ^[0-9a-f]{64}$ ]] || err "$where: sha256 must be 64 lowercase hex characters"
  [[ $size =~ ^[0-9]+$ ]] && (( size > 0 && size <= max )) || err "$where: size must be 1..$max"
  [[ $yanked == true || $yanked == false ]] || err "$where: yanked must be a boolean"
done < <(jq -r '.packages | to_entries[] | .key as $n | (.value.versions // {}) | to_entries[]
  | [$n, .key, (.value.url // ""), (.value.sha256 // ""), (.value.size // ""), (.value.yanked // false)] | @tsv' "$index")

if [[ -n $base ]]; then
  # Existing versions: unchanged apart from yanked false -> true.
  while IFS=$'\t' read -r name version; do
    old=$(jq -c --arg n "$name" --arg v "$version" '.packages[$n].versions[$v] | del(.yanked)' "$base")
    new=$(jq -c --arg n "$name" --arg v "$version" '.packages[$n].versions[$v] // null | if . == null then null else del(.yanked) end' "$index")
    if [[ $new == null ]]; then
      err "$name@$version was removed; yank it instead"
    elif [[ $old != "$new" ]]; then
      err "$name@$version was modified; published versions are immutable"
    fi
    was=$(jq -r --arg n "$name" --arg v "$version" '.packages[$n].versions[$v].yanked // false' "$base")
    now=$(jq -r --arg n "$name" --arg v "$version" '.packages[$n].versions[$v].yanked // false' "$index")
    [[ $was == true && $now != true ]] && err "$name@$version cannot be un-yanked"
  done < <(jq -r '.packages | to_entries[] | .key as $n | (.value.versions // {}) | keys[] | [$n, .] | @tsv' "$base")

  # New versions: download and verify.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  while IFS=$'\t' read -r name version url sha size; do
    if jq -e --arg n "$name" --arg v "$version" '.packages[$n].versions[$v]' "$base" >/dev/null; then
      continue
    fi
    echo "verifying new version $name@$version"
    if ! curl -fsSL --proto '=https' --max-filesize "$max" -o "$tmp/pkg" "$url"; then
      err "$name@$version: cannot download $url"
      continue
    fi
    actual_size=$(stat -c %s "$tmp/pkg")
    actual_sha=$(sha256sum "$tmp/pkg" | cut -d' ' -f1)
    [[ $actual_size == "$size" ]] || err "$name@$version: size is $actual_size, index says $size"
    [[ $actual_sha == "$sha" ]] || err "$name@$version: sha256 is $actual_sha, index says $sha"
  done < <(jq -r '.packages | to_entries[] | .key as $n | (.value.versions // {}) | to_entries[]
    | [$n, .key, .value.url, .value.sha256, .value.size] | @tsv' "$index")
fi

if (( fail )); then
  echo "index validation failed" >&2
  exit 1
fi
echo "index.json is valid ($(jq '[.packages[].versions | length] | add // 0' "$index") versions in $(jq '.packages | length' "$index") packages)"
