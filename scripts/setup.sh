#!/bin/bash
# setup.sh - Automated Yocto setup for ROS 2 Humble on ICICLE Kit
#
# Uses the repo tool to download the Microchip BSP manifest, then adds
# meta-ros and meta-custom on top.
#
# Usage: ./setup.sh [work_directory]
# Example: ./setup.sh ~/yocto-icicle

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

WORK_DIR=${1:-$(pwd)/yocto-icicle}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Microchip manifest tag — update this to move to a newer release
MCHP_TAG="refs/tags/linux4microchip-2026.04"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} ROS 2 Humble for ICICLE Kit Setup${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Work directory: ${YELLOW}${WORK_DIR}${NC}"
echo -e "Microchip release: ${YELLOW}${MCHP_TAG}${NC}"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in git python3 gcc repo; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        if [ "$cmd" = "repo" ]; then
            echo "Install the repo tool:"
            echo "  mkdir -p ~/.local/bin"
            echo "  curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo"
            echo "  chmod a+x ~/.local/bin/repo"
            echo "  export PATH=\$HOME/.local/bin:\$PATH"
        else
            echo "Install build dependencies:"
            echo "  sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \\"
            echo "    chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \\"
            echo "    iputils-ping python3-git python3-jinja2 python3-subunit zstd liblz4-tool \\"
            echo "    file locales libacl1 libncurses-dev"
        fi
        exit 1
    fi
done
echo -e "${GREEN}Prerequisites OK${NC}"
echo ""

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# Step 1: Download Microchip BSP via repo manifest
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Initializing Microchip BSP manifest...${NC}"
echo "This downloads: openembedded-core, bitbake, meta-openembedded, meta-mchp"
echo ""

if [ ! -d ".repo" ]; then
    repo init \
        -u https://github.com/linux4microchip/meta-mchp-manifest.git \
        -b "${MCHP_TAG}" \
        -m polarfire-soc/default.xml
else
    echo ".repo already initialised, skipping repo init..."
fi

echo -e "${YELLOW}Syncing repos (this may take 10-20 minutes)...${NC}"
repo sync
echo -e "${GREEN}BSP repos synced successfully!${NC}"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Clone meta-ros (not included in the Microchip manifest)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Cloning meta-ros...${NC}"
if [ ! -d "meta-ros" ]; then
    git clone -b scarthgap https://github.com/ros/meta-ros
    echo -e "${GREEN}meta-ros cloned${NC}"
else
    echo "meta-ros already exists, skipping..."
fi
echo ""

# ---------------------------------------------------------------------------
# Step 3: Copy custom layer from this repo
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Copying meta-custom layer...${NC}"
if [ -d "$SCRIPT_DIR/meta-custom" ]; then
    cp -r "$SCRIPT_DIR/meta-custom" "$WORK_DIR/"
    echo -e "${GREEN}meta-custom copied${NC}"
else
    echo -e "${RED}Warning: meta-custom not found in $SCRIPT_DIR${NC}"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 4: Initialize build environment from Microchip template
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Initializing build environment...${NC}"
TEMPLATECONF="${WORK_DIR}/meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-bsp/conf/templates/default"

if [ ! -d "$TEMPLATECONF" ]; then
    echo -e "${RED}Error: Microchip template not found at $TEMPLATECONF${NC}"
    echo "Check that repo sync completed successfully."
    exit 1
fi

export TEMPLATECONF
source openembedded-core/oe-init-build-env build

# After sourcing, the shell is now in $WORK_DIR/build/

# ---------------------------------------------------------------------------
# Step 5: Add ROS 2 and custom layers to bblayers.conf
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Adding ROS 2 and custom layers to bblayers.conf...${NC}"
cat >> conf/bblayers.conf << EOF

# ROS 2 Humble layers
BBLAYERS += " \\
  ${WORK_DIR}/meta-ros/meta-ros-common \\
  ${WORK_DIR}/meta-ros/meta-ros2 \\
  ${WORK_DIR}/meta-ros/meta-ros2-humble \\
  ${WORK_DIR}/meta-custom \\
"
EOF
echo -e "${GREEN}bblayers.conf updated${NC}"

# ---------------------------------------------------------------------------
# Step 6: Append project-specific settings to local.conf
# ---------------------------------------------------------------------------
echo -e "${YELLOW}Configuring local.conf...${NC}"
cat >> conf/local.conf << 'EOF'

#
# PolarFire SoC Icicle Kit — project overrides
#
MACHINE = "mpfs-icicle-kit"

#
# Parallel Build Configuration (adjust to your CPU core count)
#
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

#
# Shared Download and State Cache
#
DL_DIR = "${TOPDIR}/../downloads"
SSTATE_DIR = "${TOPDIR}/../sstate-cache"

#
# Package Management
#
EXTRA_IMAGE_FEATURES += "package-management"

#
# Development & Debugging
#
IMAGE_FEATURES += "tools-debug tools-sdk dev-pkgs"

#
# Disable SPDX creation (workaround for license metadata issues)
#
INHERIT:remove = "create-spdx"
EOF

echo -e "${GREEN}local.conf updated${NC}"
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "To build the image, open a new terminal and run:"
echo ""
echo -e "  ${YELLOW}cd ${WORK_DIR}${NC}"
echo -e "  ${YELLOW}source openembedded-core/oe-init-build-env build${NC}"
echo -e "  ${YELLOW}bitbake drone-stage1${NC}"
echo ""
echo "Build time: 4-8 hours on first build"
echo ""
echo "Output image location:"
echo "  build/tmp-glibc/deploy/images/mpfs-icicle-kit/drone-stage1-mpfs-icicle-kit.rootfs.wic.gz"
echo ""
