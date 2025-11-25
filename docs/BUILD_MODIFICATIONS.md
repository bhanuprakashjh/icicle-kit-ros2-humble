# Build Modifications & Configuration Details

This document describes all modifications and configurations made to build ROS 2 Humble on the Microchip PolarFire SoC ICICLE Kit.

## Overview

The build uses **Yocto Scarthgap LTS** with minimal modifications - only a custom layer was created. No upstream layers were patched or modified.

---

## 1. Layer Stack

| Layer | Source | Branch | Purpose |
|-------|--------|--------|---------|
| openembedded-core/meta | git.yoctoproject.org/poky | scarthgap | Core Yocto recipes |
| meta-openembedded/meta-oe | github.com/openembedded | scarthgap | Extended OE recipes |
| meta-openembedded/meta-python | github.com/openembedded | scarthgap | Python packages |
| meta-openembedded/meta-networking | github.com/openembedded | scarthgap | Network packages |
| meta-polarfire-soc-bsp | github.com/polarfire-soc | scarthgap | ICICLE Kit BSP |
| meta-ros/meta-ros-common | github.com/ros/meta-ros | scarthgap | ROS common infrastructure |
| meta-ros/meta-ros2 | github.com/ros/meta-ros | scarthgap | ROS 2 framework |
| meta-ros/meta-ros2-humble | github.com/ros/meta-ros | scarthgap | ROS 2 Humble recipes |
| **meta-custom** | This repo | - | Custom image recipe |

---

## 2. local.conf Modifications

The following lines were added to `build/conf/local.conf`:

```bitbake
#
# PolarFire SoC Icicle Kit Configuration
#
MACHINE = "icicle-kit-es"

#
# Parallel Build Configuration (8 cores)
#
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

#
# Shared Download and State Cache
# These directories are placed outside the build directory for reuse
#
DL_DIR = "${TOPDIR}/../downloads"
SSTATE_DIR = "${TOPDIR}/../sstate-cache"

#
# Package Management - enables opkg on target for runtime package installation
#
EXTRA_IMAGE_FEATURES += "package-management"

#
# Development & Debugging Features
# - tools-debug: gdb, strace
# - tools-sdk: gcc, g++, make on target
# - dev-pkgs: development headers
#
IMAGE_FEATURES += "tools-debug tools-sdk dev-pkgs"

#
# Disable SPDX creation (workaround for license metadata issues)
# This was needed to avoid build failures related to SPDX generation
#
INHERIT:remove = "create-spdx"
```

### Explanation of Each Setting

| Setting | Value | Rationale |
|---------|-------|-----------|
| `MACHINE` | `icicle-kit-es` | Target hardware: PolarFire SoC ICICLE Kit Engineering Sample |
| `BB_NUMBER_THREADS` | `8` | Parallel BitBake tasks (adjust to CPU cores) |
| `PARALLEL_MAKE` | `-j 8` | Parallel make jobs (adjust to CPU cores) |
| `DL_DIR` | `${TOPDIR}/../downloads` | Shared downloads directory for faster rebuilds |
| `SSTATE_DIR` | `${TOPDIR}/../sstate-cache` | Shared state cache for faster rebuilds |
| `package-management` | Enabled | Allows `opkg install` on running system |
| `tools-debug` | Enabled | Includes gdb, strace for debugging |
| `tools-sdk` | Enabled | Includes native gcc/g++ on target |
| `dev-pkgs` | Enabled | Includes -dev packages (headers) |
| `INHERIT:remove = "create-spdx"` | Disabled | Workaround for SPDX license metadata build failures |

---

## 3. bblayers.conf Configuration

```bitbake
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
```

### Layer Order Significance

1. **Core layers first** - openembedded-core provides base recipes
2. **meta-openembedded extensions** - Additional packages not in core
3. **BSP layer** - Hardware-specific kernel, bootloader, device trees
4. **ROS layers in order** - common → ros2 → ros2-humble (dependencies)
5. **meta-custom last** - Highest priority, can override anything

---

## 4. Custom Layer: meta-custom

