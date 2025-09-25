#!/usr/bin/env bash
set -x

IMAGE="localhost:5000/features/code-server:1.0.0-oci.0"
DOCKERFILE="Dockerfile.feature-code-server"
CONTEXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUSH="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --dockerfile) DOCKERFILE="$2"; shift 2 ;;
    --no-push) PUSH="false"; shift 1 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Validate presence of feature files
[[ -f "$CONTEXT_DIR/src/code-server/devcontainer-feature.json" ]] || { echo "Missing devcontainer-feature.json"; exit 1; }
[[ -f "$CONTEXT_DIR/src/code-server/install.sh" ]] || { echo "Missing install.sh"; exit 1; }

DOCKER_BUILDKIT=1 docker build \
  -f "$CONTEXT_DIR/$DOCKERFILE" \
  -t "$IMAGE" \
  "$CONTEXT_DIR"

if [[ "$PUSH" == "true" ]]; then
  docker push "$IMAGE"
fi

echo "Built Feature artifact: $IMAGE"
