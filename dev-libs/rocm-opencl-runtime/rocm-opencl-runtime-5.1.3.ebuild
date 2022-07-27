# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake edo flag-o-matic prefix virtualx

DESCRIPTION="Radeon Open Compute OpenCL Compatible Runtime"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime"
SRC_URI="https://github.com/ROCm-Developer-Tools/ROCclr/archive/rocm-${PV}.tar.gz -> rocclr-${PV}.tar.gz
	https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/archive/rocm-${PV}.tar.gz -> rocm-opencl-runtime-${PV}.tar.gz"

LICENSE="Apache-2.0 MIT"
SLOT="0/$(ver_cut 1-2)"
IUSE="debug test"
RESTRICT="!test? ( test )"
KEYWORDS="~amd64"

RDEPEND=">=dev-libs/rocr-runtime-${PV}
	>=dev-libs/rocm-comgr-${PV}
	>=dev-libs/rocm-device-libs-${PV}
	>=virtual/opencl-3
	media-libs/mesa"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-util/rocm-cmake-${PV}
	media-libs/glew
	"

PATCHES=(
	"${FILESDIR}/${PN}-5.1.3-remove-clinfo.patch"
	"${FILESDIR}/${PN}-3.5.0-do-not-install-libopencl.patch"
)

S="${WORKDIR}/ROCm-OpenCL-Runtime-rocm-${PV}"
S1="${WORKDIR}/ROCclr-rocm-${PV}"

# CMAKE_BUILD_TYPE=Release

src_prepare() {
	# Remove "clinfo" - use "dev-util/clinfo" instead
	[ -d tools/clinfo ] && rm -rf tools/clinfo || die

	cmake_src_prepare

	hprefixify amdocl/CMakeLists.txt

	sed -e "s/DESTINATION lib/DESTINATION ${CMAKE_INSTALL_LIBDIR}/g" -i packaging/CMakeLists.txt || die

	pushd ${S1} || die
	# Bug #753377
	# patch re-enables accidentally disabled gfx8000 family
	eapply "${FILESDIR}/${PN}-5.0.2-enable-gfx800.patch"
	popd
}

src_configure() {
	# Reported upstream: https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/issues/120
	append-cflags -fcommon

	local mycmakeargs=(
		-Wno-dev
		-DROCCLR_PATH="${S1}"
		-DAMD_OPENCL_PATH="${S}"
		-DROCM_PATH="${EPREFIX}/usr"
		-DBUILD_TESTS=$(usex test ON OFF)
		# -DEMU_ENV=$(usex test ON OFF)
		# -DCMAKE_STRIP=""
	)
	cmake_src_configure
}

src_install() {
	insinto /etc/OpenCL/vendors
	doins config/amdocl64.icd

	cd "${BUILD_DIR}" || die
	insinto /usr/lib64
	doins amdocl/libamdocl64.so
	doins tools/cltrace/libcltrace.so
}

src_test() {
	addwrite /dev/kfd
	addwrite /dev/dri/
	pushd "${BUILD_DIR}"/tests/ocltst
	export OCL_ICD_FILENAMES="${BUILD_DIR}"/amdocl/libamdocl64.so
	virtx ./ocltst -m liboclgl.so -a ogl.exclude
	virtx ./ocltst -m liboclruntime.so -a oclruntime.exclude
	edob ./ocltst -m liboclperf.so -a oclperf.exclude
}
