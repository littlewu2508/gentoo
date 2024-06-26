# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit desktop

MY_OGG=danslatristesse2-48.ogg
DESCRIPTION="3D tabletennis game"
HOMEPAGE="http://cannonsmash.sourceforge.net/"
SRC_URI="https://downloads.sourceforge.net/${PN}/csmash-${PV}.tar.gz
	vorbis? ( http://nan.p.utmc.or.jp/${MY_OGG} )"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="vorbis nls"

RDEPEND="
	virtual/opengl
	virtual/glu
	media-libs/libsdl[sound,video]
	media-libs/sdl-mixer[vorbis?]
	media-libs/sdl-image[jpeg,png]
	x11-libs/gtk+:2
	nls? ( virtual/libintl )
"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
"

S="${WORKDIR}/csmash-${PV}"

src_unpack() {
	unpack csmash-${PV}.tar.gz
}

src_prepare() {
	default
	eapply \
		"${FILESDIR}"/${P}-x-inc.patch \
		"${FILESDIR}"/${P}-sizeof-cast.patch \
		"${FILESDIR}"/${P}-gcc41.patch \
		"${FILESDIR}"/${P}-flags.patch
	if use vorbis ; then
		sed -i \
			-e "s:${MY_OGG}:/usr/share/csmash/games/${MY_OGG}:" ttinc.h \
			|| die "sed failed"
	fi
}

src_configure() {
	econf \
		$(use_enable nls) \
		--datadir="/usr/share"
}

src_compile() {
	emake \
		localedir="/usr/share"
}

src_install() {
	default
	if use vorbis ; then
		insinto /usr/share/games/csmash
		doins "${DISTDIR}"/${MY_OGG}
	fi
	newicon win32/orange.ico ${PN}.ico
	make_desktop_entry csmash "Cannon Smash" /usr/share/pixmaps/${PN}.ico
}
