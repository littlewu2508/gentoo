# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake rocm

DESCRIPTION="ROCm Communication Collectives Library (RCCL)"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/rccl"
SRC_URI="https://github.com/ROCmSoftwarePlatform/rccl/archive/rocm-${PV}.tar.gz -> rccl-${PV}.tar.gz"

LICENSE="BSD"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"
IUSE="test"

RDEPEND="dev-util/hip
dev-util/rocm-smi:${SLOT}"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-util/cmake-3.22
	>=dev-util/rocm-cmake-5.0.2-r1
	test? ( dev-cpp/gtest )"

RESTRICT="!test? ( test )"
S="${WORKDIR}/rccl-rocm-${PV}"

PATCHES=(
	"${FILESDIR}/${PN}-5.0.2-change_install_location.patch"
	"${FILESDIR}/${PN}-5.1.3-remove-chrpath.patch"
)

src_configure() {
	local mycmakeargs=(
	-DBUILD_TESTS=$(usex test ON OFF)
		-Wno-dev
	)

	rocm-configure
}

src_test() {
	LD_LIBRARY_PATH="${BUILD_DIR}" rocm-test test/UnitTests
}
