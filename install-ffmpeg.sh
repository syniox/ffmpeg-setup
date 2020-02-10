#!/bin/bash

current_dir=$( pwd )
work_dir=$(cd $(dirname $0); pwd)
static_lib=0
threads="2"
cross_compile=0
cross_prefix=x86_64-w64-mingw32-
cross_root=/usr/x86_64-w64-mingw32
c_compiler=${cross_prefix}gcc
cxx_compiler=${cross_prefix}g++
filters=aresample,resize,psnr,ssim,scale
decoders=aac,flac,h264,hevc,mjpeg,mp3,opus,png,rawvideo,vp9,yuv4
encoders=aac,mjpeg,rawvideo,wrapped_avframe,pcm_s16le

cd $work_dir && mkdir -p ffmpeg_sources
ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
cd ffmpeg_sources
vmaf_dir=$( ls -l | grep '^d' | grep vmaf | awk '{ print $9 }' )
x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
dav1d_dir=$( ls -l | grep '^d' | grep dav1d | awk '{ print $9 }' )
lame_dir=$( ls -l | grep '^d' | grep lame | awk '{ print $9 }' )
fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )


build_opt="
  --prefix=/
  --pkg-config-flags=--static
  --disable-debug
  --disable-hwaccels
  --disable-filters
  --disable-bsfs
  --disable-muxers
  --enable-muxer=flac,ico,matroska,mjpeg,mp3,mp4,null,rawvideo,wav,yuv4mpegpipe
  --enable-gpl
  --disable-decoders
  --disable-encoders
"

# CMAKE_SYSTEM_NAME: fix -rdynamic
# For x265: DCMAKE_RANLIB=${cross_prefix}ranlib could cause link error?
cmake_cross_command="
  -DCMAKE_SYSTEM_NAME=Windows
  -DCMAKE_FIND_ROOT_PATH=$cross_root
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
  -DCMAKE_C_COMPILER=$c_compiler
  -DCMAKE_CXX_COMPILER=$cxx_compiler
  -DCMAKE_RC_COMPILER=${cross_prefix}windres
"

make_install(){
  $make_program -j$threads || exit 1
  $make_program install DESTDIR=$work_dir/ffmpeg_build || exit 1
}

generic_configure(){
  opt="$1 --prefix=/ --with-pic=yes --enable-shared=no"
  if [ $cross_compile == 1 ]; then
    opt+="--host=x86_64-w64-mingw32 CC=$c_compiler CXX=$cxx_compiler"
  fi
  ./configure $opt
}

download_ffmpeg(){
  cd $work_dir
  if [ ! -f "n4.2.2.tar.gz" ]; then
    echo "Downloading FFmpeg 4.2.2"
    wget -c \
      "https://github.com/FFmpeg/FFmpeg/archive/n4.2.2.tar.gz" \
      || exit 1
    echo "Downloaded FFmpeg 4.2.2"
  fi
  if [ -n "$ffmpeg_dir" ]; then
    echo "FFmpeg exists."
  else
    tar -xzf n4.2.2.tar.gz || exit 1
    echo "Unpacked FFmpeg."
    ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
  fi
}

build_x264(){
  cd $work_dir/ffmpeg_sources

  wget -c \
    "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.gz" \
    || exit 1
  if [ ! -n "$x264_dir" ]; then
    tar -xzf x264-master.tar.gz || exit 1
    echo "Unpacked x264 library."
    x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x264.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x264_dir
    local opt="
      --prefix=/ --enable-static
      --enable-lto --enable-pic
      --disable-avs --disable-opencl
    "
    if [ $cross_compile == 1 ]; then
      opt="$opt
        --cross-prefix=$cross_prefix
        --host=x86_64-w64-mingw32
      "
    fi
    ./configure $opt || exit 1
    make_install
  fi
}

