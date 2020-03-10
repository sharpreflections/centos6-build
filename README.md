# centos6-build
CentOS6 based image

Includes:
- several cmake versions under /opt
- GCC
  - 4.4.7 (system)
  - 4.8.5
  - 5.5.0
- Qt 5
  - 5.9.9
  - 5.14.1 (No X11Extras)
- QtWebkit 5.212
  - for Qt 5.9.9
  - for Qt 5.14.1
- Protobuf
  - 3.0
  - 3.5
- updated binutils
- some development tools

Use the supplied *build\_qt\_qtwebkit\_icc19.sh* to compile a new Qt 5.9.9 and
QtWebkit using the Intel Compiler. It will use docker by default, but you can
also set it to use podman.

The result is the image **sharpreflections/centos6-build-qt:qt-5.9.9\_icc-19.0**
This image should then be pushed to docker.io and a rebuild of **centos6-build**
should be triggered, so it includes the latest build