### Layer Configuration (`meta-custom/conf/layer.conf`)

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "meta-custom"
BBFILE_PATTERN_meta-custom = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-custom = "10"

LAYERDEPENDS_meta-custom = "core"
LAYERSERIES_COMPAT_meta-custom = "scarthgap"
```

| Setting | Value | Purpose |
|---------|-------|---------|
| `BBFILE_PRIORITY` | `10` | Higher than default (6), ensures our recipes take precedence |
| `LAYERSERIES_COMPAT` | `scarthgap` | Compatible with Yocto Scarthgap release |

### Image Recipe (`meta-custom/recipes-core/images/drone-stage1.bb`)

```bitbake
SUMMARY = "ROS2 Humble drone mission computer for PolarFire SoC Icicle Kit"
DESCRIPTION = "Custom Linux image with ROS2 Humble, MAVROS, WiFi support, and development tools"

LICENSE = "MIT"

inherit core-image

# ROS2 Humble Packages
# CRITICAL: Use bare recipe names (ros-base NOT ros-humble-ros-base)
IMAGE_INSTALL:append = " \
    ros-base \
    mavros \
    mavros-extras \
"

# Python3 Packages
IMAGE_INSTALL:append = " \
    python3-pip \
    python3-numpy \
    python3-pyserial \
"

# WiFi & Network Support
IMAGE_INSTALL:append = " \
    iw \
    wpa-supplicant \
    hostapd \
    bluez5 \
    can-utils \
    ethtool \
    iperf3 \
    tcpdump \
"

# Development Tools
IMAGE_INSTALL:append = " \
    htop \
    screen \
    tmux \
    minicom \
    nano \
    vim \
    git \
    cmake \
    gcc \
    g++ \
    make \
    gdb \
    strace \
    rsync \
    wget \
    curl \
"

# System Utilities
IMAGE_INSTALL:append = " \
    i2c-tools \
    usbutils \
    pciutils \
    lsof \
"

# Image Features
IMAGE_FEATURES += "ssh-server-openssh"
IMAGE_FEATURES += "tools-debug"
IMAGE_FEATURES += "package-management"

# Extra rootfs space (2GB)
IMAGE_ROOTFS_EXTRA_SPACE = "2097152"

# Serial console
SERIAL_CONSOLES = "115200;ttyS0"
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `ros-base` (not `ros-humble-ros-base`) | meta-ros uses bare recipe names; prefix is automatic |
| `mavros` + `mavros-extras` | Required for drone autopilot integration (PX4/ArduPilot) |
| `IMAGE_ROOTFS_EXTRA_SPACE = "2097152"` | 2GB extra space for ROS workspaces, bag files, logs |
| `SERIAL_CONSOLES = "115200;ttyS0"` | Matches ICICLE Kit UART0 default configuration |
| Native toolchain on target | Enables on-device compilation of ROS packages |

---

## 5. Machine Configuration (from BSP layer)

The `icicle-kit-es` machine is defined in `meta-polarfire-soc-bsp`. Key settings:

```bitbake
# Machine type
MACHINE_TYPE = "smp"                    # Symmetric Multi-Processing

# Device tree
RISCV_SBI_FDT = "mpfs-icicle-kit.dtb"
KERNEL_DEVICETREE = "microchip/${RISCV_SBI_FDT}"

# U-Boot configuration
UBOOT_CONFIG = "mpfs_icicle"
HSS_PAYLOAD = "uboot"

# Boot files
IMAGE_BOOT_FILES = "fitImage boot.scr uboot.env"

# Memory addresses
UBOOT_ENTRYPOINT = "0x80200000"
UBOOT_DTB_LOADADDRESS = "0x8a000000"

# Kernel
PREFERRED_PROVIDER_virtual/kernel = "mpfs-linux"
KERNEL_IMAGETYPE = "fitImage"
KBUILD_DEFCONFIG = "mpfs_defconfig"

# Output formats
IMAGE_FSTYPES += "wic wic.gz wic.bmap ext4"
```

---

## 6. Disk Partition Layout

