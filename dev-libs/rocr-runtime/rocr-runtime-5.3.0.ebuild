# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake llvm prefix

LLVM_MAX_SLOT=15

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/RadeonOpenCompute/ROCR-Runtime/"
	inherit git-r3
	S="${WORKDIR}/${P}/src"
else
	SRC_URI="https://github.com/RadeonOpenCompute/ROCR-Runtime/archive/rocm-${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/ROCR-Runtime-rocm-${PV}/src"
	KEYWORDS="~amd64"
fi

DESCRIPTION="Radeon Open Compute Runtime"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCR-Runtime"
PATCHES=(
	"${FILESDIR}/${PN}-4.3.0_no-aqlprofiler.patch"
	"${FILESDIR}/${PN}-5.3.0-cmake-install-paths.patch"
	"${FILESDIR}/${PN}-5.3.0-interface-includedir.patch"
)

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"

COMMON_DEPEND="dev-libs/elfutils"
RDEPEND="${COMMON_DEPEND}"
DEPEND="${COMMON_DEPEND}
	>=dev-libs/roct-thunk-interface-${PV}
	>=dev-libs/rocm-device-libs-${PV}
	sys-devel/clang
	sys-devel/lld"
BDEPEND="app-editors/vim-core"
	# vim-core is needed for "xxd"

CMAKE_BUILD_TYPE=Release

src_prepare() {
	# ... otherwise system llvm/clang is used ...
	sed -e "/find_package(Clang REQUIRED HINTS /s:\${CMAKE_INSTALL_PREFIX}/llvm \${CMAKE_PREFIX_PATH}/llvm PATHS /opt/rocm/llvm:$(get_llvm_prefix ${LLVM_MAX_SLOT}):" -i image/blit_src/CMakeLists.txt || die

	# Gentoo installs "*.bc" to "/usr/lib" instead of a "[path]/bitcode" directory ...
	sed -e "s:/opt/rocm/amdgcn/bitcode:${EPREFIX}/usr/lib/amdgcn/bitcode:" -i image/blit_src/CMakeLists.txt || die

	eapply $(prefixify_ro "${FILESDIR}"/${PN}-5.3.0-specify-device-lib-path.patch)
	cmake_src_prepare
}
