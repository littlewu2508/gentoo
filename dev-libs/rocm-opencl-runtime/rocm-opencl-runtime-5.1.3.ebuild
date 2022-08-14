# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake edo flag-o-matic prefix

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
	test? ( x11-apps/mesa-progs[X] )
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
	# remove trailing  or it won't work
	sed -e "s///g" -i tests/ocltst/module/perf/oclperf.exclude || die

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
		-DEMU_ENV=ON
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

check_rw_permission() {
	[[ -r "$1" ]] && [[ -w "$1" ]] || die \
		"${PORTAGE_USERNAME} do not have read or write permissions on $1! \n Make sure ${PORTAGE_USERNAME} is in render group and check the permissions."
}

src_test() {
	addwrite /dev/kfd
	addwrite /dev/dri/
	check_rw_permission /dev/kfd
	check_rw_permission /dev/dri/render*
	pushd "${BUILD_DIR}"/tests/ocltst
	export OCL_ICD_FILENAMES="${BUILD_DIR}"/amdocl/libamdocl64.so
	edob ./ocltst -m liboclperf.so -A oclperf.exclude
	local instruction="Please start an X server using amdgpu driver on GPU device, and rerun the test using OCLGL_DISPLAY=\${DISPLAY} FEATURES=test emerge rocm-opencl-runtime."
	if [[ -n ${OCLGL_DISPLAY+x} ]]; then
		ebegin "Running oclgl test under DISPLAY ${OCLGL_DISPLAY}"
		DISPLAY=${OCLGL_DISPLAY} glxinfo | grep "OpenGL vendor string: AMD" || die "This display does not have AMD OpenGL vendor! ${instruction}"
		DISPLAY=${OCLGL_DISPLAY} ./ocltst -m liboclgl.so -A ogl.exclude
		eend $? || die "oclgl test failed"
	else
		die "\${OCLGL_DISPLAY} not set. ${instruction}."
	fi
	edob ./ocltst -m liboclruntime.so -A oclruntime.exclude
}
