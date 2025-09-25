#!/usr/bin/env bash
set -x

IMAGE="localhost:5000/offline/code-server:1.0.0"
VERSION="4.22.1"
DOCKERFILE="dockerfiles/Dockerfile.offline"
CONTEXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUSH="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --dockerfile) DOCKERFILE="$2"; shift 2 ;;
    --no-push) PUSH="false"; shift 1 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

ARTIFACT="${CONTEXT_DIR}/artifacts/code-server-${VERSION}-linux-amd64.tar.gz"
if [[ ! -f "$ARTIFACT" && "$DOCKERFILE" == *"offline"* ]]; then
  echo "Missing artifact: $ARTIFACT"
  echo "Fetch it first: ./scripts/fetch_artifacts.sh --version ${VERSION}"
  exit 1
fi

# Build
DOCKER_BUILDKIT=1 docker build \
  -f "$CONTEXT_DIR/$DOCKERFILE" \
  --build-arg CODE_SERVER_VERSION="$VERSION" \
  -t "$IMAGE" \
  "$CONTEXT_DIR"

# Push (optional)
if [[ "$PUSH" == "true" ]]; then
  docker push "$IMAGE"
fi

echo "Built image: $IMAGE"
