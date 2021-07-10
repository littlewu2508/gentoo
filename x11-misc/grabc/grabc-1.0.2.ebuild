# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit prefix toolchain-funcs

DESCRIPTION="Identify color of a pixel on the screen by clicking on a pixel on the screen"
HOMEPAGE="https://www.muquit.com/muquit/software/grabc/grabc.html"
SRC_URI="https://github.com/muquit/grabc/archive/refs/tags/v${PV}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="x11-libs/libX11"
DEPEND="${RDEPEND}
	x11-base/xorg-proto
	virtual/pkgconfig
"

# PATCHES=( "${FILESDIR}"/grabc-1.1-makefile.patch )

src_prepare() {
	hprefixify Makefile
	default
}

src_compile() {
	tc-export CC PKG_CONFIG
	make doc
	default
}

src_install() {
	dobin grabc
	einstalldocs
	doman grabc.1
}
