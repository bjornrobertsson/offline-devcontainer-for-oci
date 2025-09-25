# Offline Devcontainer via OCI (no devcontainer features)

This repository provides a simple, offline-first workflow for running VS Code in the browser (code-server) using plain Dockerfiles and a local OCI registry. It intentionally avoids devcontainer "features" to remove the network dependency chain.

## Why this exists
- Some environments are air-gapped or constrained
- Devcontainer features pull artifacts at runtime (not ideal offline)
- Installing code-server inside an image is straightforward and predictable

## What you get
- Offline Dockerfile that installs code-server during build time
- Optional local OCI registry (registry:2) via docker-compose
- Scripts to fetch artifacts and build/push your image
- Example devcontainer.json that references the built image directly

## Quickstart
1) Start a local registry (optional, for convenient distribution)

```bash
cd docker/registry
docker compose up -d
# Registry available at http://localhost:5000
```

2) Fetch code-server artifact on a connected machine

```bash
./scripts/fetch_artifacts.sh --version 4.22.1 --arch linux-amd64
# artifacts/code-server-4.22.1-linux-amd64.tar.gz
```

3) Build and (optionally) push to your local registry

```bash
./scripts/build_and_push.sh \
  --image localhost:5000/offline/code-server:1.0.0 \
  --version 4.22.1
```

4) Use with devcontainer.json (no features)

```json
{
  "image": "localhost:5000/offline/code-server:1.0.0",
  "forwardPorts": [8080],
  "remoteUser": "devcontainer"
}
```

## Notes
- This approach is offline at runtime; artifacts are acquired at build time
- For fully air-gapped builds, pre-stage the tarball into `artifacts/` and build where Docker can access it without internet
- For more complete offline images (conda, docker-in-docker, etc.), see the companion repository:
  - https://github.com/bjornrobertsson/offline-dockerfiles

## Rationale
This repo demonstrates a simpler path: build an image with code-server directly, push it to a local OCI registry, and consume it in `devcontainer.json` without any features or `dependsOn`.
