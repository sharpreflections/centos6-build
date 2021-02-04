FROM sharpreflections/centos6-build-binutils
LABEL maintainer="dennis.brendel@sharpreflections.com"

ARG prefix=/opt

WORKDIR /

COPY --from=sharpreflections/centos6-build-cmake     $prefix $prefix
COPY --from=sharpreflections/centos6-build-protobuf  $prefix $prefix
COPY --from=sharpreflections/centos6-build-gcc:gcc-4.8.5 $prefix $prefix

COPY --from=sharpreflections/centos6-build-gammaray /p/ /p/
COPY --from=sharpreflections/centos6-build-qt:qt-5.12.0_gcc-8.3.1 /p/ /p/
COPY --from=sharpreflections/centos6-build-qt:qt-5.12.0_icc-19.0  /p/ /p/

    # Requirements for using software collections and epel
RUN yum -y install yum-utils centos-release-scl.noarch epel-release.noarch && \
    # the repo files still point to the centos mirrorlist which is down
    sed --in-place '/mirrorlist.*/d;s,^# \(.*\)=.*,\1=http://vault.centos.org/centos/6/sclo/$basearch/sclo/,'  /etc/yum.repos.d/CentOS-SCLo-scl.repo && \
    sed --in-place '/mirrorlist.*/d;s,^#\(.*\)=.*,\1=http://vault.centos.org/centos/6/sclo/$basearch/rh/,'  /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo && \
    yum clean all

RUN yum -y install @development xorg-x11-server-utils libX11-devel libSM-devel libxml2-devel libGL-devel \
                   libGLU-devel mesa-libEGL libibverbs-devel freetype-devel libicu xkeyboard-config \
    # we need some basic fonts and manpath for the mklvars.sh script
                   urw-fonts man \
    # install the software collections
                   sclo-git212 sclo-subversion19 devtoolset-8 \
    # Misc developer tools and xvfb for running QTest
                   strace valgrind bc joe vim nano mc \
                   xorg-x11-server-Xvfb \
    # For building OSMesa
                   python-argparse \
    # GMP is needed for delaunyT
                   gmp-devel && \
    yum clean all

