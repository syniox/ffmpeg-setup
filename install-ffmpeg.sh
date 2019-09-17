#!/bin/bash

current_dir=$( pwd )
work_dir=$(cd $(dirname $0); pwd)
cd $work_dir
ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
cd $work_dir && mkdir -p ffmpeg_sources
cd ffmpeg_sources
x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
dav1d_dir=$( ls -l | grep '^d' | grep dav1d | awk '{ print $9 }' )
fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )
# libass_dir=$( ls -l | grep '^d' | grep ass | awk '{ print $9 }' )
install_dependencies=""
static_lib=0
threads="2"
BUILD_OPT="
  --prefix="$work_dir/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --libdir="$work_dir/ffmpeg_build/bin" \
  --disable-hwaccels \
  --disable-filters \
  --enable-filter=aresample,resize,psnr,ssim,subtitles,scale \
  --disable-bsfs \
  --disable-muxers \
  --enable-muxer=flac,h264,hevc,ico,matroska,mjpeg \
  --enable-muxer=mp4,null,rawvideo,wav,yuv4mpegpipe \
  --enable-gpl \
  --enable-nonfree \
  --disable-decoders \
  --disable-encoders \
  --enable-decoder=aac,flac,h264,hevc,libdav1d,mjpeg,mp3,opus,png,rawvideo,vp9,yuv4 \
  --enable-encoder=aac,libx264,libx265,libfdk_aac,mjpeg,rawvideo,wrapped_avframe
"

# some problems occured when compiling with mingw32-make, use make for msys2 at the moment
make_program=make
# if [[ `uname` == Linux ]]; then
#   make_program=make
# else
#   make_program=mingw32-make
# fi

if test x"$1" = x"-h" -o x"$1" = x"--help" ; then
cat <<EOF
Usage: $0 [options]
Help:
  -h, --help           print this message
  -i                   install dependencies automatically
  -t=<int>(default:2)  set the number of threads in compilation
  -x                   build static library(default: shared)
  --enable-libx264     include x264 library(default disabled)
  --enable-libx265     include x265 library(default disabled)
  --enable-libdav1d    include dav1d library(default disabled)
  --enable-libfdkaac   include fdkaac library(default disabled)
EOF
exit 1
fi

for opt do
  optarg="${opt#*=}"
  case "$opt" in 
    -i)
      install_dependencies="true"
      ;;
    -t=*)
      threads="$optarg"
      ;;
    -x)
      static_lib=1
      ;;
    --enable-libx264)
      echo "x264 enabled."
      BUILD_OPT="${BUILD_OPT} --enable-libx264"
      enable_x264=1
      ;;
    --enable-libx265)
      echo "x265 enabled."
      BUILD_OPT="${BUILD_OPT} --enable-libx265"
      enable_x265=1
      ;;
    --enable-libdav1d)
      echo "dav1d enabled."
      BUILD_OPT="${BUILD_OPT} --enable-libdav1d"
      enable_dav1d=1
      ;;
    --enable-libfdkaac)
      echo "fdkaac enabled."
      BUILD_OPT="${BUILD_OPT} --enable-libfdk-aac"
      enable_fdkaac=1
      ;;
    *)
      echo "Unknown option $opt, stopped."
      echo "Run $0 -h for help."
      exit 1
      ;;
  esac
done
echo "threads: ${threads}"
echo "Make Program: ${make_program}"

check_dependencies(){
  dependency_list=(
    "git"
    "tar"
    "diffutils"
    "wget"
    "autoconf"
    "automake"
    "make"
    "mingw-w64-x86_64-pkg-config"
    "mingw-w64-x86_64-make"
    "mingw-w64-x86_64-cmake"
    "mingw-w64-x86_64-gcc"
    "mingw-w64-x86_64-SDL2"
    "mingw-w64-x86_64-nasm"
    "mingw-w64-x86_64-libtool"
  )
  missing_dependencies=""

  for dependency in "${dependency_list[@]}"; do
    if pacman -Q $dependency > /dev/null 2>&1
  	then echo "$dependency has been installed."  
    else
      if [[ -n $install_dependencies ]]; then 
  	    pacman -S $dependency -q --noconfirm || exit 1
      else
  	    missing_dependencies="$missing_dependencies  $dependency"
  	  fi
    fi
  done

  if [[ -n $missing_dependencies ]] && [[ -z $install_dependencies ]]; then 
    echo "missing required program(s): $missing_dependencies " >&2
    echo "or add -i option to install them automatically." >&2
    exit 1;
  fi
}

download_ffmpeg(){
  cd $work_dir
  if [ -f "n4.2.1.tar.gz" ]; then
    :
  else 
    echo "Downloading FFmpeg 4.2.1"
    wget \
      "https://github.com/FFmpeg/FFmpeg/archive/n4.2.1.tar.gz" \
      || exit 1
    echo "Downloaded FFmpeg 4.2.1"
  fi
  if [ -n "$ffmpeg_dir" ]; then
    echo "FFmpeg exists."
  else
    tar -xzf n4.2.1.tar.gz || exit 1
    echo "Unpacked FFmpeg."
    ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
  fi
}

build_x264(){
  cd $work_dir/ffmpeg_sources

  if [ -f "last_x264.tar.bz2" ]; then
    :
  else
    echo "Downloading x264 library."
    wget \
      "http://ftp.videolan.org/pub/x264/snapshots/last_x264.tar.bz2" \
      || exit 1
    echo "Downloaded x264 library."
  fi
  if [ -n "$x264_dir" ]; then
    echo "x264 library exists."
  else
    tar -xjf last_x264.tar.bz2 || exit 1
    echo "Unpacked x264 library."
    x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x264.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x264_dir
    ./configure \
      --prefix=$work_dir/ffmpeg_build \
      --disable-avs \
      --disable-opencl \
      --enable-static \
      --enable-pic \
      --enable-lto || exit 1
    ${make_program} -j${threads} && ${make_program} install || exit 1
  fi
}

