# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rocm.eclass
# @MAINTAINER:
# Gentoo Science Project <sci@gentoo.org>
# @AUTHOR:
# Yiyang Wu <xgreenlandforwyy@gmail.com>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Common functions and variables for ROCm packages written in HIP
# @DESCRIPTION:
# ROCm packages such as sci-libs/<roc|hip>* can utilize functions in this
# eclass.  Currently, it handles the AMDGPU_TARGETS variable via USE_EXPAND, so
# user can use USE flag to control which GPU architecture to compile, and
# ensure coherence among dependencies. It also specify CXX=hipcc, to let hipcc
# compile. Another important function is src_test, which checks whether a valid
# KFD device exists for testing, and then execute the test program.
#
# Most ROCm packages use cmake as build system, so this eclass does not export
# phase functions which overwrites the phase functions in cmake.eclass. Ebuild
# should explicitly call rocm_src_* in src_configure and src_test.
#
# @EXAMPLE:
# # Example for ROCm packages in https://github.com/ROCmSoftwarePlatform
# @CODE
# inherit cmake rocm
# SRC_URI="https://github.com/ROCmSoftwarePlatform/${PN}/archive/rocm-${PV}.tar.gz -> ${P}.tar.gz"
# SLOT="0/$(ver_cut 1-2)"
# IUSE="test"
# REQUIRED_USE="${ROCM_REQUIRED_USE}"
# RESTRICT="!test? ( test )"
#
# RDEPEND="
#     dev-util/hip
#     sci-libs/rocBLAS:${SLOT}[${ROCM_USEDEP}]
# "
#
# S=${WORKDIR}/${PN}-rocm-${PV}
#
# src_configure() {
#     local mycmakeargs=(
#         -DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
#     )
#     rocm_src_configure
# }
#
# src_test() {
#     rocm_src_test
# }
# @CODE
#
# # Example for packages depend on ROCm libraries -- a package depend on
# # rocBLAS, and use comma seperated ${HCC_AMDGPU_TARGET} to determine GPU
# # architecture to compile. Requires ROCm version >5.
# @CODE
# ROCM_VERSION=5
# inherit rocm
# IUSE="rocm"
# REQUIRED_USE="rocm? ( ${ROCM_REQUIRED_USE} )"
# DEPEND="rocm? ( >=dev-util/hip-${ROCM_VERSION}
#     >=sci-libs/rocBLAS-${ROCM_VERSION}[${ROCM_USEDEP}] )"
# ....
# src_configure() {
#     if use rocm; then
#         local AMDGPU_FLAGS=$(get_amdgpu_flags)
#         export HCC_AMDGPU_TARGET=${AMDGPU_FLAGS//;/,}
#     fi
#     default
# }
# @CODE

if [[ ! ${_ROCM_ECLASS} ]]; then

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

inherit edo

# @ECLASS_VARIABLE: ROCM_VERSION
# @DEFAULT_UNSET
# @PRE_INHERIT
# @DESCRIPTION:
# The ROCm version of current package. Default is ${PV}, but for other packages
# that depend on ROCm libraries, this can be set to match the version of
# required ROCm libraries.

# @ECLASS_VARIABLE: ALL_AMDGPU_TARGETS
# @INTERNAL
# @DESCRIPTION:
# The list of USE flags corresponding to all AMDGPU targets in this ROCm
# version. The value depends on ${PV}. Architectures and devices map:
# https://www.coelacanth-dream.com/posts/2019/12/30/did-rid-product-matome-p2

# @ECLASS_VARIABLE: OFFICIAL_AMDGPU_TARGETS
# @INTERNAL
# @DESCRIPTION:
# The list of USE flags corresponding to all officially supported AMDGPU
# targets in this ROCm version, documented at
# https://docs.amd.com/bundle/ROCm-Installation-Guide-v${PV}/page/Prerequisite_Actions.html.
# USE flag of these architectures will be default on. Depends on ${PV}.

# @ECLASS_VARIABLE: ROCM_REQUIRED_USE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# Requires at least one AMDGPU target to be compiled.
# Example use for ROCm libraries:
# @CODE
# REQUIRED_USE="${ROCM_REQUIRED_USE}"
# @CODE
# Example use for packages that depend on ROCm libraries
# @CODE
# IUSE="rocm"
# REQUIRED_USE="rocm? ( ${ROCM_REQUIRED_USE} )"
# @CODE

# @ECLASS_VARIABLE: ROCM_USEDEP
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# This is an eclass-generated USE-dependency string which can be used to
# depend on another ROCm package being built for the same AMDGPU architecture.
#
# The generated USE-flag list is compatible with packages using rocm.eclass.
#
# Example use:
# @CODE
# DEPEND="sci-libs/rocBLAS[${ROCM_USEDEP}]"
# @CODE

