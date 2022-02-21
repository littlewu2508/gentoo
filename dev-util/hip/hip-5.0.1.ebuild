# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
inherit cmake flag-o-matic prefix

DESCRIPTION="C++ Heterogeneous-Compute Interface for Portability"
HOMEPAGE="https://github.com/ROCm-Developer-Tools/hipamd"
SRC_URI="https://github.com/ROCm-Developer-Tools/hipamd/archive/rocm-${PV}.tar.gz -> rocm-hipamd-${PV}.tar.gz
	https://github.com/ROCm-Developer-Tools/HIP/archive/rocm-${PV}.tar.gz -> rocm-hip-${PV}.tar.gz
	https://github.com/ROCm-Developer-Tools/ROCclr/archive/rocm-${PV}.tar.gz -> rocclr-${PV}.tar.gz
	https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/archive/rocm-${PV}.tar.gz -> rocm-opencl-runtime-${PV}.tar.gz
	profile? ( https://github.com/ROCm-Developer-Tools/roctracer/archive/refs/tags/rocm-${PV}.tar.gz -> rocm-tracer-${PV}.tar.gz )"

KEYWORDS="~amd64"
LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"

IUSE="debug profile"

DEPEND="
	dev-util/rocminfo:${SLOT}
	=sys-devel/llvm-roc-${PV}*[runtime]
"
RDEPEND="${DEPEND}
	dev-perl/URI-Encode"

PATCHES=(
	"${FILESDIR}/${PN}-5.0.1-DisableTest.patch"
	# "${FILESDIR}/${PN}-3.9.0-add-include-directories.patch"
	"${FILESDIR}/${PN}-4.2.0-config-cmake-in.patch"
	"${FILESDIR}/${PN}-5.0.1-hip_vector_types.patch"
	"${FILESDIR}/${PN}-4.2.0-cancel-hcc-header-removal.patch"
)

S="${WORKDIR}/hipamd-rocm-${PV}"
HIP_S="${WORKDIR}"/HIP-rocm-${PV}
OCL_S="${WORKDIR}"/ROCm-OpenCL-Runtime-rocm-${PV}
CLR_S="${WORKDIR}"/ROCclr-rocm-${PV}
RTC_S="${WORKDIR}"/roctracer-rocm-${PV}

src_prepare() {
	cmake_src_prepare
	eapply_user

	# Use Gentoo slot number, otherwise git hash is attempted in vain.
	sed -e "/set (HIP_LIB_VERSION_STRING/cset (HIP_LIB_VERSION_STRING ${SLOT#*/})" -i CMakeLists.txt || die

	# disable PCH, because it results in a build error in ROCm 4.0.0
	sed -e "s:option(__HIP_ENABLE_PCH:#option(__HIP_ENABLE_PCH:" -i CMakeLists.txt || die

	# correctly find HIP_CLANG_INCLUDE_PATH using cmake
	sed -e "/set(HIP_CLANG_ROOT/s:\"\${ROCM_PATH}/llvm\":/usr/lib/llvm/roc:" -i hip-config.cmake.in || die

	cd ${HIP_S} || die
	# Setting HSA_PATH to "/usr" results in setting "-isystem /usr/include"
	# which makes "stdlib.h" not found when using "#include_next" in header files;
	sed -e "/FLAGS .= \" -isystem \$HSA_PATH/d" \
		-e "s:\$ENV{'DEVICE_LIB_PATH'}:'/usr/lib/amdgcn/bitcode':" \
		-e "/rpath/s,--rpath=[^ ]*,," \
		-i bin/hipcc.pl || die

	# change --hip-device-lib-path to "/usr/lib/amdgcn/bitcode", must align with "dev-libs/rocm-device-libs"
	sed -e "s:\${AMD_DEVICE_LIBS_PREFIX}/lib:/usr/lib/amdgcn/bitcode:" \
		-i "${S}/hip-config.cmake.in" || die

	einfo "prefixing hipcc and its utils..."
	hprefixify $(grep -rl --exclude-dir=build/ "/usr" "${S}")
	hprefixify $(grep -rl --exclude-dir=build/ "/usr" "${HIP_S}")

	cp "$(prefixify_ro "${FILESDIR}"/hipvars.pm)" bin/ || die "failed to replace hipvars.pm"
	sed -e "s,@HIP_BASE_VERSION_MAJOR@,$(ver_cut 1)," -e "s,@HIP_BASE_VERSION_MINOR@,$(ver_cut 2)," \
		-e "s,@HIP_VERSION_PATCH@,$(ver_cut 3)," -i bin/hipvars.pm || die
}

src_configure() {
	use debug && CMAKE_BUILD_TYPE="Debug"

	# TODO: Currently a GENTOO configuration is build,
	# this is also used in the cmake configuration files
	# which will be installed to find HIP;
	# Other ROCm packages expect a "RELEASE" configuration,
	# see "hipBLAS"
	local mycmakeargs=(
		-DCMAKE_PREFIX_PATH="${EPREFIX}/usr/lib/llvm/roc"
		-DCMAKE_BUILD_TYPE=${buildtype}
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/lib/hip"
		-DBUILD_HIPIFY_CLANG=OFF
		-DHIP_PLATFORM=amd
		-DHIP_COMPILER=clang
		-DROCM_PATH="${EPREFIX}/usr"
		-DUSE_PROF_API=$(usex profile 1 0)
		-DPROF_API_HEADER_PATH="${RTC_S}"/inc/ext
		-DROCCLR_PATH=${CLR_S}
		-DHIP_COMMON_DIR=${HIP_S}
		-DAMD_OPENCL_PATH=${OCL_S}
	)

	cmake_src_configure
}

src_install() {
	echo "PATH=${EPREFIX}/usr/lib/hip/bin" >> 99hip || die
	echo "LDPATH=${EPREFIX}/usr/lib/hip/lib" >> 99hip || die
	echo "ROOTPATH=${EPREFIX}/usr/lib/hip/bin" >> 99hip || die

	doenvd 99hip

	cmake_src_install

	rm "${ED}/usr/lib/hip/include/hip/hcc_detail" || die
}
