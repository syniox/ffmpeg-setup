current_dir=$( pwd )
work_dir=$(cd $(dirname $0); pwd)
cd $work_dir
ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
cd $work_dir && mkdir ffmpeg_sources > /dev/null 2>&1
cd ffmpeg_sources
x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )
# libass_dir=$( ls -l | grep '^d' | grep ass | awk '{ print $9 }' )

check_dependencies(){
  dependency_list=(
    "git"
    "tar"
    "diffutils"
    "mingw-w64-x86_64-gcc"
    "nasm"
    "wget"
    "pkg-config"
    "make"
    "cmake"
    "autoconf"
	"automake"
  )
  missing_dependencies=""
  install_dependencies=""

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
    echo "or add -i(not finished) option to install them automatically." >&2
    exit 1;
  fi
}

download_ffmpeg(){
  if [ -f "n4.1.tar.gz" ]; then
    :
  else 
    echo "Downloading FFmpeg 4.1..."
    wget --no-verbose \
    "https://github.com/FFmpeg/FFmpeg/archive/n4.1.tar.gz" \
	|| exit 1
  fi
  if [ -n "$ffmpeg_dir" ]; then
    echo "FFmpeg exists."
  else
    echo "Unpacking FFmpeg ..."
    tar -xzf n4.1.tar.gz || exit 1
    ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
  fi
}


download_resources(){
  cd ffmpeg_sources

  if [ -f "last_x264.tar.bz2" ]; then
    :
  else
    echo "Downloading x264 library..."
    wget --no-verbose \
      "ftp://ftp.videolan.org/pub/x264/snapshots/last_x264.tar.bz2" \
	  || exit 1
  fi
  if [ -n "$x264_dir" ]; then
    echo "x264 library exists."
  else
    echo "Unpacking x264 library..."
    tar -xjf last_x264.tar.bz2 || exit 1
    x264_dir=$( ls -l | grep '^d' | grep x264 | awk '{ print $9 }' )
  fi

  if [ -f "x265_2.9.tar.gz" ]; then
    :
  else
    echo "Downloading x265 library..."
    wget --no-verbose \
      "http://ftp.videolan.org/pub/videolan/x265/x265_2.9.tar.gz" \
	  || exit 1
  fi
  if [ -n "$x265_dir" ]; then
    echo "x265 library exists."
  else 
    echo "Unpacking x265 library..."
    tar -xzf x265_2.9.tar.gz || exit 1
    x265_dir=$( ls -l | grep '^d' | grep x265 | awk '{ print $9 }' )
  fi

  if [ -f "fdk_aac-v2.0.0.tar.gz" ]; then
    :
  else
    echo "Downloading fdk-aac library..."
    wget --no-verbose -O fdk_aac-v2.0.0.tar.gz \
      "https://github.com/mstorsjo/fdk-aac/archive/v2.0.0.tar.gz" \
      || exit 1
  fi
  if [[ -n "$fdkaac_dir" ]]; then
    echo "fdkaac library exists."
  else
    echo "Unpacking fdkaac library..."
    tar -xzf fdk_aac-v2.0.0.tar.gz || exit 1
    fdkaac_dir=$( ls -l | grep '^d' | grep fdk | awk '{ print $9 }' )
  fi

#  if [[ -f libass-0.14.0.tar.xz ]]; then
#    :
#  else
#    echo "Downloading ass library..."
#	wget --no-verbose \
#    "https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.xz" \
#	|| exit 1
#  fi
#  if [[ -n "$libass_dir" ]]; then
#    echo "ass library exists."
#  else
#	echo "Unpacking ass library..."
#	tar -xJf libass-0.14.0.tar.xz || exit 1
#	libass_dir=$( ls -l | grep '^d' | grep ass | awk '{ print $9 }' )
#  fi
}


build_resources(){
  if [ ! -f "$work_dir/ffmpeg_build/lib/libx264.a" ]; then
    cd $work_dir/ffmpeg_sources/$x264_dir
    sh ./configure \
      --prefix=$work_dir/ffmpeg_build \
      --enable-static \
      --enable-pic \
      --enable-lto || exit 1
    make -j2 && make install || exit 1
  fi

#  ln -s /mingw64/bin/windres.exe /mingw64/bin/x86_64-w64-mingw32-windres.exe
#  ln -s /mingw64/bin/ar.exe /mingw64/bin/x86_64-w64-mingw32-ar.exe
  cd $work_dir/ffmpeg_sources/$x265_dir/source
  cmake -G "MSYS Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=../build/msys/toolchain-x86_64-w64-mingw32.cmake \
    -DENABLE_SHARED=off \
    -DCMAKE_INSTALL_PREFIX="$work_dir/ffmpeg_build" \
    . || exit 1
  make -j2 && make install || exit 1

  cd $work_dir/ffmpeg_sources/$fdkaac_dir
  autoreconf -fiv 
  sh ./configure \
    --prefix=$work_dir/ffmpeg_build \
    --disable-shared || exit 1
  make -j2 && make install || exit 1

#  cd $work_dir/ffmpeg_sources/$libass_dir
#  autoreconf -fiv
#  sh ./configure \
#    --prefix=$work_dir/ffmpeg_build \
#	--enable-shared=no || exit 1
#  make -j2 && make install || exit 1
}

build_ffmpeg(){
  cd $work_dir/$ffmpeg_dir
  PKG_CONFIG_PATH="$work_dir/ffmpeg_build/lib/pkgconfig/" \
  sh ./configure \
    --prefix="$work_dir/ffmpeg_build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$work_dir/ffmpeg_build/include" \
    --extra-ldflags="-L$work_dir/ffmpeg_build/lib" \
    --extra-libs="-lpthread -lm" \
    --disable-decoders \
    --disable-encoders \
    --disable-hwaccels \
    --disable-avdevice \
    --disable-demuxers \
    --disable-muxers \
    --disable-protocols \
    --disable-parsers \
    --disable-filters \
    --disable-network \
    --disable-bsfs \
    --enable-filter=subtitles,scale \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libx264 \
    --enable-libx265 \
    --enable-demuxer=aac,ape,ass,avi,concat,flac,flv,gif,h264,hevc \
    --enable-demuxer=ico,srt,swf,m4v,mp3,ogg,wav \
    --enable-muxer=avi,flac,flv,gif,h264,hash,hevc,ico \
    --enable-muxer=m4v,md5,mov,mp3,mp4,ogg,srt,swf,sup,wav,webm \
    --enable-decoder=h264,hevc \
    --enable-encoder=libx265,libx264
  make -j2 && make install
}


check_dependencies || exit 1
download_ffmpeg || exit 1
download_resources || exit 1
build_resources || exit 1
build_ffmpeg || exit 1

cd $current_dir
echo "FFmpeg has been installed to $work_dir/ffmpeg_build successfully."

