SUMMARY = "ROS2 Humble drone mission computer for PolarFire SoC Icicle Kit"
DESCRIPTION = "Custom Linux image with ROS2 Humble, MAVROS, WiFi support, and development tools"

LICENSE = "MIT"

inherit core-image

#
# ROS2 Humble Packages
# CRITICAL: Use bare recipe names (ros-base NOT ros-humble-ros-base)
#
IMAGE_INSTALL:append = " \
    ros-base \
    mavros \
    mavros-extras \
"

#
# Python3 Packages
#
IMAGE_INSTALL:append = " \
    python3-pip \
    python3-numpy \
    python3-pyserial \
"

#
# WiFi & Network Support
#
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

#
# Development Tools
#
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

#
# System Utilities
#
IMAGE_INSTALL:append = " \
    i2c-tools \
    usbutils \
    pciutils \
    lsof \
"

#
# Image Features
#
IMAGE_FEATURES += "ssh-server-openssh"
IMAGE_FEATURES += "tools-debug"
IMAGE_FEATURES += "package-management"

#
# Extra rootfs space (2GB)
#
IMAGE_ROOTFS_EXTRA_SPACE = "2097152"

#
# Serial console
#
SERIAL_CONSOLES = "115200;ttyS0"
