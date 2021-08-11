# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LICENSE="GPL-2 NVIDIA-r2"
SLOT="0/${PV%%.*}"
# TODO: for arm64, keyword virtual/opencl on arm64
IUSE="prefix"
KEYWORDS="-* ~amd64"

src_install () {
	if use prefix; then
        mkdir -p ${ED}/usr/lib64
        cd ${ED}/usr/lib64
        ln -s /lib64/libcuda.so
        ln -s /lib64/libcuda.so.1
        ln -s /lib64/libnvidia-ml.so.1
        ln -s /lib64/libnvidia-ptxjitcompiler.so.1
    fi
}
