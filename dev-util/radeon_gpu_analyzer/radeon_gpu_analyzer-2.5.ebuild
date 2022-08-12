# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Offline compiler and code analysis tool for Vulkan, DirectX, OpenGL, and OpenCL."
HOMEPAGE="https://gpuopen.com/rga/"
SRC_URI="https://github.com/GPUOpen-Tools/radeon_gpu_analyzer/archive/refs/tags/${PV}.tar.gz"

inherit cmake

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""
