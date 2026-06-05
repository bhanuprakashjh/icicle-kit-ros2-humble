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

### Install the repo Tool

```bash
mkdir -p ~/.local/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
chmod a+x ~/.local/bin/repo
export PATH=$HOME/.local/bin:$PATH
```

Add the export to your `~/.bashrc` to make it permanent.

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

#### 1. Download BSP layers via repo manifest

The Microchip BSP now ships via the
[meta-mchp-manifest](https://github.com/linux4microchip/meta-mchp-manifest)
repo manifest. A single `repo sync` replaces four separate `git clone` calls.

```bash
mkdir -p ~/yocto-icicle && cd ~/yocto-icicle

repo init \
    -u https://github.com/linux4microchip/meta-mchp-manifest.git \
    -b refs/tags/linux4microchip-2026.04 \
    -m polarfire-soc/default.xml

repo sync
```

This downloads:
- `openembedded-core` — OE core / Poky equivalent
- `bitbake` — BitBake build tool
- `meta-openembedded` — OE layer collection (meta-oe, meta-python, meta-networking, …)
- `meta-mchp` — Microchip BSP (replaces the old `meta-polarfire-soc-yocto-bsp`)

#### 2. Clone meta-ros (not in the Microchip manifest)

```bash
git clone -b scarthgap https://github.com/ros/meta-ros
```

#### 3. Copy the custom layer from this repository

```bash
git clone https://github.com/bhanuprakashjh/icicle-kit-ros2-humble.git
cp -r icicle-kit-ros2-humble/meta-custom ~/yocto-icicle/
```

#### 4. Initialize build environment from Microchip template

```bash
cd ~/yocto-icicle
export TEMPLATECONF="${PWD}/meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-bsp/conf/templates/default"
source openembedded-core/oe-init-build-env build
```

The Microchip template pre-populates `conf/bblayers.conf` and `conf/local.conf`
with the correct BSP layers and machine defaults.

#### 5. Add ROS 2 and custom layers

Append to `conf/bblayers.conf`:

```bitbake
BBLAYERS += " \
  /home/<user>/yocto-icicle/meta-ros/meta-ros-common \
  /home/<user>/yocto-icicle/meta-ros/meta-ros2 \
  /home/<user>/yocto-icicle/meta-ros/meta-ros2-humble \
  /home/<user>/yocto-icicle/meta-custom \
"
```

#### 6. Configure local.conf

Append to `conf/local.conf` (see [conf-templates/local.conf.sample](conf-templates/local.conf.sample)):

```bitbake
MACHINE = "mpfs-icicle-kit"

BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"

DL_DIR = "${TOPDIR}/../downloads"
SSTATE_DIR = "${TOPDIR}/../sstate-cache"

EXTRA_IMAGE_FEATURES += "package-management"
IMAGE_FEATURES += "tools-debug tools-sdk dev-pkgs"

INHERIT:remove = "create-spdx"
```

> **Note:** The machine name changed from `icicle-kit-es` (used by the old
> `meta-polarfire-soc-yocto-bsp`) to `mpfs-icicle-kit` (used by the new
> `meta-mchp` BSP).

#### 7. Build the image

```bash
bitbake drone-stage1
```

Build time: 4-8 hours on first build (depending on hardware and internet speed).

## BSP Layer Structure (new vs old)

| Old (`meta-polarfire-soc-yocto-bsp`) | New (`meta-mchp`) |
|--------------------------------------|-------------------|
| `meta-polarfire-soc-bsp` | `meta-mchp/meta-mchp-common` |
| — | `meta-mchp/meta-mchp-distro` |
| — | `meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-bsp` |
| — | `meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-community` |
| Machine: `icicle-kit-es` | Machine: `mpfs-icicle-kit` |

## Flashing the Image

The built image is located at:
```
build/tmp-glibc/deploy/images/mpfs-icicle-kit/drone-stage1-mpfs-icicle-kit.rootfs.wic.gz
```

### Using bmaptool (Recommended)

```bash
sudo apt install bmap-tools
sudo bmaptool copy drone-stage1-mpfs-icicle-kit.rootfs.wic.gz /dev/sdX
```

### Using dd

```bash
gunzip -c drone-stage1-mpfs-icicle-kit.rootfs.wic.gz | sudo dd of=/dev/sdX bs=4M status=progress
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
source /opt/ros/humble/setup.bash
ros2 --help
ros2 node list
ros2 topic list
```

### Test MAVROS

```bash
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
├── conf-templates/           # Reference configuration files
│   ├── local.conf.sample     # Settings appended after template init
│   └── bblayers.conf.sample  # Shows full layer stack (template + ROS 2)
├── scripts/
│   └── setup.sh              # Automated setup script
└── docs/
    └── PACKAGE_LIST.md       # Complete package manifest
```

## Customization

### Adding Packages

Edit [meta-custom/recipes-core/images/drone-stage1.bb](meta-custom/recipes-core/images/drone-stage1.bb):

```bitbake
IMAGE_INSTALL:append = " \
    your-package-name \
"
```

### Creating a New Image

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

```bash
bitbake drone-stage1 -c fetch
```

### ROS 2 Package Not Found

Use bare recipe names (e.g., `ros-base` not `ros-humble-ros-base`).

### `repo` Command Not Found

Install the repo tool as described in the [prerequisites](#install-the-repo-tool) section above.

## References

- [Microchip meta-mchp-manifest](https://github.com/linux4microchip/meta-mchp-manifest)
- [Microchip meta-mchp BSP](https://github.com/linux4microchip/meta-mchp)
- [meta-ros Documentation](https://github.com/ros/meta-ros)
- [ROS 2 Humble Documentation](https://docs.ros.org/en/humble/)
- [Yocto Project Documentation](https://docs.yoctoproject.org/)

## License

This project is licensed under the MIT License. See individual layer licenses for upstream components.

## Contributing

Contributions welcome! Please open an issue or pull request.

## Author

Built for drone/robotics applications on RISC-V hardware.
