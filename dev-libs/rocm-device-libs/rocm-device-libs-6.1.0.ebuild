# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake llvm

LLVM_MAX_SLOT=17
MY_P=llvm-project-rocm-${PV}
components=( "amd/device-libs" )

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/ROCm/llvm-project"
	inherit git-r3
	S="${WORKDIR}/${P}/${components[0]}"
else
	SRC_URI="https://github.com/ROCm/llvm-project/archive/rocm-${PV}.tar.gz -> ${MY_P}.tar.gz"
	S="${WORKDIR}/${MY_P}/${components[0]}"
	KEYWORDS="~amd64"
fi

DESCRIPTION="Radeon Open Compute Device Libraries"
HOMEPAGE="https://github.com/ROCm/ROCm-Device-Libs"

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"
IUSE="test"
RESTRICT="strip !test? ( test )"

RDEPEND="sys-devel/clang:${LLVM_MAX_SLOT}"
DEPEND="${RDEPEND}"

CMAKE_BUILD_TYPE=Release

PATCHES=(
	"${FILESDIR}/${PN}-5.5.0-test-bitcode-dir.patch"
	"${FILESDIR}/${PN}-6.1.0-fix-llvm-link.patch"
	"${FILESDIR}/${PN}-6.1.0-fix-test-failures.patch"
	)

src_unpack() {
	if [[ ${PV} == *9999 ]] ; then
		git-r3_fetch
		git-r3_checkout '' . '' "${components[@]}"
	else
		archive="${MY_P}.tar.gz"
		ebegin "Unpacking from ${archive}"
		tar -x -z -o \
			-f "${DISTDIR}/${archive}" \
			"${components[@]/#/${MY_P}/}" || die
		eend ${?}
	fi
}

src_prepare() {
	sed -e "s:amdgcn/bitcode:lib/amdgcn/bitcode:" -i "${S}/cmake/OCL.cmake" || die
	sed -e "s:amdgcn/bitcode:lib/amdgcn/bitcode:" -i "${S}/cmake/Packages.cmake" || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DLLVM_DIR="$(get_llvm_prefix "${LLVM_MAX_SLOT}")"
	)
	cmake_src_configure
}
