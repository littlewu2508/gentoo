# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOCS_BUILDER="doxygen"
DOCS_DEPEND="media-gfx/graphviz"

inherit cmake docs llvm

LLVM_MAX_SLOT=17

DESCRIPTION="C++ Heterogeneous-Compute Interface for Portability"
HOMEPAGE="https://github.com/ROCm-Developer-Tools/hipamd"
SRC_URI="https://github.com/ROCm-Developer-Tools/clr/archive/refs/tags/rocm-${PV}.tar.gz -> rocm-clr-${PV}.tar.gz
	https://github.com/ROCm-Developer-Tools/HIP/archive/refs/tags/rocm-${PV}.tar.gz -> hip-${PV}.tar.gz
	https://github.com/ROCm-Developer-Tools/hip-tests/archive/refs/tags/rocm-${PV}.tar.gz -> rocm-hip-tests-${PV}.tar.gz"

KEYWORDS="~amd64"
LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"

IUSE="debug test"
RESTRICT="!test? ( test )"

DEPEND="
	dev-util/hipcc
	>=dev-util/rocminfo-5
	sys-devel/clang:${LLVM_MAX_SLOT}
	dev-libs/rocm-comgr:${SLOT}
	x11-base/xorg-proto
	virtual/opengl
"
RDEPEND="${DEPEND}
	dev-perl/URI-Encode
	sys-devel/clang-runtime:=
	>=dev-libs/roct-thunk-interface-5"

PATCHES=(
	"${FILESDIR}/${PN}-5.7.0-install.patch"
	"${FILESDIR}/${PN}-5.7.0-set-correct-alignement.patch"
	"${FILESDIR}/${PN}-5.7.1-extend-isa-compatibility-check.patch"
	"${FILESDIR}/${PN}-5.7.1-make-test-switchable.patch"
	"${FILESDIR}/${PN}-5.7.1-enable-build-catch-test.patch"
)

HIPTEST_S="${WORKDIR}"/hip-tests-rocm-${PV}
HIP_S="${WORKDIR}/HIP-rocm-${PV}"
S="${WORKDIR}/clr-rocm-${PV}/"

src_unpack () {
	default

	cp -a "${HIPTEST_S}"/{catch,perftests} "${HIP_S}/"tests || die # move back hip tests
	cp -a "${HIPTEST_S}"/samples "${HIP_S}" || die # move back hip tests
}

src_prepare() {
	cmake_src_prepare

	sed -e "/CPACK_RESOURCE_FILE_LICENSE/d" -i hipamd/packaging/CMakeLists.txt \
		-i "${HIP_S}"/tests/catch/packaging/CMakeLists.txt || die

	pushd "${HIP_S}" || die
	eapply "${FILESDIR}/${PN}-5.7.1-fix-test-build.patch"
	eapply "${FILESDIR}/${PN}-5.4.3-fix-HIP_CLANG_PATH-detection.patch"
	eapply "${FILESDIR}/${PN}-5.7.1-rename-hit-test-target.patch"
	eapply "${FILESDIR}/${PN}-5.7.1-do-not-run-stress-on-build.patch"
	eapply "${FILESDIR}/${PN}-5.7.1-remove-test-Werror.patch"

	# Removing incompatible tests
	eapply "${FILESDIR}/${PN}-5.7.1-remove-incompatible-tests.patch"
	rm tests/src/deviceLib/hipLaunchKernelFunc.cpp || die
	rm tests/src/deviceLib/hipMathFunctions.cpp || die
}

src_configure() {
	use debug && CMAKE_BUILD_TYPE="Debug"

	# TODO: Currently a GENTOO configuration is build,
	# this is also used in the cmake configuration files
	# which will be installed to find HIP;
	# Other ROCm packages expect a "RELEASE" configuration,
	# see "hipBLAS"
	local LLVM_PREFIX="$(get_llvm_prefix "${LLVM_MAX_SLOT}")"
	local mycmakeargs=(
		-DCMAKE_PREFIX_PATH="${LLVM_PREFIX}"
		-DCMAKE_BUILD_TYPE=${buildtype}
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr"
		-DCMAKE_SKIP_RPATH=ON
		-DBUILD_HIPIFY_CLANG=OFF
		-DHIP_PLATFORM=amd
		-DHIP_COMMON_DIR="${HIP_S}"
		-DROCM_PATH="${EPREFIX}/usr"
		-DUSE_PROF_API=0
		-DFILE_REORG_BACKWARD_COMPATIBILITY=OFF
		-DCLR_BUILD_HIP=ON
		-DHIPCC_BIN_DIR="${EPREFIX}/usr/bin"
		-DOpenGL_GL_PREFERENCE="GLVND"
		-DBUILD_TESTS=$(usex test ON OFF)
	)

	use test && mycmakeargs+=(
		# HIP_CXX_COMPILER is needed when building test binaries
		-DHIP_CXX_COMPILER="${LLVM_PREFIX}/bin/clang++"
		-DHIP_CATCH_TEST=1
	)

	cmake_src_configure

	# do not rerun cmake and the build process in src_install
	sed '/RERUN/,+1d' -i "${BUILD_DIR}"/build.ninja || die
}

src_compile() {
	cmake_src_compile
	# Compile test binaries; when linking, `-lamdhip64` is used, thus need
	# LIBRARY_PATH pointing to libamdhip64.so located at ${BUILD_DIR}/lib
	if use test; then
		export LIBRARY_PATH="${BUILD_DIR}/hipamd/lib" # link to built libhipamd
		# treat the headers in build dir as system include dir to suppress
		# warnings like "anonymous structs are a GNU extension"
		export CPLUS_INCLUDE_PATH="${BUILD_DIR}/hipamd/include"
		export ROCM_PATH="${BUILD_DIR}/hipamd"
		cmake_src_compile build_tests build_hit_tests build_perf
	fi
}

# Copied from rocm.eclass. This ebuild does not need amdgpu_targets
# USE_EXPANDS, so it should not inherit rocm.eclass; it only uses the
# check_amdgpu function in src_test. Rename it to check-amdgpu to avoid
# pkgcheck warning.
check-amdgpu() {
	for device in /dev/kfd /dev/dri/render*; do
		addwrite ${device}
		if [[ ! -r ${device} || ! -w ${device} ]]; then
			eerror "Cannot read or write ${device}!"
			eerror "Make sure it is present and check the permission."
			ewarn "By default render group have access to it. Check if portage user is in render group."
			die "${device} inaccessible"
		fi
	done
}

src_test() {
	check-amdgpu
	# pushd ="${BUILD_DIR}/hipamd" || die
	# -j1 to avoid multi process on one GPU which causes coillision
	BUILD_DIR="${BUILD_DIR}/hipamd" MAKEOPTS="-j1" LD_LIBRARY_PATH="${BUILD_DIR}/lib" cmake_src_test -C performance
}

src_install() {

	cmake_src_install

	rm "${ED}/usr/include/hip/hcc_detail" || die

	# files already installed by hipcc, which is a build dep
	rm "${ED}/usr/bin/hipconfig.pl" || die
	rm "${ED}/usr/bin/hipcc.pl" || die
	rm "${ED}/usr/bin/hipcc" || die
	rm "${ED}/usr/bin/hipconfig" || die
	rm "${ED}/usr/bin/hipvars.pm" || die
}
