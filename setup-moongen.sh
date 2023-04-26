#!/usr/bin/env bash

# Clone MoonGen
cd /home/vagrant
git clone https://github.com/P4-vSwitch/MoonGen.git
cd MoonGen/
git checkout dpdk2.1
git submodule update --init

# Build LuaJIT
cd /home/vagrant/MoonGen/deps/luajit
make -j 2 'CFLAGS=-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'
make install DESTDIR=$(pwd)

# Build DPDK
cd /home/vagrant/MoonGen/deps/dpdk
patch -p1 -N < ../../setup-scripts/patches/dpdk-config.patch
make -j 2 install T=x86_64-native-linuxapp-gcc

# Setup DPDK-specific environment variables
export RTE_SDK=/home/vagrant/MoonGen/deps/dpdk
export RTE_TARGET=x86_64-native-linuxapp-gcc
export DPDK_DIR=$RTE_SDK
export DPDK_BUILD=$DPDK_DIR/$RTE_TARGET/

# Note: You may want to append these variables in the `~/.bashrc` file. This way you don't have to execute these whenever you
# open a new terminal.

# Setup DPDK kernel modules
cd /home/vagrant
sudo modprobe uio
sudo insmod $RTE_SDK/$RTE_TARGET/kmod/igb_uio.ko
sudo insmod $RTE_SDK/$RTE_TARGET/kmod/rte_kni.ko "lo_mode=lo_mode_ring"

# Add eth1 and eth2 interfaces to DPDK
sudo ifconfig eth1 down
sudo $RTE_SDK/tools/dpdk_nic_bind.py -b igb_uio eth1
sudo ifconfig eth2 down
sudo $RTE_SDK/tools/dpdk_nic_bind.py -b igb_uio eth2

# To view these interfaces run the following command:
# $RTE_SDK/tools/dpdk_nic_bind.py --status

# Configure Huge Pages
cd /home/vagrant
sudo mkdir -p /mnt/huge
(mount | grep hugetlbfs) > /dev/null || sudo mount -t hugetlbfs nodev /mnt/huge
echo 512 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages

# Note: you can verify if huge pages are configured properly using the following command:
# grep -i huge /proc/meminfo

# Build MoonGen
cd /home/vagrant/MoonGen/build
cmake ..
make