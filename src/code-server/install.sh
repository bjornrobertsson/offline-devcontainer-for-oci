#!/usr/bin/env bash
set -e

# Resolve feature options (fall back to sane defaults)
CODE_SERVER_VERSION="${VERSION:-}"
CODE_SERVER_AUTH="${AUTH:-password}"
CODE_SERVER_HOST="${HOST:-127.0.0.1}"
CODE_SERVER_PORT="${PORT:-8080}"
CODE_SERVER_LOGFILE="${LOGFILE:-/tmp/code-server.log}"
CODE_SERVER_WORKSPACE_OPT="${WORKSPACE:-}"
CODE_SERVER_EXTENSIONS="${EXTENSIONS:-}"
CODE_SERVER_VERBOSE="${VERBOSE:-false}"
CODE_SERVER_DISABLE_TELEMETRY="${DISABLETELEMETRY:-false}"
CODE_SERVER_DISABLE_UPDATE_CHECK="${DISABLEUPDATECHECK:-false}"
CODE_SERVER_DISABLE_FILE_DOWNLOADS="${DISABLEFILEDOWNLOADS:-false}"
CODE_SERVER_DISABLE_FILE_UPLOADS="${DISABLEFILEUPLOADS:-false}"
CODE_SERVER_DISABLE_PROXY="${DISABLEPROXY:-false}"
CODE_SERVER_DISABLE_WORKSPACE_TRUST="${DISABLEWORKSPACETRUST:-false}"
CODE_SERVER_DISABLE_GETTING_STARTED_OVERRIDE="${DISABLEGETTINGSTARTEDOVERRIDE:-false}"
CODE_SERVER_CERT="${CERT:-}"
CODE_SERVER_CERT_HOST="${CERTHOST:-}"
CODE_SERVER_CERT_KEY="${CERTKEY:-}"
CODE_SERVER_SOCKET="${SOCKET:-}"
CODE_SERVER_SOCKET_MODE="${SOCKETMODE:-}"
CODE_SERVER_LOCALE="${LOCALE:-}"
CODE_SERVER_APP_NAME="${APPNAME:-}"
CODE_SERVER_WELCOME_TEXT="${WELCOMETEXT:-}"
CODE_SERVER_TRUSTED_ORIGINS="${TRUSTEDORIGINS:-}"
CODE_SERVER_PROXY_DOMAIN="${PROXYDOMAIN:-}"
CODE_SERVER_ABS_PROXY_BASE_PATH="${ABSPROXYBASEPATH:-}"
LOCAL_TARBALL="${LOCALTARBALL:-${localTarball:-}}"
ASSET_ARCH="${ASSETARCH:-${assetArch:-linux-amd64}}"

