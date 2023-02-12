# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=${PV}

inherit cmake edo rocm

DESCRIPTION="ROCm SPARSE marshalling library"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/hipSPARSE"
if [[ ${PV} == *9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ROCmSoftwarePlatform/hipSPARSE.git"
	S="${WORKDIR}/${P}"
else
	S="${WORKDIR}/${PN}-rocm-${PV}"
	SRC_URI="https://github.com/ROCmSoftwarePlatform/${PN}/archive/rocm-${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"/$(ver_cut 1-2)
IUSE="test"
REQUIRED_USE="${ROCM_REQUIRED_USE}"

RESTRICT="test"

RDEPEND="dev-util/rocminfo
		dev-util/hip
		sci-libs/rocSPARSE:${SLOT}[${ROCM_USEDEP}]"
DEPEND="${RDEPEND}"
BDEPEND="dev-util/rocm-cmake
	>=dev-util/cmake-3.22"

src_configure() {
	local mycmakeargs=(
		-DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF
		-DROCM_SYMLINK_LIBS=OFF
		-DHIP_RUNTIME="ROCclr"
		-DBUILD_CLIENTS_TESTS=OFF
		-DBUILD_CLIENTS_SAMPLES=OFF
	)

	cmake_src_configure
}
