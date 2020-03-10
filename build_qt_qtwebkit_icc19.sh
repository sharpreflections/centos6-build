#!/bin/bash

print_help() {
cat << EOF
Usage: $0 --icc19 <DIR> --license <DIR>

Options:
 --icc19 <DIR>    DIR is the root of the Intel Compiler installation
 --license <DIR>  DIR is the directory containing the compiler license file
 --podman         Use podman instead of docker
EOF

  exit 0
}

# Return the path to the requested runtime if called with argument,
# fall back to docker and podman if not
get_container_runtime() {
  if [ -n "$1" ]; then
    runtime=$(which "$1" 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo "$runtime"
      exit 0
    fi
    (>&2 echo "Container runtime '"$1"' not found, falling back!")
  fi

  runtime=$(which docker 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "$runtime"
    exit 0
  fi
  runtime=$(which podman 2> /dev/null)
  if [ $? -ne 0]; then
    (>&2 echo "No container runtime found!")
    exit 1
  fi
  echo "$runtime"
}

# Pre-populate, should point to docker or to podman
runtime="$(get_container_runtime)"

while [ $# -gt 0 ]; do
  case "$1" in
    --icc19)   INTEL_DIR="$2";;
    --license) LIC_DIR="$2";;
    --podman) runtime="$(get_container_runtime podman)";;
  esac
  shift
done

if [ -z "$INTEL_DIR" ] || [ -z "$LIC_DIR" ]; then
  print_help
fi


if [ -z "$runtime" ]; then
  (>&2 echo "Could not locate container runtime!")
  exit 2
fi

gcc=gcc-4.8.5
icc=icc-19.0
qt_major=5.9
qt_minor=.9
qt_version=${qt_major}${qt_minor}
qt_string=qt-everywhere-opensource-src
prefix=/opt
PATH=$prefix/qt-${qt_version}-icc19/bin:$prefix/$icc/bin:$prefix/$gcc/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin
LD_LIBRARY_PATH=$prefix/$icc/compilers_and_libraries/linux/lib/intel64_lin/:$prefix/$gcc/lib64

mounts="$INTEL_DIR:/opt/icc-19.0
        $LIC_DIR:/root/Licenses"

envs="gcc=$gcc
      icc=$icc
      qt_major=$qt_major
      qt_minor=$qt_minor
      qt_version=$qt_version
      qt_string=$qt_string
      prefix=$prefix
      PATH=$PATH
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH
      CC=icc
      CXX=icpc"

for mount in $mounts; do
  MOUNT="$MOUNT --volume $mount"
done

for env in $envs; do
  ENV="$ENV --env $env"
done


$runtime run $ENV $MOUNT --interactive --tty --name centos6-build-qt-icc19 sharpreflections/centos6-build bash -c "
set -e

yum -y install xz glibc-headers glibc-devel mesa-libGL-devel mesa-libEGL-devel openssl-devel

cd /build
echo \"Downloading Qt5 ${qt_version}:\"
  curl --remote-name --location --progress-bar http://download.qt.io/official_releases/qt/${qt_major}/${qt_version}/single/${qt_string}-${qt_version}.tar.xz
  curl --remote-name --location --silent http://download.qt.io/official_releases/qt/${qt_major}/${qt_version}/single/md5sums.txt
  sed --in-place '/.*\.zip/d' md5sums.txt

echo -n \"Verifying file..\"
  md5sum --quiet --check md5sums.txt
echo \" done\"

echo -n \"Extracting qt5.. \"
  tar xf ${qt_string}-${qt_version}.tar.xz
echo \" done\"

mkdir build && cd build 
../${qt_string}-${qt_version}/configure --prefix=${prefix}/qt-${qt_version}-icc19 \
                -opensource -confirm-license \
                -shared                      \
                -c++std c++11                \
                -platform linux-icc-64       \
                -ssl                         \
                -qt-zlib                     \
                -qt-libjpeg                  \
                -qt-libpng                   \
                -nomake examples             \
                -nomake tests                \
                -no-rpath                    \
                -no-cups                     \
                -no-iconv                    \
                -no-dbus                     \
                -no-gtk                      \
                -no-glib

