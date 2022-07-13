# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rocm.eclass
# @MAINTAINER:
# Gentoo Science Project <sci@gentoo.org>
# @AUTHOR:
# Yiyang Wu <xgreenlandforwyy@gmail.com>
# @SUPPORTED_EAPIS: 8
# @BLURB: common functions for ROCm packages written in HIP
# @DESCRIPTION:
# ROCm packages such as sci-libs/<roc|hip>* can utilize functions in this eclass.
# Currently, it handles the AMDGPU_TARGETS variable via USE_EXPAND, so user can
# use USE flag to control which GPU architecture to compile, and ensure coherence
# among dependencies. It also specify CXX=hipcc, to let hipcc compile. Another
# important function is src_test, which checks whether a valid KFD device exists
# for testing, and then execute the test program.
# @EXAMPLE:
# inherit rocm

if [[ ! ${_ROCM_ECLASS} ]]; then

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI} unsupported."
esac

inherit cmake llvm edo

# @ECLASS_VARIABLE: OFFICIAL_AMDGPU_TARGETS
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The list of USE flags corresponding to all AMDGPU targets in this ROCm
# version.  The value depends on ${PV}.

case ${PV} in
	4*)
		OFFICIAL_AMDGPU_TARGETS=(
			gfx906 gfx908
		)
		;;
	5*)
		OFFICIAL_AMDGPU_TARGETS=(
			gfx906 gfx908 gfx90a gfx1030
		)
		;;
	*)
		die "Unknown ROCm major version! Please update rocm.eclass before bumping to new ebuilds"
		;;
esac

# @ECLASS_VARIABLE: ALL_AMDGPU_TARGETS
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The list of USE flags corresponding to all AMDGPU targets in this ROCm
# version.  The value depends on ${PV}.
# Architectures and devices map: https://www.coelacanth-dream.com/posts/2019/12/30/did-rid-product-matome-p2

case ${PV} in
	4*)
		ALL_AMDGPU_TARGETS=(
			gfx803 gfx900 gfx906 gfx908
			gfx1010 gfx1011 gfx1012 gfx1030
		)
		;;
	5*)
		ALL_AMDGPU_TARGETS=(
			gfx803 gfx900 gfx906 gfx908 gfx90a
			gfx1010 gfx1011 gfx1012 gfx1030 gfx1031
		)
		;;
	*)
		die "Unknown ROCm major version! Please update rocm.eclass before bumping to new ebuilds"
		;;
esac

REQUIRED_USE+=" || ("
for gpu_target in ${ALL_AMDGPU_TARGETS[@]}; do
	if [[ " ${OFFICIAL_AMDGPU_TARGETS[*]} " =~ " ${gpu_target} " ]]; then
		IUSE+=" ${gpu_target/#/+amdgpu_targets_}"
	else
		IUSE+=" ${gpu_target/#/amdgpu_targets_}"
	fi
	REQUIRED_USE+=" ${gpu_target/#/amdgpu_targets_}"
done
REQUIRED_USE+=" ) "


# @FUNCTION: get_amdgpu_flags
# @DESCRIPTION:
# Convert specified use flag of amdgpu_targets to compilation flags 
# Append target feature to gpu arch. See https://llvm.org/docs/AMDGPUUsage.html#id67
get_amdgpu_flags() {
	local AMDGPU_TARGET_FLAGS
	for gpu_target in ${ALL_AMDGPU_TARGETS[@]}; do
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
# @DESCRIPTION:
# check read and write permissions on specific files.
# allow using wildcard, for example check_rw_permission /dev/dri/render*
check_rw_permission() {
	[ -r "$1" ] && [ -w "$1" ] || die \
		"${PORTAGE_USERNAME} do not have read or write permissions on $1! \n Make sure ${PORTAGE_USERNAME} is in render group and check the permissions."
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

	# do not rerun cmake and the build process in src_install
	sed -e '/RERUN/,+1d' -i "${BUILD_DIR}"/build.ninja || die
}

# @FUNCTION: rocm_src_test
# @DESCRIPTION:
# Test whether valid GPU device is present. If so, find how to, and execute test.
# ROCm packages can have to test mechanism:
# 1. cmake_src_test. Usually we set MAKEOPTS="-j1" to make sure only one test on GPU at a time
# 2. one single gtest binary called "${PN,,}"-test.
# 3. Some package like rocFFT have alternative test like rocfft-selftest
rocm_src_test() {
	addwrite /dev/kfd
	addwrite /dev/dri/

	# check permissions on /dev/kfd and /dev/dri/render*
	check_rw_permission /dev/kfd
	check_rw_permission /dev/dri/render*

	if grep -q 'build test:' "${BUILD_DIR}"/build.ninja; then
		einfo "Testing using ninja test"
		MAKEOPTS="-j1" cmake_src_test
	elif [ -d "${BUILD_DIR}"/clients/staging ]; then
		cd "${BUILD_DIR}/clients/staging" || die "Test directory not found!"
		for test_program in "${PN,,}-"*test; do
			if [ -x ${test_program} ]; then
				LD_LIBRARY_PATH="${BUILD_DIR}/clients":"${BUILD_DIR}/library":"${BUILD_DIR}/library/src":"${BUILD_DIR}/library/src/device" edob ./${test_program}
			else
				die "The test program ${test_program} does not exist or cannot be excuted!"
			fi
		done
	else
		die "There is no cmake tests, nor ${BUILD_DIR}/clients/staging where test program might be located."
	fi
}

_ROCM_ECLASS=1
fi
