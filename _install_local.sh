#!/bin/bash
set -eo pipefail # Exit on error, treat unset variables as an error (implicitly), and propagate pipeline errors

# --- Configuration ---
: "${PKGBUILD_SUBDIR:=package}"                # Subdirectory within the repo containing the PKGBUILD
: "${ANTIGRAVITY_PKG_NAME:=google-antigravity-bin}"

# --- Helper Functions ---
log() {
    echo "[INFO] $(date +'%T') - $1"
}

error_exit() {
    echo "[ERROR] $(date +'%T') - $1" >&2
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "Required command '$1' not found. Please install it."
}

get_installed_version() {
    local pkg_name="$1"
    if pacman -Q "$pkg_name" &>/dev/null; then
        pacman -Q "$pkg_name" | awk '{print $2}'
    else
        echo "" # Not installed
    fi
}

get_pkgbuild_version() {
    local pkgbuild_file="$1"
    if [ ! -f "$pkgbuild_file" ]; then
        error_exit "PKGBUILD file not found at $pkgbuild_file"
    fi
    ( # Source PKGBUILD in a subshell to avoid polluting current environment
        # shellcheck source=/dev/null
        source "$pkgbuild_file"
        if [ -z "${pkgver:-}" ] || [ -z "${pkgrel:-}" ]; then
            error_exit "pkgver or pkgrel not defined in $pkgbuild_file"
        fi
        echo "${pkgver}-${pkgrel}"
    )
}

# --- Main Script Logic ---
main() {
    # --- Pre-flight Checks ---
    log "Performing pre-flight checks..."
    check_command "pacman"
    check_command "makepkg"

    # --- Script Location ---
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
    BUILD_DIR="$SCRIPT_DIR/$PKGBUILD_SUBDIR"
    
    log "Running in LOCAL mode."
    log "Script directory: $SCRIPT_DIR"
    log "Build directory: $BUILD_DIR"

    # --- Cleanup and Signal Handling ---
    cleanup_action() {
        # No temp dir cleanup needed in local only mode usually, unless we created one.
        # Leaving generic logic or empty.
        :
    }

    trap 'cleanup_action "Normal Exit"' EXIT
    trap 'cleanup_action "Script Interrupted"; exit 130' SIGINT
    trap 'cleanup_action "Script Terminated"; exit 143' SIGTERM

    # --- Installation Target ---
    TARGET_PKG_NAME="$ANTIGRAVITY_PKG_NAME"
    log "Selected package: $TARGET_PKG_NAME"

    # --- Validate Build Directory ---
    if [ ! -d "$BUILD_DIR" ]; then
         error_exit "Build directory '$BUILD_DIR' does not exist."
    fi

    cd "$BUILD_DIR" || error_exit "Failed to change to build directory '$BUILD_DIR'."
    if [ ! -f PKGBUILD ]; then
        error_exit "PKGBUILD not found in $(pwd)."
    fi
    log "Using PKGBUILD from $(pwd)"

    # --- Check Version and User Confirmation ---
    PKGBUILD_VERSION=$(get_pkgbuild_version "PKGBUILD")
    log "Version available in PKGBUILD for $TARGET_PKG_NAME: $PKGBUILD_VERSION"
    INSTALLED_VERSION=$(get_installed_version "$TARGET_PKG_NAME")
    PROCEED_WITH_BUILD=false

    if [ -n "$INSTALLED_VERSION" ]; then
        log "Currently installed version of $TARGET_PKG_NAME: $INSTALLED_VERSION"
        if [ "$INSTALLED_VERSION" == "$PKGBUILD_VERSION" ]; then
            printf "%s version %s is already installed. Reinstall anyway? (y/N): " "$TARGET_PKG_NAME" "$PKGBUILD_VERSION" >&2
            read -r reinstall_choice </dev/tty
            if [[ "$reinstall_choice" =~ ^[Yy]$ ]]; then PROCEED_WITH_BUILD=true; fi
        else
            log "Installed version ($INSTALLED_VERSION) differs from PKGBUILD version ($PKGBUILD_VERSION)."
            printf "Build and install version %s? (Y/n): " "$PKGBUILD_VERSION" >&2
            read -r upgrade_choice </dev/tty
            if [[ ! "$upgrade_choice" =~ ^[Nn]$ ]]; then PROCEED_WITH_BUILD=true; fi
        fi
    else
        log "$TARGET_PKG_NAME is not currently installed."
        printf "Install %s version %s? (Y/n): " "$TARGET_PKG_NAME" "$PKGBUILD_VERSION" >&2
        read -r install_new_choice </dev/tty
        if [[ ! "$install_new_choice" =~ ^[Nn]$ ]]; then PROCEED_WITH_BUILD=true; fi
    fi

    if [ "$PROCEED_WITH_BUILD" = false ]; then
        log "Exiting at user request."
        exit 0
    fi

    # --- Build and Install Package ---
    log "Building $TARGET_PKG_NAME version $PKGBUILD_VERSION..."
    log "This may require sudo password to install dependencies."
    
    if ! makepkg -si --noconfirm --needed </dev/tty; then
        error_exit "Failed to build/install $TARGET_PKG_NAME. Check output for errors."
    fi

    log "$TARGET_PKG_NAME version $PKGBUILD_VERSION installed successfully!"
    log "Script finished."
}

# Run the main function
main
