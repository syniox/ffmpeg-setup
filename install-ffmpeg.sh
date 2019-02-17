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
install_dependencies=""
threads="2"


if test x"$1" = x"-h" -o x"$1" = x"--help" ; then
cat <<EOF
Usage: ./install-ffmpeg.sh [options]
Help:
  -h, --help           print this message
  -i                   install dependencies automatically
  -t=<int>(default:2)  set the number of threads in compilation
EOF
exit 1
fi

check_opt(){
  for opt do
    optarg="${opt#*=}"
    case "$opt" in 
      i)
        install_dependencies="true"
        ;;
      t=*)
        threads="$optarg"
        ;;
      *)
        echo "Unknown option $opt, stopped."
        ;;
    esac
  done
}

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
  if [ -f "n4.1.tar.gz" ]; then
    :
  else 
    echo "Downloading FFmpeg 4.1."
    wget --no-verbose \
      "https://github.com/FFmpeg/FFmpeg/archive/n4.1.tar.gz" \
      || exit 1
    echo "Downloaded FFmpeg 4.1."
  fi
  if [ -n "$ffmpeg_dir" ]; then
    echo "FFmpeg exists."
  else
    tar -xzf n4.1.tar.gz || exit 1
    echo "Unpacked FFmpeg."
    ffmpeg_dir=$( ls -l | grep '^d' | grep FF | awk '{ print $9 }' )
  fi
}


download_resources(){
  cd $work_dir/ffmpeg_sources

  if [ -f "last_x264.tar.bz2" ]; then
    :
  else
    echo "Downloading x264 library."
    wget --no-verbose \
      "ftp://ftp.videolan.org/pub/x264/snapshots/last_x264.tar.bz2" \
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

  if [ -f "x265_3.0.tar.gz" ]; then
    :
  else
    echo "Downloading x265 library."
    wget --no-verbose \
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

  if [ -f "fdk_aac-v2.0.0.tar.gz" ]; then
    :
  else
    echo "Downloading fdk-aac library."
    wget --no-verbose -O fdk_aac-v2.0.0.tar.gz \
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
  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x264.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x264_dir
    sh ./configure \
      --prefix=$work_dir/ffmpeg_build \
      --enable-shared \
      --enable-pic \
      --enable-lto || exit 1
    mingw32-make -j${threads} && mingw32-make install || exit 1
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/x265.pc" ]; then
    cd $work_dir/ffmpeg_sources/$x265_dir/source
    cmake -G "MinGW Makefiles" \
      -DCMAKE_MAKE_PROGRAM=mingw32-make \
      -DENABLE_SHARED=on \
      -DCMAKE_INSTALL_PREFIX="$work_dir/ffmpeg_build" \
      . || exit 1
    mingw32-make -j${threads} && mingw32-make install || exit 1
  fi

  if [ ! -f "$work_dir/ffmpeg_build/lib/pkgconfig/fdk-aac.pc" ]; then
    cd $work_dir/ffmpeg_sources/$fdkaac_dir
    autoreconf -fi 
    sh ./configure \
      --prefix=$work_dir/ffmpeg_build \
      --enable-shared || exit 1
    mingw32-make -j${threads} && mingw32-make install || exit 1
  fi

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
    --libdir="$work_dir/ffmpeg_build/bin" \
    --disable-static \
    --enable-shared \
    --disable-hwaccels \
    --disable-filters \
    --disable-network \
    --disable-bsfs \
    --enable-filter=subtitles,scale \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libx264 \
    --enable-libx265 \
    --enable-decoder=h264,hevc \
    --enable-encoder=libx265,libx264
  mingw32-make -j${threads} && mingw32-make install || exit 1
}


check_opt || exit 1
check_dependencies || exit 1
download_ffmpeg || exit 1
download_resources || exit 1
build_resources || exit 1
build_ffmpeg || exit 1

cd $current_dir
echo "FFmpeg has been installed to $work_dir/ffmpeg_build successfully."
echo "You can uninstall it by removing $work_dir."
