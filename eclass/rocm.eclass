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

inherit cmake llvm

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

_ROCM_ECLASS=1
fi
