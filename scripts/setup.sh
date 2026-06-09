#!/bin/bash
# setup.sh - Automated Yocto setup for ROS 2 Humble on ICICLE Kit
#
# Uses the repo tool with a local manifest to pull all layers (Microchip BSP,
# meta-ros, and this repo) into the workspace in a single repo sync, then
# uses bitbake-layers to register the custom layers.
#
# Usage: ./setup.sh [work_directory]
# Example: ./setup.sh ~/yocto-icicle

# Microchip manifest tag — update this to move to a newer BSP release
MCHP_TAG="refs/tags/linux4microchip-2026.04"

# GitHub details for this repo — update if you fork
ICICLE_ROS2_REMOTE="https://github.com/cybdarren/icicle-kit-ros2-humble"
ICICLE_ROS2_REVISION="main"

WORK_DIR=${1:-$(pwd)/yocto-icicle}

echo "Installing ROS 2 Humble on ICICLE Kit"
echo "======================================"

# ---------------------------------------------------------------------------
# Step 1: Install required packages
# ---------------------------------------------------------------------------
echo "Installing required packages"
echo "============================"
sudo apt-get update
sudo apt-get install -y gawk wget git git-lfs diffstat unzip texinfo \
    gcc-multilib build-essential chrpath socat cpio python3 python3-pip \
    python3-pexpect xz-utils debianutils iputils-ping python3-git \
    python3-jinja2 python3-subunit zstd liblz4-tool file locales \
    libacl1 libncurses-dev lz4 repo

sudo locale-gen en_US.UTF-8

# ---------------------------------------------------------------------------
# Step 2: Create work directory and repo init from Microchip manifest
# ---------------------------------------------------------------------------
echo "Creating work directory: $WORK_DIR"
echo "==================================="
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Initialising repo manifest (answer N to colour prompt if asked)"
echo "==============================================================="
repo init \
    -u https://github.com/linux4microchip/meta-mchp-manifest.git \
    -b "${MCHP_TAG}" \
    -m polarfire-soc/default.xml

# ---------------------------------------------------------------------------
# Step 3: Write local manifest to add meta-ros and this repo
# ---------------------------------------------------------------------------
echo "Writing local manifest file"
echo "==========================="
mkdir -p .repo/local_manifests

cat <<EOF > ".repo/local_manifests/icicle-kit-ros2-humble.xml"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="github"
            fetch="https://github.com/" />

    <!-- ROS 2 Humble layer -->
    <project name="ros/meta-ros"
             path="meta-ros"
             remote="github"
             revision="scarthgap" />

    <!-- Custom drone/ROS 2 layer and setup scripts -->
    <project name="cybdarren/icicle-kit-ros2-humble"
             path="icicle-kit-ros2-humble"
             remote="github"
             revision="${ICICLE_ROS2_REVISION}" />
</manifest>
EOF
echo "Local manifest created"

# ---------------------------------------------------------------------------
# Step 4: Sync all repos
# ---------------------------------------------------------------------------
echo "Syncing repos (this may take 10-20 minutes)"
echo "============================================"
repo sync
echo "All repos synced"

# ---------------------------------------------------------------------------
# Step 5: Initialise build environment from Microchip PolarFire SoC template
# ---------------------------------------------------------------------------
echo "Initialising build environment"
echo "==============================="
export TEMPLATECONF="${WORK_DIR}/meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-bsp/conf/templates/default"
source openembedded-core/oe-init-build-env build

# Shell is now in $WORK_DIR/build/

# ---------------------------------------------------------------------------
# Step 6: Register ROS 2 and custom layers via bitbake-layers
# ---------------------------------------------------------------------------
echo "Adding meta-ros layers"
echo "======================"
bitbake-layers add-layer ../meta-ros/meta-ros-common
bitbake-layers add-layer ../meta-ros/meta-ros2
bitbake-layers add-layer ../meta-ros/meta-ros2-humble

echo "Adding meta-custom layer"
echo "========================"
bitbake-layers add-layer ../icicle-kit-ros2-humble/meta-custom

# ---------------------------------------------------------------------------
# Step 7: Append project-specific settings to local.conf
# ---------------------------------------------------------------------------
echo "Configuring local.conf"
echo "======================"
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

echo ""
echo "=========================="
echo "=         DONE           ="
echo "=========================="
echo ""
echo "To build the image, open a new terminal and run:"
echo ""
echo "  cd ${WORK_DIR}"
echo "  source openembedded-core/oe-init-build-env build"
echo "  bitbake drone-stage1"
echo ""
echo "Build time: 4-8 hours on first build"
echo ""
echo "Output image:"
echo "  build/tmp-glibc/deploy/images/mpfs-icicle-kit/drone-stage1-mpfs-icicle-kit.rootfs.wic.gz"
echo ""
