#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${1:-}" == "clean" ]]; then
	rm -rf "$ROOT_DIR/dist"
	echo "Removed $ROOT_DIR/dist"
	exit 0
fi

if [[ $# -gt 0 ]]; then
	echo "Usage: $0 [clean]" >&2
	exit 2
fi

if [[ -x "/Users/july/.local/go/bin/go" ]]; then
	GO="/Users/july/.local/go/bin/go"
elif command -v go >/dev/null 2>&1; then
	GO="$(command -v go)"
else
	echo "error: go not found at /Users/july/.local/go/bin/go or on PATH" >&2
	exit 1
fi

VERSION="$(git describe --tags --always --dirty)"
LDFLAGS="-s -w -X main.version=${VERSION}"
DIST_DIR="$ROOT_DIR/dist"
DW_BIN="$DIST_DIR/magpie-dw"
FULL_BIN="$DIST_DIR/magpie-full"
RAW_BIN="$DIST_DIR/magpie-raw"

file_bytes() {
	wc -c < "$1" | tr -d '[:space:]'
}

file_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

format_mb() {
	awk -v b="$1" 'BEGIN { printf "%.2f", b / 1048576 }'
}

report_binary() {
	local label="$1"
	local path="$2"
	local bytes mb sha
	bytes="$(file_bytes "$path")"
	mb="$(format_mb "$bytes")"
	sha="$(file_sha256 "$path")"
	printf '%s: %s MB (%s bytes)  sha256=%s\n' "$label" "$mb" "$bytes" "$sha"
}

mkdir -p "$DIST_DIR"

echo "Building magpie-raw (default tags, no strip, the baseline)..."
"$GO" build -o "$RAW_BIN" .
report_binary "magpie-raw" "$RAW_BIN"

echo "Building magpie-dw (-tags deepworks, version=${VERSION})..."
"$GO" build -tags deepworks -trimpath -ldflags "$LDFLAGS" -o "$DW_BIN" .
report_binary "magpie-dw" "$DW_BIN"

echo "Building magpie-full (default tags, version=${VERSION})..."
"$GO" build -trimpath -ldflags "$LDFLAGS" -o "$FULL_BIN" .
report_binary "magpie-full" "$FULL_BIN"

raw_bytes="$(file_bytes "$RAW_BIN")"
dw_bytes="$(file_bytes "$DW_BIN")"
full_bytes="$(file_bytes "$FULL_BIN")"
strip_saved=$(( raw_bytes - full_bytes ))
strip_pct="$(awk -v s="$strip_saved" -v f="$raw_bytes" 'BEGIN { if (f > 0) printf "%.1f", (s * 100.0) / f; else printf "0.0" }')"
tag_saved=$(( full_bytes - dw_bytes ))
printf 'Strip (-s -w -trimpath): saved %s bytes (%s%%) - this is the real weight\n' "$strip_saved" "$strip_pct"
printf 'Tag   (-tags deepworks):  saved %s bytes - identity only, the same code\n' "$tag_saved"

dw_version="$(./dist/magpie-dw --version)"
echo "magpie-dw --version: $dw_version"
if [[ "$dw_version" != *"DeepWorks"* ]]; then
	echo "error: expected ./dist/magpie-dw --version to contain 'DeepWorks', got: $dw_version" >&2
	exit 1
fi

full_version="$(./dist/magpie-full --version)"
echo "magpie-full --version: $full_version"
if [[ "$full_version" != "magpie"* ]]; then
	echo "error: expected ./dist/magpie-full --version to print 'magpie', got: $full_version" >&2
	exit 1
fi