# @FUNCTION: _rocm_set_globals
# @DESCRIPTION:
# Set global variables used by the eclass: ALL_AMDGPU_TARGETS,
# OFFICIAL_AMDGPU_TARGETS, ROCM_REQUIRED_USE, and ROCM_USEDEP
_rocm_set_globals() {
	case ${ROCM_VERSION:-${PV}} in
		4.*)
			ALL_AMDGPU_TARGETS=(
				gfx803 gfx900 gfx906 gfx908
				gfx1010 gfx1011 gfx1012 gfx1030
			)
			OFFICIAL_AMDGPU_TARGETS=(
				gfx906 gfx908
			)
			;;
		5.*)
			ALL_AMDGPU_TARGETS=(
				gfx803 gfx900 gfx906 gfx908 gfx90a
				gfx1010 gfx1011 gfx1012 gfx1030 gfx1031
			)
			OFFICIAL_AMDGPU_TARGETS=(
				gfx906 gfx908 gfx90a gfx1030
			)
			;;
		*)
			die "Unknown ROCm major version! Please update rocm.eclass before bumping to new ebuilds"
			;;
	esac

	ROCM_REQUIRED_USE+=" || ("
	for gpu_target in "${ALL_AMDGPU_TARGETS[@]}"; do
		if has "${gpu_target}" "${OFFICIAL_AMDGPU_TARGETS[@]}"; then
			IUSE+=" ${gpu_target/#/+amdgpu_targets_}"
		else
			IUSE+=" ${gpu_target/#/amdgpu_targets_}"
		fi
		ROCM_REQUIRED_USE+=" ${gpu_target/#/amdgpu_targets_}"
	done
	ROCM_REQUIRED_USE+=" ) "

	local flags=( "${ALL_AMDGPU_TARGETS[@]/#/amdgpu_targets_}" )
	local optflags=${flags[@]/%/(-)?}
	ROCM_USEDEP=${optflags// /,}
}
_rocm_set_globals
unset -f _rocm_set_globals


# @FUNCTION: get_amdgpu_flags
# @USAGE: get_amdgpu_flags
# @DESCRIPTION:
# Convert specified use flag of amdgpu_targets to compilation flags.
# Append default target feature to GPU arch. See
# https://llvm.org/docs/AMDGPUUsage.html#target-features
get_amdgpu_flags() {
	local AMDGPU_TARGET_FLAGS
	for gpu_target in "${ALL_AMDGPU_TARGETS[@]}"; do
		local target_feature=
		if use amdgpu_targets_${gpu_target}; then
			case ${gpu_target} in
				gfx906|gfx908)
					target_feature=:xnack-
					;;
				gfx90a)
					target_feature=:xnack+
					;;
				*)
					;;
			esac
			AMDGPU_TARGET_FLAGS+="${gpu_target}${target_feature};"
		fi
	done
	echo ${AMDGPU_TARGET_FLAGS}
}

# @FUNCTION: check_rw_permission
# @USAGE: check_rw_permission <file>
# @DESCRIPTION:
# check read and write permissions on specific files.
# allow using wildcard, for example check_rw_permission /dev/dri/render*
check_rw_permission() {
	[[ -r $1 ]] && [[ -w $1 ]] || die \
		"Portage do not have read or write permissions on $1! \n Make sure both are in render group and check the permissions."
}

# == phase functions ==

# @FUNCTION: rocm_src_configure
# @DESCRIPTION:
# configure rocm packages, and setting common cmake arguments
rocm_src_configure() {
	# allow acces to hardware
	addpredict /dev/kfd
	addpredict /dev/dri/

	mycmakeargs+=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr"
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-DCMAKE_SKIP_RPATH=TRUE
	)

	CXX="hipcc" cmake_src_configure
}

# @FUNCTION: rocm_src_test
# @DESCRIPTION:
# Test whether valid GPU device is present. If so, find how to, and execute test.
# ROCm packages can have to test mechanism:
# 1. cmake_src_test. MAKEOPTS="-j1" ensures only one test on GPU at a time;
# 2. one single gtest binary called "${PN,,}"-test;
# 3. Some package like rocFFT have alternative test like rocfft-selftest;
# 4. Custome testing binaries like dev-libs/rccl. Use ${ROCM_TESTS} to specify.
rocm_src_test() {
	# grant and check permissions on /dev/kfd and /dev/dri/render*
	for device in /dev/kfd /dev/dri/render*; do
		addwrite ${device}
		check_rw_permission ${device}
	done

	: ${LD_LIBRARY_PATH:="${BUILD_DIR}/clients:${BUILD_DIR}/src:${BUILD_DIR}/library:${BUILD_DIR}/library/src:${BUILD_DIR}/library/src/device"}
	export LD_LIBRARY_PATH
	if grep -q 'build test:' "${BUILD_DIR}"/build.ninja; then
		MAKEOPTS="-j1" cmake_src_test
	elif [[ -d ${BUILD_DIR}/clients/staging ]]; then
		cd "${BUILD_DIR}/clients/staging" || die "Test directory not found!"
		for test_program in "${PN,,}-"*test; do
			if [[ -x ${test_program} ]]; then
					edob ./${test_program}
			else
				die "The test program ${test_program} does not exist or cannot be excuted!"
			fi
		done
	elif [[ -n ${ROCM_TESTS} ]]; then
		for test_program in ${ROCM_TESTS}; do
			cd "${BUILD_DIR}" || die
			if [[ -x ${test_program} ]]; then
			edob ./${test_program}
			else
				die "The test program ${test_program} does not exist or cannot be excuted!"
			fi
		done
	else
		die "There is no cmake tests, no \${ROCM_TESTS} executable provided, nor ${BUILD_DIR}/clients/staging where test program might be located."
	fi
}

_ROCM_ECLASS=1
fi
