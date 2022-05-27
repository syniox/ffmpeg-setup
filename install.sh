#!/bin/bash

alllibs="x264 x265 dav1d fdk-aac"
base="$(cd $(dirname $0); pwd)"
PREFIX=build
threads=4


TOOLCHAIN=x86_64-w64-mingw32
CROSS_PREFIX=x86_64-w64-mingw32-

# TODO: add static library support
# TODO: install dependencies automatically
# Dependencies: autoconf libtool nasm

for opt do
    optarg="${opt#*=}"
    case "$opt" in
        -t=*)
            threads="$optarg";;
        --cross)
            cross=1;;
        --mirror)
            mirror=1;;
        --lib*)
            exlibs+=" ${opt#*b}";;
        -h)
            ask_help=1;;
        --help)
            ask_help=1;;
        *)
            echo [Error] Unknown option: $opt, exited.
            echo [Error] Type $0 --help for more information.
            exit 1;;
    esac
done

# Print Usage (if needed)
if [[ $ask_help == 1 ]]; then
    cat<<EOF
Usage: $0 [options]
  -h, --help            print this message
  -t=<int>(default:2)   set number of threads in compilation
  --cross               cross compile ffmpeg for windows
  --mirror              download ffmpeg behind The Great FireWall
  --prefix=<prefix>     set work directory to <prefix>
  --lib<library name>   include external library (e.g. --libx264)
    available <library name>: $alllibs
EOF
exit 0
fi

# Helper variables
CONF=" --enable-static --enable-pic --prefix=/ --enable-lto"
if [[ $cross == 1 ]]; then
    CONF+=" --host=$TOOLCHAIN --cross-prefix=$CROSS_PREFIX"
    PREFIX=build-cross
fi

# Helper functions
make_install(){
    make -j$threads || exit 1
    make install DESTDIR="$base/$PREFIX" || exit 1
}

# Build functions
build_x264(){
    echo [Info] Building x264...
    cd "$base/plugins"
    git clone https://code.videolan.org/videolan/x264 --depth=1
    cd x264
    ./configure $CONF --disable-cli
    make_install
}
build_x265(){
    echo [Info] Building x265...
    cd "$base/plugins"
    git clone -b 3.4.1 https://bitbucket.org/multicoreware/x265_git x265 --depth=1
    cd x265

    local config=(
        -DCMAKE_INSTALL_PREFIX="$base/$PREFIX"
        -DENABLE_SHARED=0
        -DCMAKE_BUILD_TYPE=Release
        -DENABLE_CLI=0
    )
    if [[ $cross == 1 ]]; then
        config+=( -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN.cmake )
    fi
}

build_ffmpeg(){
    git clone -b n5.0.1 https://git.ffmpeg.org/ffmpeg --depth=1
}

# Ensure libraries
echo [Info] exlibs: $exlibs
for exlib in $exlibs; do
    if [[ -z "$( grep $exlib <<< $alllibs )" ]]; then
        invld_lib+=" $exlib"
    fi
done
if [[ -n "$invld_lib" ]]; then
    echo [Error] Invalid library finded: $invld_lib
    exit 1
fi

# Build libraries
for lib in $exlibs; do
    build_$exlib
done
