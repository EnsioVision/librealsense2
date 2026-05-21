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

# if [ $(sudo swapon --show | wc -l) -eq 0 ];
# then
# 	echo "No swapon - setting up 1Gb swap file"
# 	sudo fallocate -l 2G /swapfile
# 	sudo chmod 600 /swapfile
# 	sudo mkswap /swapfile
# 	sudo swapon /swapfile
# 	sudo swapon --show
# fi

echo Install udev-rules
cd ..
sudo cp config/99-realsense-libusb.rules /etc/udev/rules.d/ 
sudo cp config/99-realsense-d4xx-mipi-dfu.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger 

# rm -rf build
mkdir build || true
cd build
echo 
echo "Calling cmake"

cmake .. -DCMAKE_INSTALL_PREFIX=/home/ensio/evRealSense -DFORCE_RSUSB_BACKEND=ON -DBUILD_WITH_CUDA=true -DCMAKE_BUILD_TYPE=$build_type -DCMAKE_CUDA_ARCHITECTURES="87"
echo
echo "Running make -j4"
make -j4
echo
echo "Running make install"
sudo make install
echo -e "\e[92m\n\e[1mLibrealsense script completed.\n\e[0m"




