#!/bin/bash
# setup.sh - Automated Yocto setup for ROS 2 Humble on ICICLE Kit
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

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} ROS 2 Humble for ICICLE Kit Setup${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Work directory: ${YELLOW}${WORK_DIR}${NC}"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in git python3 gcc; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        echo "Please install build dependencies first:"
        echo "  sudo apt install gawk wget git diffstat unzip texinfo gcc build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 python3-subunit zstd liblz4-tool file locales"
        exit 1
    fi
done
echo -e "${GREEN}Prerequisites OK${NC}"
echo ""

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clone layers
echo -e "${YELLOW}Cloning Yocto layers (Scarthgap)...${NC}"
echo "This may take 10-20 minutes depending on your internet connection."
echo ""

if [ ! -d "openembedded-core" ]; then
    echo "Cloning openembedded-core..."
    git clone -b scarthgap https://git.yoctoproject.org/git/poky openembedded-core
else
    echo "openembedded-core already exists, skipping..."
fi

if [ ! -d "meta-openembedded" ]; then
    echo "Cloning meta-openembedded..."
    git clone -b scarthgap https://github.com/openembedded/meta-openembedded
else
    echo "meta-openembedded already exists, skipping..."
fi

if [ ! -d "meta-polarfire-soc-yocto-bsp" ]; then
    echo "Cloning meta-polarfire-soc-yocto-bsp..."
    git clone -b scarthgap https://github.com/polarfire-soc/meta-polarfire-soc-yocto-bsp
else
    echo "meta-polarfire-soc-yocto-bsp already exists, skipping..."
fi

if [ ! -d "meta-ros" ]; then
    echo "Cloning meta-ros..."
    git clone -b scarthgap https://github.com/ros/meta-ros
else
    echo "meta-ros already exists, skipping..."
fi

echo ""
echo -e "${GREEN}All layers cloned successfully!${NC}"
echo ""

# Copy custom layer
echo -e "${YELLOW}Copying custom layer...${NC}"
if [ -d "$SCRIPT_DIR/meta-custom" ]; then
    cp -r "$SCRIPT_DIR/meta-custom" "$WORK_DIR/"
    echo -e "${GREEN}meta-custom layer copied${NC}"
else
    echo -e "${RED}Warning: meta-custom not found in $SCRIPT_DIR${NC}"
fi
echo ""

# Initialize build environment
echo -e "${YELLOW}Initializing build environment...${NC}"
source openembedded-core/oe-init-build-env build

# Create bblayers.conf
echo -e "${YELLOW}Configuring bblayers.conf...${NC}"
cat > conf/bblayers.conf << 'EOF'
# LAYER_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
LCONF_VERSION = "7"

BBPATH = "${TOPDIR}"
BBFILES ?= ""

BSPDIR := "${TOPDIR}/.."

BBLAYERS ?= " \
  ${BSPDIR}/openembedded-core/meta \
  ${BSPDIR}/meta-openembedded/meta-oe \
  ${BSPDIR}/meta-openembedded/meta-python \
  ${BSPDIR}/meta-openembedded/meta-networking \
  ${BSPDIR}/meta-polarfire-soc-yocto-bsp/meta-polarfire-soc-bsp \
  ${BSPDIR}/meta-ros/meta-ros-common \
  ${BSPDIR}/meta-ros/meta-ros2 \
  ${BSPDIR}/meta-ros/meta-ros2-humble \
  ${BSPDIR}/meta-custom \
"
EOF

# Append custom settings to local.conf
echo -e "${YELLOW}Configuring local.conf...${NC}"
cat >> conf/local.conf << 'EOF'

#
# PolarFire SoC Icicle Kit Configuration
#
MACHINE = "icicle-kit-es"

#
# Parallel Build Configuration (adjust to your CPU cores)
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

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN} Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "To build the image:"
echo ""
echo -e "  ${YELLOW}cd $WORK_DIR${NC}"
echo -e "  ${YELLOW}source openembedded-core/oe-init-build-env build${NC}"
echo -e "  ${YELLOW}bitbake drone-stage1${NC}"
echo ""
echo "Build time: 4-8 hours on first build"
echo ""
echo "Output image location:"
echo "  build/tmp-glibc/deploy/images/icicle-kit-es/drone-stage1-icicle-kit-es.rootfs.wic.gz"
echo ""