build_x265(){
  cd $work_dir/ffmpeg_sources

  wget -c \
    "http://ftp.videolan.org/videolan/x265/x265_3.2.1.tar.gz" \
    || exit 1
  if [ ! -n "$x265_dir" ]; then
    tar -xzf x265_3.0.tar.gz || exit 1
    x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x265.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x265_dir/source
    rm -rf build && mkdir build && cd build
    local cmake_command="
      -DCMAKE_INSTALL_PREFIX=/
      -DCMAKE_MAKE_PROGRAM=$make_program
      -DENABLE_SHARED=0
    "
    if [ $cross_compile == 1 ]; then
      cmake_command="$cmake_command $cmake_cross_command"
    fi
    cmake -G "Unix Makefiles" $cmake_command .. || exit 1
    make_install
  fi
}

build_dav1d(){
  mkdir -p $work_dir/ffmpeg_build
  mkdir -p $work_dir/ffmpeg_build/lib
  mkdir -p $work_dir/ffmpeg_build/lib/pkgconfig

  cd $work_dir/ffmpeg_sources
  wget -c -O dav1d-0.5.2.tar.gz \
    "https://github.com/videolan/dav1d/archive/0.5.2.tar.gz" \
    || exit 1
  if [ ! -n "$dav1d_dir" ]; then
    tar -xzf dav1d-0.5.2.tar.gz || exit 1
    echo "Unpacked dav1d library."
    dav1d_dir=$( ls -l | grep '^d' | grep dav1d | awk '{ print $9 }' )
  fi

  cd $dav1d_dir
  if [ ! -f build/src/libdav1d.a ]; then
    meson build -Ddefault_library=static \
      -Denable_tests=false || exit 1
    ninja -C build || exit 1
  fi
  cp build/src/libdav1d.a $work_dir/ffmpeg_build/lib || exit 1
  cp -r include/dav1d $work_dir/ffmpeg_build/include || exit 1
  cp -r build/include/dav1d $work_dir/ffmpeg_build/include || exit 1

  cd $work_dir
  echo "prefix=$work_dir/ffmpeg_build" > dav1d.pc
  cat _dav1d.pc >> dav1d.pc
  mv dav1d.pc $work_dir/ffmpeg_build/lib/pkgconfig
}

