### ffmpeg-setup

A script to download and compile ffmpeg for personal use.  
Only static build is available at the moment.  

Dependencies:

```
autoconf automake make cmake pkg-config nasm libtool
```

dav1d needs `meson ninja`

ffplay needs `libsdl2-dev`

External libraries:

* libx264
* libx265
* libdav1d
* libfdk-aac
