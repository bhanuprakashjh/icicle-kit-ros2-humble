# ROS 2 Humble on Microchip PolarFire SoC ICICLE Kit

A complete Yocto-based Linux distribution with ROS 2 Humble for the Microchip PolarFire SoC ICICLE Kit (RISC-V 64-bit).

## Features

- **ROS 2 Humble LTS** - Full ROS 2 base system with CLI tools
- **MAVROS** - MAVLink bridge for PX4/ArduPilot integration
- **Python 3.12** - With numpy, pyserial, and pip
- **WiFi Support** - wpa_supplicant, hostapd, iw
- **Development Tools** - gcc, g++, cmake, gdb, git, vim
- **CAN Bus** - can-utils for vehicle/autopilot communication
- **SSH Server** - Remote access enabled by default

## Hardware Requirements

- Microchip PolarFire SoC ICICLE Kit (MPFS-ICICLE-KIT-ES)
- microSD card (16GB+ recommended)
- USB-UART cable for serial console
- (Optional) WiFi USB adapter

## Build Host Requirements

- Ubuntu 22.04 LTS or compatible Linux distribution
- 50GB+ free disk space
- 8GB+ RAM (16GB recommended)
- Internet connection

### Install Dependencies (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
    iputils-ping python3-git python3-jinja2 python3-subunit zstd liblz4-tool file \
    locales libacl1 libncurses-dev
sudo locale-gen en_US.UTF-8
```

## Quick Start

### Option 1: Automated Setup

```bash
git clone https://github.com/bhanuprakashjh/icicle-kit-ros2-humble.git
cd icicle-kit-ros2-humble
./scripts/setup.sh ~/yocto-icicle
cd ~/yocto-icicle
source openembedded-core/oe-init-build-env build
bitbake drone-stage1
```

### Option 2: Manual Setup

#### 1. Clone Yocto Layers

```bash
mkdir -p ~/yocto-icicle && cd ~/yocto-icicle

# Core Yocto layers (Scarthgap release)
git clone -b scarthgap https://git.yoctoproject.org/git/poky openembedded-core
git clone -b scarthgap https://github.com/openembedded/meta-openembedded

# PolarFire SoC BSP
git clone -b scarthgap https://github.com/polarfire-soc/meta-polarfire-soc-yocto-bsp

# ROS 2 layers
git clone -b scarthgap https://github.com/ros/meta-ros
```

#### 2. Copy Custom Layer

```bash
# Clone this repository
git clone https://github.com/bhanuprakashjh/icicle-kit-ros2-humble.git

# Copy custom layer
cp -r icicle-kit-ros2-humble/meta-custom ~/yocto-icicle/
```

#### 3. Initialize Build Environment

```bash
cd ~/yocto-icicle
source openembedded-core/oe-init-build-env build
```

#### 4. Configure Build

Edit `conf/bblayers.conf`:
```bitbake
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

Add to `conf/local.conf`:
```bitbake
# Machine selection
MACHINE = "icicle-kit-es"

# Parallel build (adjust to your CPU cores)
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

# Shared cache (optional, speeds up rebuilds)
DL_DIR = "${TOPDIR}/../downloads"
SSTATE_DIR = "${TOPDIR}/../sstate-cache"

# Enable package management on target
EXTRA_IMAGE_FEATURES += "package-management"

# Development features
IMAGE_FEATURES += "tools-debug tools-sdk dev-pkgs"

# Workaround for SPDX issues
INHERIT:remove = "create-spdx"
```

#### 5. Build the Image

```bash
bitbake drone-stage1
```

Build time: 4-8 hours on first build (depending on hardware and internet speed).

## Flashing the Image

The built image is located at:
```
build/tmp-glibc/deploy/images/icicle-kit-es/drone-stage1-icicle-kit-es.rootfs.wic.gz
```

### Using bmaptool (Recommended)

```bash
sudo apt install bmap-tools
sudo bmaptool copy drone-stage1-icicle-kit-es.rootfs.wic.gz /dev/sdX
```

### Using dd

```bash
gunzip -c drone-stage1-icicle-kit-es.rootfs.wic.gz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

**Warning:** Replace `/dev/sdX` with your actual SD card device. Use `lsblk` to identify it.

## First Boot

### Serial Console Connection

```bash
# Connect USB-UART to J11 on ICICLE Kit
sudo minicom -D /dev/ttyUSB0 -b 115200
```

Settings: 115200 baud, 8N1, no flow control

### Default Login

- **Username:** root
- **Password:** (none - just press Enter)

### Test ROS 2

```bash
# Source ROS 2 environment
source /opt/ros/humble/setup.bash

# Check ROS 2 installation
ros2 --help

# List available nodes
ros2 node list

# Test topic communication
ros2 topic list
```

### Test MAVROS

```bash
# Start MAVROS with serial connection to flight controller
ros2 launch mavros mavros.launch.py fcu_url:=/dev/ttyS1:921600
```

## Package List

The image includes 1,299 packages. Key categories:

| Category | Packages |
|----------|----------|
| ROS 2 Humble Core | 165+ |
| MAVROS | 3 (mavros, mavros-extras, mavros-msgs) |
| Python 3.12 | 80+ |
| Development Tools | gcc, g++, cmake, gdb, git, make |
| Networking | WiFi, Bluetooth, CAN bus |

See [docs/PACKAGE_LIST.md](docs/PACKAGE_LIST.md) for the complete list.

## Directory Structure

```
icicle-kit-ros2-humble/
├── README.md                 # This file
├── meta-custom/              # Custom Yocto layer
│   ├── conf/
│   │   └── layer.conf        # Layer configuration
│   └── recipes-core/
│       └── images/
│           └── drone-stage1.bb  # Image recipe
├── conf-templates/           # Sample configuration files
│   ├── local.conf.sample
│   └── bblayers.conf.sample
├── scripts/
│   └── setup.sh              # Automated setup script
└── docs/
    └── PACKAGE_LIST.md       # Complete package manifest
```

## Customization

### Adding Packages

Edit `meta-custom/recipes-core/images/drone-stage1.bb`:

```bitbake
IMAGE_INSTALL:append = " \
    your-package-name \
"
```

### Creating a New Image

Copy and modify the existing recipe:

```bash
cp meta-custom/recipes-core/images/drone-stage1.bb \
   meta-custom/recipes-core/images/my-custom-image.bb
# Edit my-custom-image.bb
bitbake my-custom-image
```

## Troubleshooting

### Build Fails with Disk Space Error

Ensure 50GB+ free space. Clean old builds:
```bash
cd build
rm -rf tmp-glibc/work/*
```

### Network Timeout During Fetch

Retry or use a mirror:
```bash
bitbake drone-stage1 -c fetch
```

### ROS 2 Package Not Found

Use bare recipe names (e.g., `ros-base` not `ros-humble-ros-base`).

## References

- [Microchip PolarFire SoC Documentation](https://github.com/polarfire-soc)
- [meta-polarfire-soc-yocto-bsp](https://github.com/polarfire-soc/meta-polarfire-soc-yocto-bsp)
- [meta-ros Documentation](https://github.com/ros/meta-ros)
- [ROS 2 Humble Documentation](https://docs.ros.org/en/humble/)
- [Yocto Project Documentation](https://docs.yoctoproject.org/)

## License

This project is licensed under the MIT License. See individual layer licenses for upstream components.

## Contributing

Contributions welcome! Please open an issue or pull request.

## Author

Built for drone/robotics applications on RISC-V hardware.