build_lame(){
  cd $work_dir/ffmpeg_sources

  if [ ! -f "lame-3.100.tar.gz" ]; then
    wget -O lame-3.100.tar.gz \
      "https://sourceforge.net/projects/lame/files/latest/download" \
      || exit 1
  fi
  if [ ! -n "$lame_dir" ]; then
    tar -xzf lame-3.100.tar.gz || exit 1
    lame_dir=$( ls -l | grep '^d' | grep lame | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/libmp3lame.a" ]; then
    cd $work_dir/ffmpeg_sources/$lame_dir
    generic_configure "--enable-nasm" || exit 1
    make_install
  fi
}

build_fdkaac(){
  cd $work_dir/ffmpeg_sources

  wget -c -O fdk-aac-v2.0.1.tar.gz \
    "https://nchc.dl.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-2.0.1.tar.gz" \
    || exit 1
  if [ ! -n "$fdkaac_dir" ]; then
    tar -xzf fdk-aac-v2.0.1.tar.gz || exit 1
    echo "Unpacked fdkaac library."
    fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/fdk-aac.pc" ]; then
    cd $work_dir/ffmpeg_sources/$fdkaac_dir
    autoreconf -fi 
	generic_configure || exit 1
    make_install
  fi
}

build_vmaf(){
  cd $work_dir/ffmpeg_sources
  wget -c -O vmaf-1.3.15.tar.gz \
    https://github.com/Netflix/vmaf/archive/v1.3.15.tar.gz \
    || exit 1

  if [ ! -n $vmaf_dif ]; then
    tar -xzf vmaf-1.3.15.tar.gz || exit 1
    vmaf_dir=$( ls -l | grep '^d' | grep vmaf | awk '{ print $9 }' )
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/libvmaf.pc" ]; then
    cd $work_dir/ffmpeg_sources/$vmaf_dir
    make -j$threads && make DESTDIR="$work_dir/temp" install
    cp -r "$work_dir/temp/usr/local/*" "$work_dir/ffmpeg_build/"
    rm -r "$work_dir/temp"
  fi
}

build_ffmpeg(){
  cd $work_dir/$ffmpeg_dir
  if [[ $static_lib == 1 ]]; then
    build_opt+=" --disable-shared --enable-static"
  else
    build_opt+=" --enable-shared --disable-static"
  fi
  build_opt+=" --enable-filter=$filters"
  build_opt+=" --enable-decoder=$decoders"
  build_opt+=" --enable-encoder=$encoders"
  if [ $cross_compile == 1 ]; then
    build_opt="$build_opt
      --arch=x86_64
      --target-os=mingw32
      --cross-prefix=$cross_prefix
    "
  fi
  echo $build_opt
  echo configuring...
  PKG_CONFIG_PATH="$work_dir/ffmpeg_build/lib/pkgconfig" \
  CFLAGS="-I$work_dir/ffmpeg_build/include" \
  LDFLAGS="-L$work_dir/ffmpeg_build/lib" \
  LIBS="-lpthread -lm -lgcc" \
  bash ./configure $build_opt || exit 1
  make_install
  if [ $static_lib == 0 ]; then
    cp $work_dir/ffmpeg_build/lib/*.dll $work_dir/ffmpeg_build/bin/
  fi
  return 0
}

# some problems occured when compiling with mingw32-make, use make for msys2 at the moment
make_program=make

if test x"$1" = x"-h" -o x"$1" = x"--help" ; then
cat <<EOF
Usage: $0 [options]
Help:
  -h, --help           print this message
  -t=<int>(default:2)  set the number of threads in compilation
  -x                   build static library (default: shared)
  --cross-compile      cross compile ffmpeg for windows (default:native)
  --libx264            include x264 library (default disabled)
  --libx265            include x265 library (default disabled)
  --libdav1d           include dav1d library (default disabled)
  --libmp3lame         include mp3lame library (default disabled)
  --libfdk-aac         include fdkaac library (default disabled)
  --sys-libopus        include system opus library (default disabled)
  --sys-libvmaf        include system vmaf library (default disabled)
EOF
exit 1
fi

for opt do
  optarg="${opt#*=}"
  case "$opt" in 
    -t=*)
      threads="$optarg"
      ;;
    -x)
      static_lib=1
      ;;
    --cross-compile)
      cross_compile=1
      ;;
    --libx264)
      echo "x264 enabled."
      build_opt+=" --enable-libx264"
      encoders+=",libx264"
      enable_x264=1
      ;;
    --libx265)
      echo "x265 enabled."
      build_opt+=" --enable-libx265"
      encoders+=",libx265"
      enable_x265=1
      ;;
    --libdav1d)
      echo "dav1d enabled."
      build_opt+=" --enable-libdav1d"
      decoders+=",libdav1d"
      enable_dav1d=1
      ;;
    --libfdk-aac)
      echo "fdkaac enabled."
      build_opt+=" --enable-libfdk-aac --enable-nonfree "
      encoders+=",libfdk_aac"
      enable_fdkaac=1
      ;;
    --libmp3lame)
      echo "mp3lame enabled."
      build_opt+=" --enable-libmp3lame"
      encoders+=",libmp3lame"
      enable_mp3lame=1
      ;;
    --sys-libvmaf)
      echo "vmaf enabled."
      build_opt+=" --enable-libvmaf --enable-version3"
      filters+=",libvmaf"
      ;;
    --sys-libopus)
      echo "opus enabled."
      build_opt+=" --enable-libopus"
      encoders+=",libopus"
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

download_ffmpeg || exit 1

echo "configuring dependencies..."

if [[ $enable_x264 == 1 ]]; then
  build_x264 || exit 1
fi
if [[ $enable_x265 == 1 ]]; then
  build_x265 || exit 1
fi
if [[ $enable_dav1d == 1 ]]; then
  build_dav1d || exit 1
fi
if [[ $enable_mp3lame == 1 ]]; then
  build_lame || exit 1
fi
if [[ $enable_fdkaac == 1 ]]; then
  build_fdkaac || exit 1
fi

build_ffmpeg || exit 1

cd $current_dir
echo "FFmpeg has been installed to $work_dir/ffmpeg_build successfully."
echo "You can uninstall it by removing $work_dir."
