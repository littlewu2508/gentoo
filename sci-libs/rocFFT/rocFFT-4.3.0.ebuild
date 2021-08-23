# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cmake flag-o-matic check-reqs

DESCRIPTION="Next generation FFT implementation for ROCm"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/rocFFT"
SRC_URI="https://github.com/ROCmSoftwarePlatform/rocFFT/archive/rocm-${PV}.tar.gz -> rocFFT-${PV}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"

RDEPEND="
	dev-util/hip:${SLOT}
"
DEPEND="${RDEPEND}"
BDEPEND="
	test? ( dev-cpp/gtest dev-libs/boost  >=sci-libs/fftw-3 )
"

required_mem() {
	local NJOBS=$(sed -r 's,.*-j ?([0-9]+).*,\1,' <<< ${MAKEOPTS})
	if use test; then
		echo "52G"
	else
		if [ -n "${AMDGPU_TARGETS}" ]; then
			local NARCH=$(($(awk -F";" '{print NF-1}' <<< "${AMDGPU_TARGETS}")+1))
		else
			local NARCH=7 # The default number of AMDGPU_TARGETS for rocFFT-4.3.0. May change in the future.
		fi
		echo "$((${NJOBS}*${NARCH}*25+2200))M" # A linear function estimating how much memory required
	fi
}

CHECKREQS_DISK_BUILD="7G"
pkg_pretend() {
	return
}
pkg_setup() {
	export CHECKREQS_MEMORY=$(required_mem)
	check-reqs_pkg_setup
}

IUSE="test"

RESTRICT="!test? ( test )"

S="${WORKDIR}/rocFFT-rocm-${PV}"

PATCHES="${FILESDIR}/${PN}-4.2.0-add-functional-header.patch"

src_prepare() {
	sed -e "s/PREFIX rocfft//" \
		-e "/rocm_install_symlink_subdir/d" \
		-e "/<INSTALL_INTERFACE/s,include,include/rocFFT," \
		-i library/src/CMakeLists.txt || die

	sed -e "/rocm_install_symlink_subdir/d" \
		-e "$!N;s:PREFIX\n[ ]*rocfft:# PREFIX rocfft\n:;P;D" \
		-i library/src/device/CMakeLists.txt || die

	eapply_user
	cmake_src_prepare
}

src_configure() {
	# Grant access to the device
	addwrite /dev/kfd
	addpredict /dev/dri/

	# Compiler to use
	export CXX=hipcc

	local mycmakeargs=(
		-Wno-dev
		-DCMAKE_INSTALL_INCLUDEDIR="include/rocFFT/"
		-DCMAKE_SKIP_RPATH=ON
		-D__skip_rocmclang="ON" ## fix cmake-3.21 configuration issue caused by officialy support programming language "HIP"
		-DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
		-DBUILD_CLIENTS_SELFTEST=$(usex test ON OFF)
	)
	[ -n "${AMDGPU_TARGETS}" ] && mycmakeargs+=( -DAMDGPU_TARGETS="${AMDGPU_TARGETS}" )

	cmake_src_configure
}

src_test () {
	addwrite /dev/kfd
	addpredict /dev/dri
	cd "${BUILD_DIR}/clients/staging" || die
	einfo "Running rocfft-test"
	LD_LIBRARY_PATH=${BUILD_DIR}/library/src/:${BUILD_DIR}/library/src/device ./rocfft-test
	einfo "Running rocfft-selftest"
	LD_LIBRARY_PATH=${BUILD_DIR}/library/src/:${BUILD_DIR}/library/src/device ./rocfft-selftest
}
