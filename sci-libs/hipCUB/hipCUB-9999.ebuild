# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=${PV}

inherit cmake rocm

DESCRIPTION="Wrapper of rocPRIM or CUB for GPU parallel primitives"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/hipCUB"
if [[ ${PV} == *9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ROCmSoftwarePlatform/hipCUB.git"
	S="${WORKDIR}/${P}"
else
	S="${WORKDIR}/${PN}-rocm-${PV}"
	SRC_URI="https://github.com/ROCmSoftwarePlatform/hipCUB/archive/rocm-${PV}.tar.gz -> hipCUB-${PV}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="BSD"
SLOT="0/$(ver_cut 1-2)"
IUSE="benchmark test"
REQUIRED_USE="${ROCM_REQUIRED_USE}"
RESTRICT="!test? ( test )"

RDEPEND="dev-util/hip
	sci-libs/rocPRIM:${SLOT}[${ROCM_USEDEP}]
	benchmark? ( dev-cpp/benchmark )
	test? ( dev-cpp/gtest )
"
DEPEND="${RDEPEND}"

PATCHES="${FILESDIR}/${PN}-4.3.0-add-memory-header.patch"

src_prepare() {
	sed	-e "s:\${ROCM_INSTALL_LIBDIR}:\${CMAKE_INSTALL_LIBDIR}:" -i cmake/ROCMExportTargetsHeaderOnly.cmake || die

	# do not install test files
	sed '/rocm_install(/ {:r;/)/!{N;br}; s,.*,,}' -i test/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	addpredict /dev/kfd
	addpredict /dev/dri/

	local mycmakeargs=(
		-DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF
		-DROCM_SYMLINK_LIBS=OFF
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-DBUILD_TEST=$(usex test ON OFF)
		-DBUILD_BENCHMARK=$(usex benchmark ON OFF)
	)

	CXX=hipcc cmake_src_configure
}

src_test() {
	check_amdgpu
	MAKEOPTS="-j1" cmake_src_test
}
