#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP_FILE="$INSTALL_DIR/backhaul_premium.zip"
CORE_DIR="$INSTALL_DIR/backhaul-core"
PACKAGE_NAME="backhaul_premium"
BIN_PATH="/usr/local/bin/bh-tui"

URL_1="https://github.com/RootedOne/BH/blob/main/backhaul_premium.zip"
URL_2="URL_2_HERE"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

install_unzip() {
    if command -v unzip >/dev/null 2>&1; then
        return
    fi

    echo "unzip is not installed. Installing unzip..."

    if command -v apt >/dev/null 2>&1; then
        run_privileged apt update
        run_privileged apt install -y unzip
    elif command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y unzip
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y unzip
    elif command -v pacman >/dev/null 2>&1; then
        run_privileged pacman -Sy --noconfirm unzip
    elif command -v zypper >/dev/null 2>&1; then
        run_privileged zypper install -y unzip
    else
        echo "Could not install unzip automatically. Please install unzip manually."
        exit 1
    fi
}

download_file() {
    local url="$1"
    local tmp_file="$ZIP_FILE.tmp"

    rm -f "$tmp_file"

    if command -v curl >/dev/null 2>&1; then
        if curl -L --fail -o "$tmp_file" "$url"; then
            mv "$tmp_file" "$ZIP_FILE"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -O "$tmp_file" "$url"; then
            mv "$tmp_file" "$ZIP_FILE"
            return 0
        fi
    else
        echo "Neither curl nor wget is installed."
        exit 1
    fi

    rm -f "$tmp_file"
    return 1
}

download_zip() {
    if [ -f "$ZIP_FILE" ]; then
        echo "backhaul_premium.zip already exists. Skipping download."
        return
    fi

    echo "Downloading backhaul_premium.zip from URL 1..."
    if download_file "$URL_1"; then
        echo "Downloaded successfully from URL 1."
        return
    fi

    echo "URL 1 failed. Trying URL 2..."
    if download_file "$URL_2"; then
        echo "Downloaded successfully from URL 2."
        return
    fi

    echo "URL 2 failed."
    read -rp "Enter custom download URL: " CUSTOM_URL

    if [ -z "$CUSTOM_URL" ]; then
        echo "No custom URL provided."
        exit 1
    fi

    echo "Downloading from custom URL..."
    if download_file "$CUSTOM_URL"; then
        echo "Downloaded successfully from custom URL."
        return
    fi

    echo "Failed to download backhaul_premium.zip."
    exit 1
}

create_bh_tui_command() {
    local script_path="$1"

    echo "Creating global bh-tui command..."

    run_privileged tee "$BIN_PATH" >/dev/null <<EOF
#!/usr/bin/env bash

set -e

CORE_DIR="$CORE_DIR"
SCRIPT_PATH="$script_path"
BIN_PATH="$BIN_PATH"

run_privileged() {
    if [ "\$(id -u)" -eq 0 ]; then
        "\$@"
    else
        sudo "\$@"
    fi
}

uninstall_backhaul() {
    echo "This will remove:"
    echo "  - \$CORE_DIR"
    echo "  - \$BIN_PATH"
    echo
    read -rp "Continue uninstall? [y/N]: " answer

    case "\$answer" in
        y|Y|yes|YES)
            run_privileged rm -rf "\$CORE_DIR"
            run_privileged rm -f "\$BIN_PATH"
            echo "Backhaul TUI has been uninstalled."
            ;;
        *)
            echo "Uninstall cancelled."
            ;;
    esac
}

if [ "\${1:-}" = "uninstall" ] || [ "\${1:-}" = "--uninstall" ]; then
    uninstall_backhaul
    exit 0
fi

if [ ! -x "\$SCRIPT_PATH" ]; then
    echo "Could not find executable backhaul.sh at:"
    echo "  \$SCRIPT_PATH"
    echo
    echo "Try reinstalling, or run:"
    echo "  bh-tui uninstall"
    exit 1
fi

cd "\$(dirname "\$SCRIPT_PATH")"
exec "\$SCRIPT_PATH" "\$@"
EOF

    run_privileged chmod +x "$BIN_PATH"

    echo "bh-tui command installed successfully."
}

extract_and_install() {
    local tmp_dir
    local found_package
    local script_path

    tmp_dir="$(mktemp -d)"

    echo "Extracting backhaul_premium.zip..."
    unzip -q "$ZIP_FILE" -d "$tmp_dir"

    mkdir -p "$CORE_DIR"

    found_package="$(find "$tmp_dir" -name "$PACKAGE_NAME" -print -quit)"

    if [ -z "$found_package" ]; then
        echo "Could not find $PACKAGE_NAME inside extracted zip."
        rm -rf "$tmp_dir"
        exit 1
    fi

    echo "Moving $PACKAGE_NAME to $CORE_DIR/"
    rm -rf "$CORE_DIR/$PACKAGE_NAME"
    mv "$found_package" "$CORE_DIR/"

    script_path="$(find "$CORE_DIR" -type f -name "backhaul.sh" -print -quit)"

    if [ -z "$script_path" ]; then
        echo "Could not find backhaul.sh inside $CORE_DIR."
        rm -rf "$tmp_dir"
        exit 1
    fi

    echo "Making backhaul.sh executable..."
    chmod +x "$script_path"

    create_bh_tui_command "$script_path"

    rm -rf "$tmp_dir"

    echo
    echo "Installation complete."
    echo "Run Backhaul TUI from anywhere using:"
    echo "  bh-tui"
    echo
    echo "Uninstall using:"
    echo "  bh-tui uninstall"
}

uninstall_backhaul() {
    echo "This will remove:"
    echo "  - $CORE_DIR"
    echo "  - $BIN_PATH"
    echo
    read -rp "Continue uninstall? [y/N]: " answer

    case "$answer" in
        y|Y|yes|YES)
            run_privileged rm -rf "$CORE_DIR"
            run_privileged rm -f "$BIN_PATH"
            echo "Backhaul TUI has been uninstalled."
            ;;
        *)
            echo "Uninstall cancelled."
            ;;
    esac
}

case "${1:-install}" in
    install)
        install_unzip
        download_zip
        extract_and_install
        ;;
    uninstall|--uninstall)
        uninstall_backhaul
        ;;
    *)
        echo "Usage:"
        echo "  $0 install"
        echo "  $0 uninstall"
        echo "  bh-tui"
        echo "  bh-tui uninstall"
        exit 1
        ;;
esac
