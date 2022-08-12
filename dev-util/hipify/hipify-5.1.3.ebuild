# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Convert CUDA to Portable C++ Code"
HOMEPAGE="https://github.com/ROCm-Developer-Tools/HIPIFY"
SRC_URI="https://github.com/ROCm-Developer-Tools/HIPIFY/archive/refs/tags/rocm-5.1.3.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

S="${WORKDIR}"/${PN^^}-rocm-${PV}

PATCHES=( "${FILESDIR}"/${PN}-5.1.3-llvm-link.patch )

src_prepare() {
	sed -e "/DESTINATION/s,\${CMAKE_INSTALL_PREFIX},\${CMAKE_INSTALL_PREFIX}/bin,g" -i CMakeLists.txt || die
	cmake_src_prepare
}
