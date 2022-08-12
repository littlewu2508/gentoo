# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..10} )

inherit cmake rocm

DESCRIPTION="Basic Linear Algebra Subroutines for sparse computation"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/rocSPARSE"

SRC_URI="https://github.com/ROCmSoftwarePlatform/rocALUTION/archive/rocm-${PV}.tar.gz -> rocALUTION${PV}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64"
IUSE="benchmark mpi +openmp test"
SLOT="0/$(ver_cut 1-2)"

RDEPEND="dev-util/hip
sci-libs/rocSPARSE:${SLOT}
sci-libs/rocBLAS:${SLOT}
mpi? ( virtual/mpi )
openmp? ( sys-devel/gcc[openmp] )"

DEPEND="${RDEPEND}"
BDEPEND="test? (
	dev-cpp/gtest
)
"

RESTRICT="!test? ( test )"

S="${WORKDIR}/${PN}-rocm-${PV}"

python_check_deps() {
	if use test; then
		has_version "dev-python/pyyaml[${PYTHON_USEDEP}]"
	fi
}

src_prepare() {
	eapply_user
	sed -e "s/PREFIX rocalution//" \
		-e "/rocm_install_symlink_subdir(rocsparse)/d" \
		-i src/CMakeLists.txt || die

	# remove GIT dependency
	sed -e "/find_package(Git/d" -i cmake/Dependencies.cmake || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DSUPPORT_HIP=ON
		-DSUPPORT_OMP=$(usex openmp ON OFF)
		-DSUPPORT_MPI=$(usex mpi ON OFF)
		-DBUILD_CLIENTS_SAMPLES=OFF
		-DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
		-DBUILD_CLIENTS_BENCHMARKS=$(usex benchmark ON OFF)
	)

	rocm_src_configure
}

src_test() {
	rocm_src_test
}

src_install() {
	cmake_src_install

# 	if use benchmark; then
# 		local rocalution_bench="${BUILD_DIR}/clients/staging/rocalution-bench"
# 		dobin "${rocalution_bench}"
# 	fi
}
