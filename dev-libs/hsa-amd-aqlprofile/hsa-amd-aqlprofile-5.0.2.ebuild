# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit unpacker

DESCRIPTION="AMD HSA Aqlprofile"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCm"
MY_PV=$(ver_rs 1- '0')
SRC_URI="http://repo.radeon.com/rocm/apt/${PV%.0}/pool/main/h/hsa-amd-aqlprofile/hsa-amd-aqlprofile_1.0.0.${MY_PV}-72_amd64.deb"

LICENSE="AMD-AOCC-AQLProfile-EULA"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"

S="${WORKDIR}"

QA_PREBUILT="/usr/lib64/libhsa-amd-aqlprofile64.so.1.0.${MY_PV}"

src_unpack(){
	unpack_deb ${A}
}

src_install() {
	dolib.so "${S}/opt/rocm-${PV}/hsa-amd-aqlprofile/lib/libhsa-amd-aqlprofile64.so.1.0.${MY_PV}"
	dosym "libhsa-amd-aqlprofile64.so.1.0.${MY_PV}" "/usr/$(get_libdir)/libhsa-amd-aqlprofile64.so"
	dosym "libhsa-amd-aqlprofile64.so.1.0.${MY_PV}" "/usr/$(get_libdir)/libhsa-amd-aqlprofile64.so.1"
}
