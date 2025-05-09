# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{11..13} )
DISTUTILS_USE_PEP517=setuptools
inherit distutils-r1

DESCRIPTION="The ultimate statusline/prompt utility"
HOMEPAGE="https://github.com/powerline/powerline"
if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/powerline/powerline"
	EGIT_BRANCH="develop"
else
	SRC_URI="https://github.com/powerline/powerline/archive/refs/tags/${PV}.tar.gz"
	KEYWORDS="~amd64 ~arm64 ~riscv ~x86 ~amd64-linux ~x86-linux"
fi

LICENSE="Apache-2.0"
SLOT="0"

PATCHES=(
	"${FILESDIR}"/2.7-ldflags.patch
)