# Ensure basic tools are present (no dependsOn on common-utils)
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y && apt-get install -y --no-install-recommends curl ca-certificates sudo coreutils
  rm -rf /var/lib/apt/lists/*
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache curl ca-certificates sudo coreutils
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y curl ca-certificates sudo coreutils || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl ca-certificates sudo coreutils || true
fi

# Detect target user and home robustly (no reliance on _REMOTE_USER/common-utils)
resolve_user() {
  if [ -n "${_REMOTE_USER:-}" ] && id "${_REMOTE_USER}" >/dev/null 2>&1; then
    echo "${_REMOTE_USER}"
    return
  fi
  if [ -n "${USERNAME:-}" ] && id "${USERNAME}" >/dev/null 2>&1; then
    echo "${USERNAME}"
    return
  fi
  # First non-root user with uid >= 1000
  if command -v getent >/dev/null 2>&1; then
    getent passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}'
  else
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd
  fi
}

USERNAME_RESOLVED="$(resolve_user)"
if [ -z "$USERNAME_RESOLVED" ]; then
  USERNAME_RESOLVED="devcontainer"
  if ! id "$USERNAME_RESOLVED" >/dev/null 2>&1; then
    if command -v groupadd >/dev/null 2>&1; then groupadd --gid 1000 "$USERNAME_RESOLVED" || true; fi
    if command -v useradd  >/dev/null 2>&1; then useradd --uid 1000 --gid 1000 -m -s /bin/bash "$USERNAME_RESOLVED"; fi
    echo "$USERNAME_RESOLVED ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME_RESOLVED
    chmod 0440 /etc/sudoers.d/$USERNAME_RESOLVED
  fi
fi

# Resolve home directory
if command -v getent >/dev/null 2>&1; then
  USER_HOME="$(getent passwd "$USERNAME_RESOLVED" | cut -d: -f6)"
else
  USER_HOME="$(awk -F: -v u="$USERNAME_RESOLVED" '$1==u{print $6}' /etc/passwd)"
fi
[ -z "$USER_HOME" ] && USER_HOME="/home/$USERNAME_RESOLVED"

# Install code-server from local tarball if provided; otherwise use official installer
install_code_server() {
  if [ -n "$LOCAL_TARBALL" ] && [ -f "$LOCAL_TARBALL" ]; then
    tar -xzf "$LOCAL_TARBALL" -C /tmp
    BASENAME="$(basename "$LOCAL_TARBALL" .tar.gz)"
    # Expected form: code-server-<VERSION>-<arch>
    if [ -d "/tmp/$BASENAME" ]; then
      mv "/tmp/$BASENAME/bin/code-server" /usr/local/bin/
      mv "/tmp/$BASENAME/lib/vscode" /usr/local/lib/
      rm -rf "/tmp/$BASENAME"
      return
    fi
    # Fallback: discover extracted dir
    EXTRACTED_DIR="$(tar -tzf "$LOCAL_TARBALL" | head -1 | cut -f1 -d"/")"
    if [ -n "$EXTRACTED_DIR" ] && [ -d "/tmp/$EXTRACTED_DIR" ]; then
      mv "/tmp/$EXTRACTED_DIR/bin/code-server" /usr/local/bin/
      mv "/tmp/$EXTRACTED_DIR/lib/vscode" /usr/local/lib/
      rm -rf "/tmp/$EXTRACTED_DIR"
      return
    fi
  fi

  INSTALL_ARGS=""
  if [ -n "$CODE_SERVER_VERSION" ]; then
    INSTALL_ARGS="$INSTALL_ARGS --version=\"$CODE_SERVER_VERSION\""
  fi
  curl -fsSL https://code-server.dev/install.sh | sh -s -- $INSTALL_ARGS
}

install_code_server

# Install extensions
IFS=',' read -ra EXT_ARR <<<"$CODE_SERVER_EXTENSIONS"
for extension in "${EXT_ARR[@]}"; do
  [ -n "$extension" ] || continue
  sudo -u "$USERNAME_RESOLVED" code-server --install-extension "$extension" || true
done

# Determine workspace
CODE_SERVER_WORKSPACE="$USER_HOME"
[ -n "$CODE_SERVER_WORKSPACE_OPT" ] && CODE_SERVER_WORKSPACE="$CODE_SERVER_WORKSPACE_OPT"

# Build flag array
FLAGS=()
FLAGS+=(--auth "$CODE_SERVER_AUTH")
FLAGS+=(--bind-addr "$CODE_SERVER_HOST:$CODE_SERVER_PORT")

[ "$CODE_SERVER_DISABLE_FILE_DOWNLOADS" = "true" ] && FLAGS+=(--disable-file-downloads)
[ "$CODE_SERVER_DISABLE_FILE_UPLOADS" = "true" ] && FLAGS+=(--disable-file-uploads)
[ "$CODE_SERVER_DISABLE_GETTING_STARTED_OVERRIDE" = "true" ] && FLAGS+=(--disable-getting-started-override)
[ "$CODE_SERVER_DISABLE_PROXY" = "true" ] && FLAGS+=(--disable-proxy)
[ "$CODE_SERVER_DISABLE_TELEMETRY" = "true" ] && FLAGS+=(--disable-telemetry)
[ "$CODE_SERVER_DISABLE_UPDATE_CHECK" = "true" ] && FLAGS+=(--disable-update-check)
[ "$CODE_SERVER_DISABLE_WORKSPACE_TRUST" = "true" ] && FLAGS+=(--disable-workspace-trust)
[ -n "$CODE_SERVER_CERT" ] && FLAGS+=(--cert "$CODE_SERVER_CERT")
[ -n "$CODE_SERVER_CERT_HOST" ] && FLAGS+=(--cert-host "$CODE_SERVER_CERT_HOST")
[ -n "$CODE_SERVER_CERT_KEY" ] && FLAGS+=(--cert-key "$CODE_SERVER_CERT_KEY")
[ -n "$CODE_SERVER_SOCKET" ] && FLAGS+=(--socket "$CODE_SERVER_SOCKET")
[ -n "$CODE_SERVER_SOCKET_MODE" ] && FLAGS+=(--socket-mode "$CODE_SERVER_SOCKET_MODE")
[ -n "$CODE_SERVER_LOCALE" ] && FLAGS+=(--locale "$CODE_SERVER_LOCALE")
[ -n "$CODE_SERVER_APP_NAME" ] && FLAGS+=(--app-name "$CODE_SERVER_APP_NAME")
[ -n "$CODE_SERVER_WELCOME_TEXT" ] && FLAGS+=(--welcome-text "$CODE_SERVER_WELCOME_TEXT")
[ -n "$CODE_SERVER_PROXY_DOMAIN" ] && FLAGS+=(--proxy-domain "$CODE_SERVER_PROXY_DOMAIN")
[ -n "$CODE_SERVER_ABS_PROXY_BASE_PATH" ] && FLAGS+=(--abs-proxy-base-path "$CODE_SERVER_ABS_PROXY_BASE_PATH")

IFS=',' read -ra TO_ARR <<<"$CODE_SERVER_TRUSTED_ORIGINS"
for origin in "${TO_ARR[@]}"; do [ -n "$origin" ] && FLAGS+=(--trusted-origins "$origin"); done

# Entry-point script that re-execs as the resolved user
cat > /usr/local/bin/code-server-entrypoint <<EOF
#!/usr/bin/env bash
set -e

RESOLVED_USER="$USERNAME_RESOLVED"
if [[ \\$(whoami) != "\\$RESOLVED_USER" ]]; then
    exec su "\\$RESOLVED_USER" -c /usr/local/bin/code-server-entrypoint
fi

$(declare -p FLAGS)

# Optional secret files
[ -f "$PASSWORDFILE" ] && export PASSWORD="\\$(<"$PASSWORDFILE")"
[ -f "$HASHEDPASSWORDFILE" ] && export HASHED_PASSWORD="\\$(<"$HASHEDPASSWORDFILE")"
[ -f "$GITHUBAUTHTOKENFILE" ] && export GITHUB_TOKEN="\\$(<"$GITHUBAUTHTOKENFILE")"

exec code-server "\\${FLAGS[@]}" "$CODE_SERVER_WORKSPACE" >"$CODE_SERVER_LOGFILE" 2>&1
EOF

chmod +x /usr/local/bin/code-server-entrypoint
