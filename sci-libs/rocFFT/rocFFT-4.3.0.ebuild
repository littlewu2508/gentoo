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
	test? ( dev-cpp/gtest )
"
DEPEND="${RDEPEND}"

CHECKREQS_MEMORY="28G"

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

	[ -z "${AMDGPU_TARGETS}" ] && local AMDGPU_TARGETS="gfx803;gfx900:xnack-;gfx906:xnack-;gfx908:xnack-"
	local mycmakeargs=(
		-Wno-dev
		-DCMAKE_INSTALL_INCLUDEDIR="include/rocFFT/"
		-DCMAKE_SKIP_RPATH=ON
		-DAMDGPU_TARGETS="${AMDGPU_TARGETS}"
		-D__skip_rocmclang="ON" ## fix cmake-3.21 configuration issue caused by officialy support programming language "HIP"
		-DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
		-DBUILD_CLIENTS_SELFTEST=$(usex test ON OFF)
	)

	cmake_src_configure
}

src_test () {
	cd "${BUILD_DIR}/clients/staging" || die
	einfo "Running rocfft-test"
	LD_LIBRARY_PATH=/tmp/portage/sci-libs/rocFFT-4.3.0/work/rocFFT-4.3.0_build/library/src/:/tmp/portage/sci-libs/rocFFT-4.3.0/work/rocFFT-4.3.0_build/library/src/device ./rocfft-test
	einfo "Running rocfft-selftest"
	LD_LIBRARY_PATH=/tmp/portage/sci-libs/rocFFT-4.3.0/work/rocFFT-4.3.0_build/library/src/:/tmp/portage/sci-libs/rocFFT-4.3.0/work/rocFFT-4.3.0_build/library/src/device ./rocfft-selftest
}