make --jobs=$(nproc --all)
make install
rm -rf /build/*

########################################
# QtWebkit
########################################

yum -y install centos-release-scl
yum -y install gperf python27 rh-ruby23 mesa-libGL-devel sqlite-devel libjpeg-turbo-devel zlib-devel \
               libpng-devel libxml2-devel hyphen-devel libicu-devel libXcomposite-devel libXrender-devel
cd /build
git clone https://code.qt.io/qt/qtwebkit.git
cd qtwebkit
git checkout --track origin/5.212
mkdir /build/qtwebkit/build
cd /build/qtwebkit/build
set -x

# 2.8.0 only contains bug fixes according to the changelog, so 2.7.0 might also be fine
sed --in-place 's/\(find_package(LibXml2\) 2.8.0/\1 2.7.0/' ../Source/cmake/OptionsQt.cmake

# Some include is missing
sed --in-place '/Modules\/mediasession$/aModules\/mediasource/' ../Source/WebCore/CMakeLists.txt

# new in ICU 4.4, but we are only at 4.2. It's basically about character comparison which we don't care about
sed --in-place 's/USEARCH_STANDARD_ELEMENT_COMPARISON/USEARCH_ON/'          ../Source/WebCore/editing/TextIterator.cpp
sed --in-place 's/USEARCH_PATTERN_BASE_WEIGHT_IS_WILDCARD/USEARCH_ON/'      ../Source/WebCore/editing/TextIterator.cpp
sed --in-place 's/USEARCH_ELEMENT_COMPARISON/(USearchAttribute)USEARCH_ON/' ../Source/WebCore/editing/TextIterator.cpp

# Our ICU does not know that linebreak char, so purge it
sed --in-place '/U_LB_CLOSE_PARENTHESIS/d'                    ../Source/WebCore/rendering/RenderRubyText.cpp

# Something with overdrawing special characters which we most likely don't need to support
sed --in-place '/UBLOCK_CJK_UNIFIED_IDEOGRAPHS_EXTENSION_C/d' ../Source/WebCore/platform/graphics/FontCascade.cpp
sed --in-place '/UBLOCK_CJK_UNIFIED_IDEOGRAPHS_EXTENSION_D/d' ../Source/WebCore/platform/graphics/FontCascade.cpp
sed --in-place '/UBLOCK_ENCLOSED_IDEOGRAPHIC_SUPPLEMENT/d'    ../Source/WebCore/platform/graphics/FontCascade.cpp
sed --in-place '/UBLOCK_HANGUL_JAMO_EXTENDED_A/d'             ../Source/WebCore/platform/graphics/FontCascade.cpp
sed --in-place '/UBLOCK_HANGUL_JAMO_EXTENDED_B/d'             ../Source/WebCore/platform/graphics/FontCascade.cpp

# Added with ICU 4.6 - number format symbols
sed --in-place '/UNUM_ONE_DIGIT_SYMBOL/d'   ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_TWO_DIGIT_SYMBOL/d'   ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_THREE_DIGIT_SYMBOL/d' ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_FOUR_DIGIT_SYMBOL/d'  ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_FIVE_DIGIT_SYMBOL/d'  ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_SIX_DIGIT_SYMBOL/d'   ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_SEVEN_DIGIT_SYMBOL/d' ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_EIGHT_DIGIT_SYMBOL/d' ../Source/WebCore/platform/text/LocaleICU.cpp
sed --in-place '/UNUM_NINE_DIGIT_SYMBOL/d'  ../Source/WebCore/platform/text/LocaleICU.cpp

# Fix build since the macro USE_EXPORT_MACROS is not being defined empty as it should be, which in case should define
# WEBCORE_EXPORT empty. Yet, it does not work globally
sed --in-place '/#include <wtf\/Compiler.h>/a#define USE_EXPORT_MACROS 1' ../Source/WTF/wtf/text/WTFString.h

# I did not find the common source to set it for all
sed --in-place '/#include <wtf\/text\/WTFString.h>/a#define WEBCORE_EXPORT'  ../Source/WebCore/platform/FileSystem.h
sed --in-place '/#include <wtf\/Vector.h>/a#define WEBCORE_EXPORT'           ../Source/WebCore/platform/Timer.h
sed --in-place '/#include <wtf\/text\/WTFString.h>/a#define WEBCORE_EXPORT'  ../Source/WebCore/platform/sql/SQLiteDatabase.h
sed --in-place '/#include <wtf\/RefPtr.h>/a#define WEBCORE_EXPORT'           ../Source/WebCore/page/DatabaseProvider.h
sed --in-place '/#include <wtf\/Vector.h>/a#define WEBCORE_EXPORT'           ../Source/WebCore/loader/LoaderStrategy.h

sed --in-place '/#include <wtf\/text\/StringHash.h>/a#define WEBCORE_EXPORT' ../Source/WebCore/platform/LinkHash.h
#sed --in-place '/#include <wtf\/RefCounted.h>/a#define WEBCORE_EXPORT'       ../Source/WebCore/page/VisitedLinkStore.h

# ASSERT() is expanded although it should not on release builds..
sed --in-place '/ASSERT(/d' ../Source/WebCore/platform/network/ResourceLoadPriority.h

# This happens because we use system malloc and something in QtWebkit is broken
sed --in-place '/WTF_MAKE_FAST_ALLOCATED;/d' ../Source/WTF/wtf/Lock.h

# Missing include, uint8_t needs <cstdint>
sed --in-place '/#include \"ResourceHandleTypes.h\"/a#include <cstdint>' ../Source/WebCore/loader/ResourceLoaderOptions.h

# Fix Qt private include paths
sed --in-place 's:\(set(Qt5Gui_PRIVATE_INCLUDE_DIRS\) \"\"):\1 \"\$\{_qt5Gui_install_prefix\}/include/QtGui/\$\{Qt5Gui_VERSION_STRING\}\" \"\$\{_qt5Gui_install_prefix\}/include/QtGui/\$\{Qt5Gui_VERSION_STRING\}/QtGui\"):' $prefix/qt-${qt_major}${qt_minor}-icc19/lib/cmake/Qt5Gui/Qt5GuiConfig.cmake
sed --in-place 's:\(set(Qt5Core_PRIVATE_INCLUDE_DIRS\) \"\"):\1 \"\$\{_qt5Core_install_prefix\}/include/QtCore/\$\{Qt5Core_VERSION_STRING\}\" \"\$\{_qt5Core_install_prefix\}/include/QtCore/\$\{Qt5Core_VERSION_STRING\}/QtCore\"):' $prefix/qt-${qt_major}${qt_minor}-icc19/lib/cmake/Qt5Core/Qt5CoreConfig.cmake

# Fix build with intel compilers
sed --in-place 's/\(if (NOT MSVC\).*/\1 AND NOT \$\{CMAKE_CXX_COMPILER_ID\} STREQUAL Intel)/' ../Source/cmake/OptionsCommon.cmake

