#!/bin/sh

# Git tags for the package releases
LIBDISPATCH_VERSION="5.10"
LIBDISPATCH_TAG="swift-${LIBDISPATCH_VERSION}-RELEASE"
LIBOBJC_VERSION="2.2"
LIBOBJC2_TAG="v${LIBOBJC_VERSION}"
GNUSTEP_MAKE_TAG="make-2_9_1"
GNUSTEP_BASE_TAG="base-1_29_0"

# Account
ROOT_PASSWORD="root" # Change this
VMP_PASSWORD="vmp" # Change this

NATIVE_ARCH="$(dpkg --print-architecture)"

if [ "${NATIVE_ARCH}" = "arm64" ]; then
	MULTIARCH_PATH="aarch64-linux-gnu"
elif [ "${NATIVE_ARCH}" = "amd64" ]; then
	MULTIARCH_PATH="x86_64-linux-gnu"
else
	echo "Unsupported architecture: ${NATIVE_ARCH}"
	exit 1
fi

echo "* Preparing RootFS..."
echo "* Arch: ${NATIVE_ARCH} Multiarch: ${MULTIARCH_PATH}"

# Uncomment en_US.UTF-8 locale in configuration
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen

# Generate locale
echo "* Generating locale..."
locale-gen

echo "LANG=en_US.UTF-8" | tee /etc/default/locale
echo "LANGUAGE=en_US.UTF-8" | tee -a /etc/default/locale
echo "LC_ALL=en_US.UTF-8" | tee -a /etc/default/locale

echo "* Updating locale..."
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

# For this session
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "* Creating Accounts..."
# Create new user with USERNAME and PASSWORD and add to sudo
useradd -m -s /bin/bash -G sudo "vmp"
echo "vmp:${VMP_PASSWORD}" | chpasswd

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Compiler Flags
export CC=clang
export OBJC=clang # Required by meson for building Objective-C code
export CXX=clang++
export CPP="clang -E"
export LD=ld.lld

echo "* Updating package list..."
apt update

# We are now building libdispatch, libobjc2, gnustep-make, and
# gnustep-base from source, as the Debian packages
# horribly outdated and use the legacy GCC Objective-C runtime.
#
# Someday, a working GNUstep APT repository may replace this step.

echo "* Building Objective-C Packages..."

echo "* Installing compiler and build tools..."
apt install -y cmake meson clang lld git ninja-build make pkg-config autotools-dev
if test $? -ne 0; then
	echo "Failed to install compiler and build tools"
	exit 1
fi

# Building and Installing Grand Central Dispatch

echo "* Cloning libdispatch..."
git clone "https://github.com/apple/swift-corelibs-libdispatch" --branch "${LIBDISPATCH_TAG}" --depth 1
if test $? -ne 0; then
	echo "Failed to clone libdispatch"
	exit 1
fi

echo "* Configuring libdispatch..."
cd swift-corelibs-libdispatch

cmake -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_LINKER=ld.lld \
	-DBUILD_SHARED_LIBS=YES \
	-DBUILD_TESTING=NO \
	-DINSTALL_PRIVATE_HEADERS=YES \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-GNinja
if test $? -ne 0; then
	echo "Failed to configure libdispatch"
	exit 1
fi

echo "* Building libdispatch..."
ninja -C build
if test $? -ne 0; then
	echo "Failed to build libdispatch"
	exit 1
fi

echo "* Installing libdispatch..."
ninja -C build install
if test $? -ne 0; then
	echo "Failed to install libdispatch"
	exit 1
fi

cd ..
rm -rf swift-corelibs-libdispatch

## libdispatch does not ship a pkg-config file, so we need to create one
echo "* Creating libdispatch pkg-config file..."
cat <<EOF > /usr/lib/pkgconfig/libdispatch.pc
Name: libdispatch
Description: Grand Central Dispatch (GCD)
Version: ${LIBDISPATCH_VERSION}
Libs: -ldispatch
Cflags: -I/usr/include
EOF

## Building and Installing the Objective-C 2.0 Runtime

echo "* Installing dependencies for libobjc2..."
apt install -y robin-map-dev
if test $? -ne 0; then
	echo "Failed to install dependencies for libobjc2"
	exit 1
fi

echo "* Cloning libobjc2..."
git clone "https://github.com/gnustep/libobjc2" --branch "${LIBOBJC2_TAG}" --depth 1 --recurse-submodules
if test $? -ne 0; then
	echo "Failed to clone libobjc2"
	exit 1
fi

echo "* Configuring libobjc2..."
cd libobjc2
cmake -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DTESTS=OFF \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_LINKER=ld.lld \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-GNinja
if test $? -ne 0; then
	echo "Failed to configure libobjc2"
	exit 1
fi

echo "* Building libobjc2..."
ninja -C build
if test $? -ne 0; then
	echo "Failed to build libobjc2"
	exit 1
fi

echo "* Installing libobjc2..."
ninja -C build install
if test $? -ne 0; then
	echo "Failed to install libobjc2"
	exit 1
fi

cd ..
rm -rf libobjc2

## Building and Installing GNUstep Make

echo "* Cloning GNUstep make..."
git clone "https://github.com/gnustep/tools-make"
if test $? -ne 0; then
	echo "Failed to clone GNUstep make"
	exit 1
fi

