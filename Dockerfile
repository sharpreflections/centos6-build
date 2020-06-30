FROM sharpreflections/centos6-build-binutils
LABEL maintainer="dennis.brendel@sharpreflections.com"

ARG gcc=gcc-4.8.5
ARG qt=qt-5.9.9-icc19
ARG cmake=cmake-3.11.4

ARG prefix=/opt

WORKDIR /

COPY --from=sharpreflections/centos6-build-cmake     $prefix $prefix
COPY --from=sharpreflections/centos6-build-protobuf  $prefix $prefix
COPY --from=sharpreflections/centos6-build-gcc:gcc-4.8.5 $prefix $prefix
COPY --from=sharpreflections/centos6-build-qt:qt-5.9.9_gcc-4.8.5 $prefix $prefix
COPY --from=sharpreflections/centos6-build-qt:qt-5.9.9_icc-19.0  $prefix $prefix

RUN yum -y install @development xorg-x11-server-utils libX11-devel libSM-devel libxml2-devel libGL-devel \
                   libGLU-devel libibverbs-devel freetype-devel libicu && \
    # we need some basic fonts and manpath for the mklvars.sh script
    yum -y install urw-fonts man && \
    # Requirements for using software collections and epel
    yum -y install yum-utils centos-release-scl.noarch epel-release.noarch && \
    # install the software collections
    yum -y install sclo-git212 sclo-subversion19 && \
    # Misc developer tools
    yum -y install strace valgrind bc joe vim nano mc && \
    yum clean all

