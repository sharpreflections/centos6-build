FROM sharpreflections/centos6-build-binutils
LABEL maintainer="dennis.brendel@sharpreflections.com"

ARG prefix=/opt

WORKDIR /

COPY --from=sharpreflections/centos6-build-cmake     $prefix $prefix
COPY --from=sharpreflections/centos6-build-protobuf  $prefix $prefix
COPY --from=sharpreflections/centos6-build-gcc:gcc-4.8.5 $prefix $prefix
COPY --from=sharpreflections/centos6-build-qt:qt-5.12.0_gcc-8.3.1 /p/ /p/
COPY --from=sharpreflections/centos6-build-qt:qt-5.12.0_icc-19.0  /p/ /p/

RUN yum -y install @development xorg-x11-server-utils libX11-devel libSM-devel libxml2-devel libGL-devel \
                   libGLU-devel mesa-libEGL libibverbs-devel freetype-devel libicu xkeyboard-config && \
    # we need some basic fonts and manpath for the mklvars.sh script
    yum -y install urw-fonts man && \
    # Requirements for using software collections and epel
    yum -y install yum-utils centos-release-scl.noarch epel-release.noarch && \
    # install the software collections
    yum -y install sclo-git212 sclo-subversion19 devtoolset-8 && \
    # Misc developer tools
    yum -y install strace valgrind bc joe vim nano mc && \
    yum clean all

