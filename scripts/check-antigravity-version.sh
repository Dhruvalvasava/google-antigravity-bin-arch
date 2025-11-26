#!/bin/bash

set -x  # Enable debug output

# Set up temporary directory
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Download and set up the repository key
curl -fsSL "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" -o "$TEMP_DIR/antigravity.gpg"

# Add the key to apt's trusted keys
cat "$TEMP_DIR/antigravity.gpg" | gpg --batch --yes --dearmor -o "/usr/share/keyrings/antigravity-archive-keyring.gpg"

# Create sources list
# Note: antigravity-debian is the distribution name found in docs
echo "deb [signed-by=/usr/share/keyrings/antigravity-archive-keyring.gpg arch=amd64] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null

# Update package lists for the repository
apt-get update > /dev/null 2>&1

# Search for the package name if not sure (uncomment for debugging)
# apt-cache search antigravity

# Get package version
# Assuming package name is 'antigravity' or 'google-antigravity'. Trying 'antigravity' first based on search results.
PACKAGE_NAME="antigravity"
VERSION=$(apt-cache madison "$PACKAGE_NAME" | head -n1 | awk '{ print $3 }' | cut -d'-' -f1)

# If version is empty, try 'google-antigravity'
if [ -z "$VERSION" ]; then
    PACKAGE_NAME="google-antigravity"
    VERSION=$(apt-cache madison "$PACKAGE_NAME" | head -n1 | awk '{ print $3 }' | cut -d'-' -f1)
fi

if [ -n "$VERSION" ]; then
    # Construct DEB URL
    # We can use 'apt-get download --print-uris' to get the URL
    DEB_URL=$(apt-get download --print-uris "$PACKAGE_NAME" | awk '{print $1}' | tr -d "'")
    
    if [ -n "$DEB_URL" ]; then
        # Download the DEB file to calculate SHA256 sum
        DEB_FILE="$TEMP_DIR/${PACKAGE_NAME}_${VERSION}.deb"
        if curl --silent --output "$DEB_FILE" "$DEB_URL"; then
            # Calculate SHA256 sum
            SHA256SUM=$(sha256sum "$DEB_FILE" | awk '{print $1}')
            # Output version, SHA256 sum, and URL
            printf "%s %s %s" "$VERSION" "$SHA256SUM" "$DEB_URL"
            exit 0
        else
            echo "Failed to download DEB package from $DEB_URL" >&2
            exit 1
        fi
    else
        echo "Could not determine DEB URL for $PACKAGE_NAME" >&2
        exit 1
    fi
else
    echo "Failed to get version. Package not found?" >&2
    apt-cache search antigravity >&2
    exit 1
fi