echo "* Building GNUstep make..."
cd tools-make

# The GNUstep make package configuration is a bit tricky...
# We want to explicitly enable all modern Objective-C features
# and set the runtime ABI to the current ABI version.
#
# This version is passed to clang as -fobjc-runtime=gnustep-2.2
# during building of any Objective-C code using GNUstep Make.
# If the version is inaccurate, Clang may not make use of newer
# runtime features.
./configure \
	--with-layout=debian \
	--enable-native-objc-exceptions \
	--enable-objc-arc \
	--enable-install-ld-so-conf \
	--with-runtime-abi=gnustep-${LIBOBJC_VERSION} \
	--with-library-combo=ng-gnu-gnu \
	--prefix=/usr \
	CC="clang" CXX="clang++" CPP="clang -E" LDFLAGS="-fuse-ld=lld -L/usr/lib/${MULTIARCH_PATH}" SHELLPROG=/bin/bash GNUMAKE=make 
if test $? -ne 0; then
	echo "Failed to configure GNUstep make"
	exit 1
fi

echo "* Building GNUstep make..."
make
if test $? -ne 0; then
	echo "Failed to build GNUstep make"
	exit 1
fi

echo "* Installing GNUstep make..."
make install
if test $? -ne 0; then
	echo "Failed to install GNUstep make"
	exit 1
fi

cd ..
rm -rf tools-make

echo "* Installing GNUstep base dependencies..."
apt install -y \
	gnutls-bin \
	libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libgnutls28-dev \
    zlib1g-dev \
    m4 \
    libavahi-client-dev \
    libicu-dev \
    tzdata \
	ca-certificates \
    libcurl4-openssl-dev
if test $? -ne 0; then
	echo "Failed to install GNUstep base dependencies"
	exit 1
fi

echo "* Cloning gnustep-base..."
git clone "https://github.com/gnustep/libs-base" --branch "${GNUSTEP_BASE_TAG}" --depth 1
if test $? -ne 0; then
	echo "Failed to clone gnustep-base"
	exit 1
fi

echo "* Configuring gnustep-base..."
cd libs-base

# Source GNUstep environment
source /usr/share/GNUstep/Makefiles/GNUstep.sh

./configure \
	--with-installation-domain=SYSTEM \
	 CURRENT_GNUSTEP_MAKEFILES=/usr/share/GNUstep/Makefiles LDFLAGS="-fuse-ld=lld -L/usr/lib/${MULTIARCH_PATH}"
if test $? -ne 0; then
	echo "Failed to configure gnustep-base"
	exit 1
fi

echo "* Building gnustep-base..."
make -j `nproc`
if test $? -ne 0; then
	echo "Failed to build gnustep-base"
	exit 1
fi

echo "* Installing gnustep-base..."
make install
if test $? -ne 0; then
	echo "Failed to install gnustep-base"
	exit 1
fi

cd ..
rm -rf libs-base

echo "* Finished building Objective-C Packages"

# It is time to build all VMP packages
echo "* Cloning VMP repository..."
git clone "https://github.com/TUM-Dev/VMP" --branch "main" --depth 1
if test $? -ne 0; then
	echo "Failed to clone VMP project"
	exit 1
fi

cd VMP

echo "* Installing dependencies for MicroHTTPKit..."
apt install -y libmicrohttpd-dev

echo "* Building MicroHTTPKit..."
cd Libraries/MicroHTTPKit

meson setup build --prefix /usr
if test $? -ne 0; then
	echo "Failed to configure MicroHTTPKit"
	exit 1
fi

ninja -C build install
if test $? -ne 0; then
	echo "Failed to build and install MicroHTTPKit"
	exit 1
fi

cd ../

echo "* Building CalendarKit..."
cd CalendarKit

meson setup build --prefix /usr
if test $? -ne 0; then
	echo "Failed to configure CalendarKit"
	exit 1
fi

ninja -C build install
if test $? -ne 0; then
	echo "Failed to build and install CalendarKit"
	exit 1
fi

cd ../..

echo "* Installing vmpserverd Dependencies"
apt install -y --no-install-recommends \
	libglib2.0-dev \
	libgstreamer1.0-dev \
	libgstreamer-plugins-base1.0-dev \
	libgstreamer-plugins-bad1.0-dev \
	gstreamer1.0-plugins-ugly \
	gstreamer1.0-libav \
	libgstrtspserver-1.0-dev \
	libudev-dev \
	libgraphviz-dev \
	libsystemd-dev
if test $? -ne 0; then
	echo "Failed to install vmpserverd dependencies"
	exit 1
fi

echo "* Building vmpserverd"
cd Daemons/vmpserverd

meson setup build --prefix /usr
if test $? -ne 0; then
	echo "Failed to configure vmpserverd"
	exit 1
fi

ninja -C build install
if test $? -ne 0; then
	echo "Failed to build and install vmpserverd"
	exit 1
fi

cd ../../..
rm -rf VMP

echo "* Finished building VMP packages"

echo "* Enabling vmpserverd systemd service"
systemctl enable vmpserverd

echo "* Cleaning up..."
apt remove -y cmake meson clang lld git ninja-build make pkg-config autotools-dev
apt autoremove -y
apt clean -y

rm -f /root/post-install.sh

echo "* Finished RootFS setup. Exiting..."
