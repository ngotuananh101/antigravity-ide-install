#!/bin/bash
set -e
set -o pipefail

RELEASES_API="https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases"
TMP_DIR="/tmp"
INSTALL_DIR="$HOME/.local/share/AntigravityIDE"
SYMLINK_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
VERSION_FILE="$INSTALL_DIR/.installed_version"
BIN_NAME="antigravity-ide"
DESKTOP_FILE="$DESKTOP_DIR/$BIN_NAME.desktop"
ICON_DEST="$ICON_DIR/$BIN_NAME.png"

info()  { echo -e "\e[94m$1\e[39m"; }
ok()    { echo -e "\e[32m$1\e[39m"; }
err()   { echo -e "\e[31m$1\e[39m" >&2; }

echo "### Antigravity CLI installer ###"

# Detect CPU architecture
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64) ARCH_TAG="x64" ;;
  aarch64|arm64) ARCH_TAG="arm" ;;
  *)
    err "Unsupported architecture: $ARCH_RAW"
    exit 1
    ;;
esac

# Fetch latest release info
info "Checking latest version..."
RELEASES_JSON=$(curl -fsSL "$RELEASES_API")
[ -z "$RELEASES_JSON" ] && { err "Failed to fetch $RELEASES_API"; exit 1; }

LATEST_VERSION=$(echo "$RELEASES_JSON" | grep -Po '"version"\s*:\s*"\K[^"]+' | head -n1)
LATEST_EXEC_ID=$(echo "$RELEASES_JSON" | grep -Po '"execution_id"\s*:\s*"\K[^"]+' | head -n1)

[ -z "$LATEST_VERSION" ] || [ -z "$LATEST_EXEC_ID" ] && { err "Could not parse version/execution_id from API response."; exit 1; }

info "Latest version: $LATEST_VERSION (execution_id: $LATEST_EXEC_ID)"

# Check currently installed version
CURRENT_VERSION=""
[ -f "$VERSION_FILE" ] && CURRENT_VERSION=$(cat "$VERSION_FILE")
info "Installed version: ${CURRENT_VERSION:-none}"

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
  ok "Antigravity CLI is already up to date ($CURRENT_VERSION)."
  exit 0
fi

# Build download URL and fetch archive
ARCHIVE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${LATEST_VERSION}-${LATEST_EXEC_ID}/linux-${ARCH_TAG}/Antigravity%20IDE.tar.gz"
ARCHIVE_FILENAME="antigravity-${LATEST_VERSION}-linux-${ARCH_TAG}.tar.gz"

info "Downloading $ARCHIVE_URL ..."
rm -f "$TMP_DIR/$ARCHIVE_FILENAME" 2>/dev/null || true
wget -q --show-progress -cO "$TMP_DIR/$ARCHIVE_FILENAME" "$ARCHIVE_URL"

# Extract
info "Extracting to $INSTALL_DIR ..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP_DIR/$ARCHIVE_FILENAME" -C "$INSTALL_DIR" --strip-components=1
rm -f "$TMP_DIR/$ARCHIVE_FILENAME"

# Locate binary and symlink it
BIN_PATH=$(find "$INSTALL_DIR" -maxdepth 3 -type f -iname "$BIN_NAME" | head -n1)
[ -z "$BIN_PATH" ] && { err "Could not find executable '$BIN_NAME' in $INSTALL_DIR"; exit 1; }
chmod +x "$BIN_PATH"

mkdir -p "$SYMLINK_DIR"
rm -f "$SYMLINK_DIR/$BIN_NAME" 2>/dev/null || true
ln -s "$BIN_PATH" "$SYMLINK_DIR/$BIN_NAME"

echo "$LATEST_VERSION" > "$VERSION_FILE"

# Install desktop icon (app menu launcher)
info "Setting up desktop icon..."
mkdir -p "$DESKTOP_DIR" "$ICON_DIR"

ICON_SRC="$INSTALL_DIR/resources/app/resources/linux/code.png"

if [ -f "$ICON_SRC" ]; then
  cp -f "$ICON_SRC" "$ICON_DEST"
else
  info "No icon file found in the package; the launcher will use a generic icon."
fi

cat > "$DESKTOP_FILE" << DESKTOP_EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=Antigravity IDE
Exec=$SYMLINK_DIR/$BIN_NAME %u
Icon=${ICON_DEST}
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=$BIN_NAME
MimeType=x-scheme-handler/antigravity-ide;
DESKTOP_EOF

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# Register as the default handler for antigravity-ide:// links (e.g. OAuth callbacks)
if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default "$(basename "$DESKTOP_FILE")" x-scheme-handler/antigravity-ide
  info "Registered as default handler for antigravity-ide:// links."
else
  info "xdg-mime not found; skipping antigravity-ide:// URL scheme registration."
fi

ok "Done! Antigravity CLI $LATEST_VERSION installed at $INSTALL_DIR"
ok "Run '$BIN_NAME' to use it (make sure $SYMLINK_DIR is in your PATH), or launch it from your application menu."

case ":$PATH:" in
  *":$SYMLINK_DIR:"*) ;;
  *) info "Add this to ~/.profile or ~/.bashrc:\n  export PATH=\"$SYMLINK_DIR:\$PATH\"" ;;
esac
