# Copyright 2022-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{9..10} )
ROCM_VERSION=5.5.0
inherit python-single-r1 cmake flag-o-matic rocm

MYPN=pytorch
MYP=${MYPN}-${PV}

DESCRIPTION="A deep learning framework"
HOMEPAGE="https://pytorch.org/"
SRC_URI="https://github.com/pytorch/${MYPN}/archive/refs/tags/v${PV}.tar.gz
	-> ${MYP}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda ffmpeg nnpack +numpy opencl opencv openmp qnnpack rocm xnnpack"
RESTRICT="test"
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	ffmpeg? ( opencv )
	?? ( cuda rocm )
	rocm? ( ${ROCM_REQUIRED_USE} )
"

RDEPEND="
	${PYTHON_DEPS}
	dev-cpp/gflags:=
	>=dev-cpp/glog-0.5.0
	dev-libs/cpuinfo
	dev-libs/libfmt
	dev-libs/protobuf:=
	dev-libs/pthreadpool
	dev-libs/sleef
	sci-libs/lapack
	sci-libs/onnx
	sci-libs/foxi
	cuda? (
		=dev-libs/cudnn-8*
		dev-libs/cudnn-frontend:0/8
		dev-util/nvidia-cuda-toolkit:=[profiler]
	)
	ffmpeg? ( media-video/ffmpeg:= )
	nnpack? ( sci-libs/NNPACK )
	numpy? ( $(python_gen_cond_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		') )
	opencl? ( virtual/opencl )
	opencv? ( media-libs/opencv:= )
	rocm? (
		dev-util/hip
		dev-util/roctracer
		dev-libs/rccl[${ROCM_USEDEP}]
		sci-libs/hipFFT[${ROCM_USEDEP}]
		sci-libs/hipSPARSE[${ROCM_USEDEP}]
		sci-libs/hipCUB[${ROCM_USEDEP}]
		sci-libs/miopen[${ROCM_USEDEP}]
		sci-libs/rocBLAS[${ROCM_USEDEP}]
		sci-libs/rocFFT[${ROCM_USEDEP}]
		sci-libs/rocPRIM[${ROCM_USEDEP}]
		sci-libs/rocRAND[${ROCM_USEDEP}]
		sci-libs/rocThrust[${ROCM_USEDEP}]
	)
	qnnpack? ( sci-libs/QNNPACK )
	xnnpack? ( sci-libs/XNNPACK )
"
DEPEND="
	${RDEPEND}
	dev-cpp/eigen
	dev-libs/psimd
	dev-libs/FP16
	dev-libs/FXdiv
	dev-libs/pocketfft
	dev-libs/flatbuffers
	$(python_gen_cond_dep '
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/pybind11[${PYTHON_USEDEP}]
	')
"

S="${WORKDIR}"/${MYP}

PATCHES=(
	"${FILESDIR}"/${PN}-1.11.0-gentoo.patch
	"${FILESDIR}"/${PN}-1.12.0-install-dirs.patch
	"${FILESDIR}"/${P}-glog-0.6.0.patch
	"${FILESDIR}"/${P}-clang.patch
	"${FILESDIR}"/find-hip.patch
	"${FILESDIR}"/specify-rocm-arch.patch
	"${FILESDIR}"/disable-frexp.patch
)

src_prepare() {
	filter-lto #bug 862672
	cmake_src_prepare
	pushd torch/csrc/jit/serialization || die
	flatc --cpp --gen-mutable --scoped-enums mobile_bytecode.fbs || die
	popd

	sed -e "s,\${ROCM_PATH}/lib,\${ROCM_PATH}/$(get_libdir),g" -i cmake/public/LoadHIP.cmake || die

	if use rocm; then
		ebegin "HIPifying cuda sources"
		${EPYTHON} tools/amd_build/build_amd.py || die
		eend $?
		for rocm_lib in rocblas hipfft hipsparse; do
			sed -e "/#include <${rocm_lib}.h>/s,${rocm_lib}.h,${rocm_lib}/${rocm_lib}.h," \
				-i $(grep -rl "#include <${rocm_lib}.h>" .) || die
		done
	fi
}

src_configure() {
	if use cuda && [[ -z ${TORCH_CUDA_ARCH_LIST} ]]; then
		ewarn "WARNING: caffe2 is being built with its default CUDA compute capabilities: 3.5 and 7.0."
		ewarn "These may not be optimal for your GPU."
		ewarn ""
		ewarn "To configure caffe2 with the CUDA compute capability that is optimal for your GPU,"
		ewarn "set TORCH_CUDA_ARCH_LIST in your make.conf, and re-emerge caffe2."
		ewarn "For example, to use CUDA capability 7.5 & 3.5, add: TORCH_CUDA_ARCH_LIST=7.5,3.5"
		ewarn "For a Maxwell model GPU, an example value would be: TORCH_CUDA_ARCH_LIST=Maxwell"
		ewarn ""
		ewarn "You can look up your GPU's CUDA compute capability at https://developer.nvidia.com/cuda-gpus"
		ewarn "or by running /opt/cuda/extras/demo_suite/deviceQuery | grep 'CUDA Capability'"
	fi

	local mycmakeargs=(
		-DBUILD_CUSTOM_PROTOBUF=OFF
		-DBUILD_SHARED_LIBS=ON

		-DUSE_CCACHE=OFF
		-DUSE_CUDA=$(usex cuda)
		-DUSE_CUDNN=$(usex cuda)
		-DUSE_FAST_NVCC=$(usex cuda)
		-DTORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-3.5 7.0}"
		-DUSE_DISTRIBUTED=OFF
		-DUSE_FAKELOWP=OFF
		-DUSE_FBGEMM=OFF # TODO
		-DUSE_FFMPEG=$(usex ffmpeg)
		-DUSE_GFLAGS=ON
		-DUSE_GLOG=ON
		-DUSE_GLOO=OFF
		-DUSE_KINETO=OFF # TODO
		-DUSE_LEVELDB=OFF
		-DUSE_MAGMA=OFF # TODO: In GURU as sci-libs/magma
		-DUSE_MKLDNN=OFF
		-DUSE_NCCL=OFF # TODO: NVIDIA Collective Communication Library
		-DUSE_NNPACK=$(usex nnpack)
		-DUSE_QNNPACK=$(usex qnnpack)
		-DUSE_XNNPACK=$(usex xnnpack)
		-DUSE_SYSTEM_XNNPACK=$(usex xnnpack)
		-DUSE_PYTORCH_QNNPACK=OFF
		-DUSE_NUMPY=$(usex numpy)
		-DUSE_OPENCL=$(usex opencl)
		-DUSE_OPENCV=$(usex opencv)
		-DUSE_OPENMP=$(usex openmp)
		-DUSE_ROCM=$(usex rocm)
		-DUSE_SYSTEM_CPUINFO=ON
		-DUSE_SYSTEM_BIND11=ON
		-DPYBIND11_PYTHON_VERSION="${EPYTHON#python}"
		-DPYTHON_EXECUTABLE="${PYTHON}"
		-DUSE_SYSTEM_EIGEN_INSTALL=ON
		-DUSE_SYSTEM_PTHREADPOOL=ON
		-DUSE_SYSTEM_FXDIV=ON
		-DUSE_SYSTEM_FP16=ON
		-DUSE_SYSTEM_GLOO=ON
		-DUSE_SYSTEM_ONNX=ON
		-DUSE_SYSTEM_SLEEF=ON
		-DUSE_TENSORPIPE=OFF

		-Wno-dev
		-DTORCH_INSTALL_LIB_DIR="${EPREFIX}"/usr/$(get_libdir)
		-DLIBSHM_INSTALL_LIB_SUBDIR="${EPREFIX}"/usr/$(get_libdir)
	)
	if use rocm; then
			mycmakeargs+=(
			-DPYTORCH_ROCM_ARCH="$(get_amdgpu_flags)"
			-DROCM_VERSION_DEV_RAW=${ROCM_VERSION}
			-DCMAKE_MODULE_PATH="${EPREFIX}/usr/$(get_libdir)/cmake/hip"
		)
	fi

	use cuda && addpredict "/dev/nvidiactl" # bug 867706
	use rocm && export HIP_PATH="${EPREFIX}/usr"
	cmake_src_configure
}

src_install() {
	cmake_src_install

	insinto "/var/lib/${PN}"
	doins "${BUILD_DIR}"/CMakeCache.txt

	rm -rf python
	mkdir -p python/torch/include || die
	mv "${ED}"/usr/lib/python*/site-packages/caffe2 python/ || die
	mv "${ED}"/usr/include/torch python/torch/include || die
	cp torch/version.py python/torch/ || die
	python_domodule python/caffe2
	python_domodule python/torch
}
