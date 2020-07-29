## ffmpeg-setup

A script to download and (cross-)compile ffmpeg under msys2/*nix.

Dependencies:

```
autoconf automake make cmake pkg-config nasm libtool
```

dav1d needs `meson ninja`

ffplay needs `libsdl2-dev`


### External libraries

* libx264
* libx265
* libdav1d
* libmp3lame
* libfdk-aac

### System libraries

* libopus
* libvmaf

### Known Issues

- [x] cannot cross-compile libx265
