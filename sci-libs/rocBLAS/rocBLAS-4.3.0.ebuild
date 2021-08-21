# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{6..9} )

inherit cmake prefix python-any-r1

DESCRIPTION="AMD's library for BLAS on ROCm."
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/rocBLAS"
SRC_URI="https://github.com/ROCmSoftwarePlatform/rocBLAS/archive/rocm-${PV}.tar.gz -> rocm-${P}.tar.gz
	https://github.com/ROCmSoftwarePlatform/Tensile/archive/rocm-${PV}.tar.gz -> rocm-Tensile-${PV}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64"
IUSE="benchmark test"
SLOT="0/$(ver_cut 1-2)"

BDEPEND="
	dev-util/rocm-cmake
	!dev-util/Tensile
	$(python_gen_any_dep '
		dev-python/msgpack[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
	')
	benchmark? ( app-admin/chrpath )
"

DEPEND="
	dev-util/hip:${SLOT}
	dev-libs/msgpack
	test? ( virtual/blas )
	test? ( dev-cpp/gtest )
	test? ( sys-libs/libomp )
	benchmark? ( virtual/blas )
	benchmark? ( sys-libs/libomp )
"
# stripped library is not working
RESTRICT="!test? ( test )"

python_check_deps() {
	has_version "dev-python/pyyaml[${PYTHON_USEDEP}]" &&
	has_version "dev-python/msgpack[${PYTHON_USEDEP}]"
}

check_rw_permission() {
	su portage -c "[ -r $1 ] && [ -w $1 ]"  || die " portage don't have read and write permissions on $1! \n Make sure portage is in render group and check the permissions."
}

pkg_setup () {
	# check permissions on /dev/kfd, /dev/dri/render* and /dev/random
	if has sandbox ${FEATURES}; then
		check_rw_permission /dev/kfd
		check_rw_permission /dev/dri/render*
		check_rw_permission /dev/random
	fi
	python-any-r1_pkg_setup
}

S="${WORKDIR}"/${PN}-rocm-${PV}

PATCHES=("${FILESDIR}"/${PN}-4.3.0-fix-glibc-2.32-and-above.patch
	"${FILESDIR}"/${PN}-4.3.0-change-default-Tensile-library-dir.patch
	"${FILESDIR}"/${PN}-4.3.0-link-system-blas.patch )

src_prepare() {
	eapply_user

	pushd "${WORKDIR}"/Tensile-rocm-${PV} || die
	eapply "${FILESDIR}/Tensile-${PV}-hsaco-compile-specified-arch.patch" # backported from upstream, should remove after 4.3.0
	eapply "${FILESDIR}/Tensile-4.3.0-output-commands.patch"
	popd || die

	# Fit for Gentoo FHS rule
	sed -e "/PREFIX rocblas/d" \
		-e "/<INSTALL_INTERFACE/s:include:include/rocblas:" \
		-e "s:rocblas/include:include/rocblas:" \
		-e "s:\\\\\${CPACK_PACKAGING_INSTALL_PREFIX}rocblas/lib:${EPREFIX}/usr/$(get_libdir)/rocblas:" \
		-e "s:share/doc/rocBLAS:share/doc/${P}:" \
		-e "/rocm_install_symlink_subdir( rocblas )/d" -i library/src/CMakeLists.txt || die

	# Use setup.py to install Tensile rather than pip
	sed -r -e "/pip install/s:([^ \"\(]*python) -m pip install ([^ \"\)]*):\1 setup.py install --single-version-externally-managed --root / WORKING_DIRECTORY \2:g" -i cmake/virtualenv.cmake

	sed -e "s:,-rpath=.*\":\":" -i clients/CMakeLists.txt || die

	cmake_src_prepare
	eprefixify library/src/tensile_host.cpp
}

src_configure() {
	# allow acces to hardware
	addwrite /dev/kfd
	addwrite /dev/dri/
	addwrite /dev/random

	export PATH="${EPREFIX}/usr/lib/llvm/roc/bin:${PATH}"

	local mycmakeargs=(
		-DTensile_LOGIC="asm_full"
		-DTensile_COMPILER="hipcc"
		-DTensile_LIBRARY_FORMAT="msgpack"
		-DTensile_CODE_OBJECT_VERSION="V3"
		-DTensile_TEST_LOCAL_PATH="${WORKDIR}/Tensile-rocm-${PV}"
		-DBUILD_WITH_TENSILE=ON
		-DBUILD_WITH_TENSILE_HOST=ON
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr"
		-DCMAKE_INSTALL_INCLUDEDIR="include/rocblas"
		-DBUILD_TESTING=OFF
		-DBUILD_CLIENTS_SAMPLES=OFF
		-DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
		-DBUILD_CLIENTS_BENCHMARKS=$(usex benchmark ON OFF)
		-D__skip_rocmclang="ON" ## fix cmake-3.21 configuration issue caused by officialy support programming language "HIP"
	)
	[ -n "${AMDGPU_TARGETS}" ] && mycmakeargs+=( -DAMDGPU_TARGETS="${AMDGPU_TARGETS}" )

	CXX="hipcc" cmake_src_configure

	# do not rerun cmake and the build process in src_install
	sed -e '/RERUN/,+1d' -i "${BUILD_DIR}"/build.ninja || die
}

src_test() {
	addwrite /dev/kfd
	addwrite /dev/dri/
	cd "${BUILD_DIR}/clients/staging" || die
	ROCBLAS_TENSILE_LIBPATH="${BUILD_DIR}/Tensile/library" ./rocblas-test
}

src_install() {
	cmake_src_install

	if use benchmark; then
		cd "${BUILD_DIR}" || die
		dolib.so clients/librocblas_fortran_client.so
		dobin clients/staging/rocblas-bench
		chrpath -d "${ED}/usr/bin/rocblas-bench" || die
	fi
}
