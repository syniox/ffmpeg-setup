#!/bin/bash

alllibs="x264 x265 dav1d fdk-aac"
work_dir="$(cd $(dirname $0); pwd)"
threads=2
# TODO: add static library support

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
            echo [Warning] Unused option: $opt;;
    esac
done

# Help processing
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

# Ensure libraries
echo [Info] exlibs: $exlibs
for exlib in $exlibs; do
    if [[ -z "$( ls plugins/$exlib.sh 2>/dev/null)" ]]; then
        invld_lib+=" $exlib"
    fi
done
if [[ -n "$invld_lib" ]]; then
    echo [Error] Invalid library finded: $invld_lib
    exit 1
fi
