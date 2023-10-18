# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Dobiasd/FunctionalPlus.git"
else
	SRC_URI="https://github.com/Dobiasd/FunctionalPlus/archive/refs/tags/v${PV}-p0.tar.gz -> functional-plus-${PV}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="Functional Programming Library for C++"
HOMEPAGE="https://www.editgym.com/fplus-api-search/"

LICENSE="Boost-1.0"
SLOT="0"

IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="test? ( dev-cpp/doctest )"

S="${WORKDIR}/FunctionalPlus-${PV}-p0"

src_test() {
	local BUILD_DIR="${WORKDIR}/${P}_build/test"
	local CMAKE_USE_DIR="${S}/test"
	cmake_src_configure
	cmake_src_compile
	cmake_src_test
}
