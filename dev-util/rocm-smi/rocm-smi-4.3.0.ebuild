# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{7..10} )

inherit cmake prefix python-single-r1

DESCRIPTION="ROCm System Management Interface Library"
HOMEPAGE="https://github.com/RadeonOpenCompute/rocm_smi_lib"

SRC_URI="https://github.com/RadeonOpenCompute/rocm_smi_lib/archive/rocm-${PV}.tar.gz -> rocm-smi-${PV}.tar.gz"
KEYWORDS="~amd64"

LICENSE="NCSA-AMD"
SLOT="0/$(ver_cut 1-2)"
IUSE=""
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

S="${WORKDIR}/rocm_smi_lib-rocm-${PV}"

DEPEND=""
RDEPEND="${PYTHON_DEPS}"

src_prepare() {
	eapply "${FILESDIR}/${PN}-4.3.0.patch"
	sed -e "/DESTINATION/s,\${OAM_NAME}\/lib,lib64," \
		-e "/DESTINATION/s,oam\/include,include," -i oam/CMakeLists.txt || die

	sed -e "/DESTINATION/s,\${ROCM_SMI}\/lib,lib," \
		-e "/DESTINATION/s,lib,lib64," \
		-e "/DESTINATION/s,rocm_smi\/include,include," -i rocm_smi/CMakeLists.txt || die

	eprefixify python_smi_tools/rsmiBindings.py

	cmake_src_prepare
}

src_install() {
	python_scriptinto /usr/bin
	python_newscript python_smi_tools/rocm_smi.py rocm-smi

	python_domodule python_smi_tools/rsmiBindings.py

	cmake_src_install
}
