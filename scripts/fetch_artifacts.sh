#!/usr/bin/env bash
set -x

VERSION=""
ARCH="linux-amd64"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/artifacts"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"; shift 2 ;;
    --arch)
      ARCH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 --version <code-server-version> [--arch linux-amd64]"
  exit 1
fi

mkdir -p "$OUT_DIR"
URL="https://github.com/coder/code-server/releases/download/v${VERSION}/code-server-${VERSION}-${ARCH}.tar.gz"
OUT="${OUT_DIR}/code-server-${VERSION}-${ARCH}.tar.gz"

curl -fL --retry 3 -o "$OUT" "$URL"
echo "Downloaded: $OUT"