# This sets PATH and LD_LIBRARY_PATH accordingly to use the scl
source /opt/rh/rh-ruby23/enable
source /opt/rh/python27/enable

# we don't care about the warnings and they clutter the output too much. It's hard to find errors among the warnigns
export CXXFLAGS=-w

/opt/cmake-3.11.4/bin/cmake .. -DPORT=Qt \
                               -DQt5_DIR=/opt/qt-${qt_version}-icc19/lib/cmake/Qt5 \
                               -DCMAKE_INSTALL_PREFIX=/opt/qt-${qt_version}-icc19  \
                               -DCMAKE_PREFIX_PATH='/opt/rh/python27/root/usr/;/opt/rh/rh-ruby23/root/usr/' \
                               -DENABLE_ACCELERATED_2D_CANVAS:BOOL=OFF\
                               -DENABLE_API_TESTS:BOOL=OFF            \
                               -DENABLE_CSS_GRID_LAYOUT:BOOL=OFF      \
                               -DENABLE_DATABASE_PROCESS:BOOL=OFF     \
                               -DENABLE_DEVICE_ORIENTATION:BOOL=OFF   \
                               -DENABLE_DRAG_SUPPORT:BOOL=OFF         \
                               -DENABLE_FULLSCREEN_API:BOOL=OFF       \
                               -DENABLE_GAMEPAD_DEPRECATED:BOOL=OFF   \
                               -DENABLE_GEOLOCATION:BOOL=OFF          \
                               -DENABLE_ICONDATABASE:BOOL=OFF         \
                               -DENABLE_INDEXED_DATABASE:BOOL=OFF     \
                               -DENABLE_INSPECTOR_UI:BOOL=OFF         \
                               -DENABLE_JIT:BOOL=OFF                  \
                               -DENABLE_LEGACY_WEB_AUDIO:BOOL=OFF     \
                               -DENABLE_NETSCAPE_PLUGIN_API:BOOL=OFF  \
                               -DENABLE_OPENGL:BOOL=OFF               \
                               -DENABLE_PRINT_SUPPORT:BOOL=OFF        \
                               -DENABLE_SAMPLING_PROFILER:BOOL=OFF    \
                               -DENABLE_SPELLCHECK:BOOL=OFF           \
                               -DENABLE_TOUCH_EVENTS:BOOL=OFF         \
                               -DENABLE_VIDEO:BOOL=OFF                \
                               -DENABLE_WEBKIT2:BOOL=OFF              \
                               -DENABLE_XSLT:BOOL=OFF                 \
                               -DUSE_GSTREAMER:BOOL=OFF               \
                               -DUSE_LIBHYPHEN:BOOL=OFF               \
                               -DENABLE_INTL:BOOL=OFF                 \
                               -DUSE_SYSTEM_MALLOC:BOOL=ON            \
                               -DUSE_WOFF2:BOOL=OFF                   \
                               -DCMAKE_BUILD_TYPE=Release         

# be conservative - some source files are huge and ICC19 can take 6GB/job easily
make --jobs=2
make install && rm -rf /build/*
"

podman commit centos6-build-qt-icc19 sharpreflections/centos6-build-qt:qt-5.9.9_icc-19.0