Defined in `meta-polarfire-soc-bsp/wic/mpfs-rootfs.wks`:

```
part /boot    --source bootimg-partition --fstype=vfat --label boot --fixed-size 65536K
part /hssboot --source rawcopy --sourceparams="file=payload.bin" --fixed-size 8192K
part /        --source rootfs --fstype=ext4 --label root

bootloader --ptable gpt
```

| Partition | Size | Filesystem | Contents |
|-----------|------|------------|----------|
| /boot | 64 MB | vfat | fitImage, boot.scr, uboot.env |
| /hssboot | 8 MB | raw | HSS payload (U-Boot) |
| / | remaining | ext4 | Root filesystem |

---

## 7. Build Artifacts

After successful build, outputs are in:
```
build/tmp-glibc/deploy/images/icicle-kit-es/
```

| File | Size | Purpose |
|------|------|---------|
| `drone-stage1-icicle-kit-es.rootfs.wic.gz` | ~261 MB | Compressed flashable image |
| `drone-stage1-icicle-kit-es.rootfs.wic` | ~1.2 GB | Uncompressed disk image |
| `drone-stage1-icicle-kit-es.rootfs.ext4` | ~3.1 GB | Raw root filesystem |
| `fitImage` | ~5.9 MB | Kernel + DTB FIT image |
| `u-boot.bin` | ~745 KB | U-Boot bootloader |
| `payload.bin` | ~747 KB | HSS payload |
| `drone-stage1-icicle-kit-es.rootfs.manifest` | ~50 KB | Package list |

---

## 8. What Was NOT Modified

The following upstream layers were used **unmodified**:

- ✅ openembedded-core
- ✅ meta-openembedded
- ✅ meta-polarfire-soc-yocto-bsp
- ✅ meta-ros (all sublayers)

No patches, bbappends, or modifications were required to upstream layers.

---

## 9. Known Issues & Workarounds

### Issue: SPDX License Metadata Generation Failures

**Symptom:** Build fails during license metadata generation

**Workaround:** Added to local.conf:
```bitbake
INHERIT:remove = "create-spdx"
```

### Issue: ROS Package Names

**Symptom:** `ros-humble-ros-base` recipe not found

**Solution:** Use bare recipe names without distro prefix:
- ❌ `ros-humble-ros-base`
- ✅ `ros-base`

The meta-ros layer handles the distro prefix automatically.

---

## 10. Build Statistics

| Metric | Value |
|--------|-------|
| Total packages | 1,299 |
| ROS 2 packages | 165+ |
| Build time (first) | 4-8 hours |
| Build time (incremental) | 10-30 minutes |
| Disk space required | ~50 GB |
| sstate-cache size | ~6.2 GB |
| downloads size | ~9.9 GB |
| Final image (compressed) | 261 MB |

---

## 11. Reproducing the Build

```bash
# 1. Clone all layers
git clone -b scarthgap https://git.yoctoproject.org/poky openembedded-core
git clone -b scarthgap https://github.com/openembedded/meta-openembedded
git clone -b scarthgap https://github.com/polarfire-soc/meta-polarfire-soc-yocto-bsp
git clone -b scarthgap https://github.com/ros/meta-ros
git clone https://github.com/bhanuprakashjh/icicle-kit-ros2-humble

# 2. Copy custom layer
cp -r icicle-kit-ros2-humble/meta-custom .

# 3. Initialize build
source openembedded-core/oe-init-build-env build

# 4. Copy configurations
cp ../icicle-kit-ros2-humble/conf-templates/bblayers.conf.sample conf/bblayers.conf
cat ../icicle-kit-ros2-humble/conf-templates/local.conf.sample >> conf/local.conf

# 5. Adjust BSPDIR path in bblayers.conf if needed

# 6. Build
bitbake drone-stage1
```

---

## References

- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [meta-ros Wiki](https://github.com/ros/meta-ros/wiki)
- [PolarFire SoC Documentation](https://github.com/polarfire-soc)
- [ROS 2 Humble Documentation](https://docs.ros.org/en/humble/)
