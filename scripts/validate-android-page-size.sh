#!/usr/bin/env bash
set -euo pipefail

required_alignment=16384
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_readelf() {
  if command -v llvm-readelf >/dev/null 2>&1; then
    command -v llvm-readelf
    return 0
  fi

  local sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  if [ -d "$sdk_root/ndk" ]; then
    find "$sdk_root/ndk" -path '*/toolchains/llvm/prebuilt/*/bin/llvm-readelf' | sort | tail -n 1
    return 0
  fi

  return 1
}

readelf_bin="$(find_readelf || true)"
if [ -z "$readelf_bin" ]; then
  echo "Unable to find llvm-readelf. Install Android NDK or set ANDROID_HOME/ANDROID_SDK_ROOT." >&2
  exit 1
fi

echo "Using: $readelf_bin"

so_list="$(mktemp)"
trap 'rm -f "$so_list"' EXIT
find "$repo_root" \
  \( -path '*/libsodium*' -o -path '*/android/build*' -o -path '*/android/lib*' \) \
  -name '*.so' -type f | sort > "$so_list"

if [ ! -s "$so_list" ]; then
  echo "No Android .so files found. Build or extract precompiled.tgz first." >&2
  exit 1
fi

failed=0
while IFS= read -r so; do
  rel="${so#$repo_root/}"
  output="$($readelf_bin -l "$so")"
  alignments="$(printf '%s\n' "$output" | awk '/LOAD/ { print $NF }')"

  if [ -z "$alignments" ]; then
    echo "FAIL $rel: no LOAD segments found"
    failed=1
    continue
  fi

  while IFS= read -r alignment; do
    [ -n "$alignment" ] || continue
    value=$((alignment))
    if [ "$value" -lt "$required_alignment" ]; then
      echo "FAIL $rel: LOAD alignment $alignment is less than 0x4000"
      failed=1
    fi
  done <<< "$alignments"

  if ! printf '%s\n' "$alignments" | while IFS= read -r alignment; do [ $((alignment)) -ge "$required_alignment" ] || exit 1; done; then
    :
  else
    echo "OK   $rel"
  fi
done < "$so_list"

exit "$failed"
