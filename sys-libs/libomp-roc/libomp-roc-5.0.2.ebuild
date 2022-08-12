# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_ECLASS=cmake
PYTHON_COMPAT=( python3_{8..10} )
inherit cmake

DESCRIPTION="Radeon Open Compute OpenMP runtime library for LLVM/clang"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCm"
SRC_URI="https://github.com/RadeonOpenCompute/llvm-project/archive/rocm-${PV}.tar.gz -> llvm-rocm-ocl-${PV}.tar.gz
		https://github.com/RadeonOpenCompute/ROCm-Device-Libs/archive/rocm-rocm-device-libs.tar.gz -> rocm-device-libs-${PV}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="debug"
RESTRICT="test"

RDEPEND="sys-devel/llvm-roc[runtime]"
DEPEND="${RDEPEND}"
S="${WORKDIR}/llvm-project-rocm-${PV}/openmp"

src_prepare() {
	mv "${WORKDIR}"/ROCm-Device-Libs-rocm-${PV} "${WORKDIR}"/rocm-device-libs || die
	cmake_src_prepare
}

src_configure() {
	use debug || local -x CPPFLAGS="${CPPFLAGS} -DNDEBUG"

	local mycmakeargs=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/lib/llvm/roc"
		-DLLVM_DIR="${EPREFIX}/usr/lib/llvm/roc/lib/cmake/llvm"
		-DOPENMP_ENABLE_LIBOMPTARGET=offload
		# do not install libgomp.so & libiomp5.so aliases
		-DLIBOMP_INSTALL_ALIASES=OFF
		# disable unnecessary hack copying stuff back to srcdir
		-DLIBOMP_COPY_EXPORTS=OFF
		-DLIBOMPTARGET_BUILD_AMDGCN_BCLIB=ON
		-DCMAKE_DISABLE_FIND_PACKAGE_CUDA=ON
		-DLIBOMPTARGET_BUILD_NVPTX_BCLIB=OFF
		-DOPENMP_ENABLE_LIBOMPTARGET_HSA=ON
	)

	cmake_src_configure
}