build_x265(){
  cd $work_dir/ffmpeg_sources

  if [ -f "x265_3.0.tar.gz" ]; then
    :
  else
    echo "Downloading x265 library."
    wget \
      "http://ftp.videolan.org/pub/videolan/x265/x265_3.0.tar.gz" \
      || exit 1
    echo "Downloaded x265 library."
  fi
  if [ -n "$x265_dir" ]; then
    echo "x265 library exists."
  else 
    tar -xzf x265_3.0.tar.gz || exit 1
    echo "Unpacked x265 library."
    x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x265.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x265_dir/source
    cmake -G "Unix Makefiles" \
      -DCMAKE_MAKE_PROGRAM=${make_program} \
      -DENABLE_SHARED=0 \
      -DCMAKE_INSTALL_PREFIX="$work_dir/ffmpeg_build" \
      -DCMAKE_C_COMPILER=gcc \
      -DCMAKE_CXX_COMPILER=g++ \
      . || exit 1
    ${make_program} -j${threads} && ${make_program} install || exit 1
  fi
}

build_dav1d(){
  mkdir -p $work_dir/ffmpeg_build
  mkdir -p $work_dir/ffmpeg_build/lib
  mkdir -p $work_dir/ffmpeg_build/lib/pkgconfig

  cd $work_dir/ffmpeg_sources
  if [ -f "dav1d-0.4.0.tar.gz" ]; then
    :
  else
    echo "Downloading fdk-aac library."
    wget -O dav1d-0.4.0.tar.gz \
      "https://github.com/videolan/dav1d/archive/0.4.0.tar.gz" \
      || exit 1
    echo "Downloaded dav1d library."
  fi
  if [ -n "$dav1d_dir" ]; then
    echo "dav1d library exists."
  else
    tar -xzf dav1d-0.4.0.tar.gz || exit 1
    echo "Unpacked dav1d library."
    dav1d_dir=$( ls -l | grep '^d' | grep dav1d | awk '{ print $9 }' )
  fi

  cd $dav1d_dir
  if [ -f build/src/libdav1d.a ]; then
    :
  else
    meson build -Ddefault_library=static \
      -Denable_tests=false -Dbitdepths=8 \
      -Denable_tools=false || exit 1
    ninja -C build || exit 1
  fi
  cp build/src/libdav1d.a $work_dir/ffmpeg_build/lib || exit 1
  cp -r include/dav1d $work_dir/ffmpeg_build/include || exit 1
  cp -r build/include/dav1d $work_dir/ffmpeg_build/include || exit 1

  cd $work_dir
  echo "prefix=${work_dir}/ffmpeg_build" > dav1d.pc
  cat _dav1d.pc >> dav1d.pc
  mv dav1d.pc $work_dir/ffmpeg_build/lib/pkgconfig
}

build_fdkaac(){
  cd $work_dir/ffmpeg_sources

  if [ -f "fdk_aac-v2.0.0.tar.gz" ]; then
    :
  else
    echo "Downloading fdk-aac library."
    wget -O fdk_aac-v2.0.0.tar.gz \
      "https://github.com/mstorsjo/fdk-aac/archive/v2.0.0.tar.gz" \
      || exit 1
    echo "Downloaded fdk-aac library."
  fi
  if [ -n "$fdkaac_dir" ]; then
    echo "fdkaac library exists."
  else
    tar -xzf fdk_aac-v2.0.0.tar.gz || exit 1
    echo "Unpacked fdkaac library."
    fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/fdk-aac.pc" ]; then
    cd $work_dir/ffmpeg_sources/$fdkaac_dir
    autoreconf -fi 
    ./configure \
      --prefix=$work_dir/ffmpeg_build \
      --with-pic=yes \
      --enable-shared=no || exit 1
    ${make_program} -j${threads} && ${make_program} install || exit 1
  fi
}

build_ffmpeg(){
  cd $work_dir/$ffmpeg_dir
  if [[ $static_lib == 1 ]]; then
    BUILD_OPT="${BUILD_OPT} --disable-shared --enable-static"
  else
    BUILD_OPT="${BUILD_OPT} --enable-shared --disable-static"
  fi
  PKG_CONFIG_PATH="$work_dir/ffmpeg_build/lib/pkgconfig/" \
  CFLAGS="-I$work_dir/ffmpeg_build/include" \
  LDFLAGS="-L$work_dir/ffmpeg_build/lib" \
  LIBS="-lpthread -lm -lgcc" \
  sh ./configure ${BUILD_OPT} || exit 1
  ${make_program} -j${threads} && ${make_program} install || exit 1
}

if [[ `uname` != Linux ]]; then
  check_dependencies || exit 1
fi

download_ffmpeg || exit 1

if [[ $enable_x264 == 1 ]]; then
  build_x264 || exit 1
fi
if [[ $enable_x265 == 1 ]]; then
  build_x265 || exit 1
fi
if [[ $enable_dav1d == 1 ]]; then
  build_dav1d || exit 1
fi
if [[ $enable_fdkaac == 1 ]]; then
  build_fdkaac || exit 1
fi

build_ffmpeg || exit 1

cd $current_dir
echo "FFmpeg has been installed to $work_dir/ffmpeg_build successfully."
echo "You can uninstall it by removing $work_dir."
