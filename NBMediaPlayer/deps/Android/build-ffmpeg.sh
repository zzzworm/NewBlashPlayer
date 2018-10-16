#!/bin/sh

# this request set NDK_ROOT and version recommend r13b
SYSROOT=$NDK_ROOT/platforms/android-19/arch-arm
TOOLCHAIN=$NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64

BUILD_DIR=`pwd`/build
if [ ! -r $BUILD_DIR ]
then
	mkdir $BUILD_DIR
fi
# change directory to build
cd $BUILD_DIR

# directories
FF_VERSION="3.4.4"
if [[ $FFMPEG_VERSION != "" ]]; then
  FF_VERSION=$FFMPEG_VERSION
fi
SOURCE="ffmpeg-$FF_VERSION"
INSTALL_PREFIX=`pwd`/"FFmpeg-Android"

SCRATCH="ffmpeg_scratch"
# must be an absolute path
# THIN=`pwd`/"ffmpeg_thin"

# disable protocols
#     		  --disable-protocols \
#                 --disable-protocol=http \
#                 --disable-protocol=rtp \
#                 --disable-protocol=tcp \
#                 --disable-protocol=udp \

CONFIGURE_FLAGS="--enable-cross-compile \
                 --disable-debug \
                 --disable-programs \
                 --disable-doc \
                 --disable-protocols \
                 --disable-protocol=http \
                 --disable-protocol=rtp \
                 --disable-protocol=tcp \
                 --disable-protocol=udp \
                 --disable-avfilter \
                 --disable-avdevice \
                 --disable-encoders \
                 --disable-hwaccels \
                 --disable-muxers \
                 --disable-devices \
                 --enable-small \
                 --enable-pic"

#ARCHS="arm64 armv7 x86_64 i386"
ARCHS="armeabi-v7a"

COMPILE="y"
LIPO=""

DEPLOYMENT_TARGET="8.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	CWD=`pwd`
	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		axel -n 16 -o $CWD/$SOURCE.tar.bz2 -v http://www.ffmpeg.org/releases/$SOURCE.tar.bz2
		tar zxvf $CWD/$SOURCE.tar.bz2
		# curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
		# 	|| exit 1
	fi


	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		# CFLAGS="-arch $ARCH"
		# if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		# then
		#     PLATFORM="iPhoneSimulator"
		#     CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		# else
		#     PLATFORM="iPhoneOS"
		#     CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		#     if [ "$ARCH" = "arm64" ]
		#     then
		#         EXPORT="GASPP_FIX_XCODE5=1"
		#     fi
		# fi
		
		if [ "$ARCH" = "armeabi-v7a" ]
		then
			TARGET_ARCH="arm"
		fi

		# XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		# CC="xcrun -sdk $XCRUN_SDK clang"

		# # force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.4.4)
		# if [ "$ARCH" = "arm64" ]
		# then
		#     AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		# else
		#     AS="gas-preprocessor.pl -- $CC"
		# fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		export CC="$TOOLCHAIN/bin/arm-linux-androideabi-gcc --sysroot=$SYSROOT"
		export CXX="$TOOLCHAIN/bin/arm-linux-androideabi-g++ --sysroot=$SYSROOT"
		export LINK="$CXX"
		export LD=$TOOLCHAIN/bin/arm-linux-androideabi-ld
		export AR=$TOOLCHAIN/bin/arm-linux-androideabi-ar
		export RANLIB=$TOOLCHAIN/bin/arm-linux-androideabi-ranlib
		export STRIP=$TOOLCHAIN/bin/arm-linux-androideabi-strip

		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
			--cross-prefix=$TOOLCHAIN/bin/arm-linux-androideabi- \
		    --target-os=linux \
		    --arch=$TARGET_ARCH \
		    --sysroot=$SYSROOT \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$INSTALL_PREFIX/$ARCH" \
		    --disable-linux-perf \
		|| exit 1

		make -j8 install $EXPORT || exit 1
		cd $CWD
	done
fi

# if [ "$LIPO" ]
# then
# 	echo "building fat binaries..."
# 	mkdir -p $FAT/lib
# 	set - $ARCHS
# 	CWD=`pwd`
# 	cd $THIN/$1/lib
# 	for LIB in *.a
# 	do
# 		cd $CWD
# 		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
# 		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
# 	done

# 	cd $CWD
# 	cp -rf $THIN/$1/include $FAT
# fi

echo "copy target file"
echo "target directory : "$FAT
cp -rf $INSTALL_PREFIX `pwd`/../ffmpeg

echo Done