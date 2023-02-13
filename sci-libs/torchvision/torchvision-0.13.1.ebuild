# Copyright 2020-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
ROCM_VERSION=5.5.0

PYTHON_COMPAT=( python3_10 )
DISTUTILS_SINGLE_IMPL=1
DISTUTILS_USE_PEP517=setuptools
inherit distutils-r1 rocm

DESCRIPTION="Datasets, transforms and models to specific to computer vision"
HOMEPAGE="https://github.com/pytorch/vision"
SRC_URI="https://github.com/pytorch/vision/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/vision-${PV}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="rocm"

RDEPEND="
	$(python_gen_cond_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/typing-extensions[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/scipy[${PYTHON_USEDEP}]
	')
	sci-libs/pytorch[${PYTHON_SINGLE_USEDEP}]
	rocm? ( sci-libs/caffe2[rocm,${ROCM_USEDEP}] )
	media-video/ffmpeg
	dev-qt/qtcore:5
"
DEPEND="${RDEPEND}"
BDEPEND="
	test? (
		$(python_gen_cond_dep '
		dev-python/mock[${PYTHON_USEDEP}]
		')
	)"

distutils_enable_tests pytest

src_compile() {
	addpredict /dev/kfd
	addpredict /dev/dri/

	if use rocm; then
		# echo $(get_amdgpu_flags) > "${T}/gpu.list" || die
		# sed -e 's/;/\n/g' -i "${T}/gpu.list" || die
		export FORCE_CUDA=1
		# export ROCM_TARGET_LST="${T}/gpu.list"
		export PYTORCH_ROCM_ARCH=$(get_amdgpu_flags)
	fi
	MAKEOPTS="-j1" distutils-r1_src_compile
}
