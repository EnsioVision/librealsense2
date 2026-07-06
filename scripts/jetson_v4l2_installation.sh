#!/bin/bash -xe

#Locally suppress stderr to avoid raising not relevant messages
exec 3>&2
exec 2> /dev/null
con_dev=$(ls /dev/video* | wc -l)
exec 2>&3

if [ -z "$1" ]; then
	build_type=Release
else
	build_type=$1
fi

echo "Building $build_type ..."

if [ $con_dev -ne 0 ];
then
	echo -e "\e[32m"
	read -p "Remove all RealSense cameras attached. Hit any key when ready"
	echo -e "\e[0m"
fi

lsb_release -a
echo "Kernel version $(uname -r)"

echo Install udev-rules
cd ..
sudo cp config/99-realsense-libusb.rules /etc/udev/rules.d/
sudo cp config/99-realsense-d4xx-mipi-dfu.rules /etc/udev/rules.d/

# The mipi-dfu udev rule RUN+= references these by name, so they must be on
# udev's PATH before rules are triggered, or /dev/video-rs-* links never get created.
sudo cp scripts/rs-enum.sh scripts/rs_ipu6_d457_bind.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rs-enum.sh /usr/local/bin/rs_ipu6_d457_bind.sh

sudo udevadm control --reload-rules && sudo udevadm trigger

# rm -rf build
mkdir build || true
cd build
echo 
echo "Calling cmake"

# If FORCE_RSUSB_BACKEND is not defined, it will default to using V4L2
cmake .. -D CMAKE_INSTALL_PREFIX=/home/ensio/evRealSense -D BUILD_WITH_CUDA=true -D CMAKE_BUILD_TYPE=$build_type -D CMAKE_CUDA_ARCHITECTURES="87"
echo
echo "Running make -j4"
make -j4
echo
echo "Running make install"
sudo make install
echo -e "\e[92m\n\e[1mLibrealsense script completed.\n\e[0m"




