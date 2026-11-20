#!/usr/bin/env bash
# Build the DeepWorks edition for every platform this machine can reach.
#
# It is not a test by itself: a cross-compile that links but dies on start has
# fooled this repo before. Running it is what counts, and only the host's own
# binary can run here — .github/workflows/deepworks.yml is where the others
# actually start.
#
#   ./scripts/build-cross.sh            build everything into dist/
#   ./scripts/build-cross.sh clean      remove dist/
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

VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo dev)"
DIST="$ROOT_DIR/dist"
mkdir -p "$DIST"

build() {
	local goos="$1" goarch="$2" tags="$3" out="$4"
	local ext="" gui=""
	[[ "$goos" == "windows" ]] && ext=".exe" && gui="-H windowsgui"
	if CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" "$GO" build \
		-tags "$tags" -trimpath -buildvcs=false \
		-ldflags "-s -w ${gui} -X main.version=${VERSION}" \
		-o "$DIST/$out$ext" .; then
		printf '  %-16s %-8s %s\n' "$goos/$goarch" "$(du -h "$DIST/$out$ext" | cut -f1)" "$out$ext"
	else
		printf '  %-16s FAILED\n' "$goos/$goarch"
		return 1
	fi
}

echo "DeepWorks edition ${VERSION}"

# The Windows GUI embeds a launcher per architecture; it has to exist first.
for arch in amd64 arm64; do
	CGO_ENABLED=0 GOOS=windows GOARCH="$arch" "$GO" build -trimpath -buildvcs=false \
		-ldflags="-s -w" -o "internal/update/launcher-$arch.com" ./internal/update/launcher
done

echo "CLI (nogui), runs anywhere:"
build linux amd64 "nogui,deepworks" "magpie-dw-linux-amd64"
build linux arm64 "nogui,deepworks" "magpie-dw-linux-arm64"

echo "GUI:"
build windows amd64 "production,comlauncher,deepworks" "magpie-dw-windows-amd64"
build windows arm64 "production,comlauncher,deepworks" "magpie-dw-windows-arm64"

# The Linux GUI links GTK 3 and WebKitGTK 4.1 through cgo and cannot be built
# here; the release workflow builds it on Linux. The host's own build can run.
if "$GO" env GOOS | grep -q darwin; then
	"$GO" build -tags deepworks -trimpath \
		-ldflags "-s -w -X main.version=${VERSION}" \
		-o "$DIST/magpie-dw-darwin-$( "$GO" env GOARCH)" .
	printf '  %-16s %-8s %s\n' "darwin/$( "$GO" env GOARCH)" \
		"$(du -h "$DIST/magpie-dw-darwin-$( "$GO" env GOARCH)" | cut -f1)" "magpie-dw-darwin"
fi

echo
echo "Only the host's binary can be started here. The others are checked by"
echo ".github/workflows/deepworks.yml, which runs each one where it belongs."
