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

# @ECLASS_VARIABLE: ALL_AMDGPU_TARGETS
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The list of USE flags corresponding to all AMDGPU targets in this ROCm
# version.  The value depends on ${PV}.

case ${PV} in
	4*)
		ALL_AMDGPU_TARGETS=(
			gfx803 gfx900 gfx906 gfx908 gfx90a gfx90a 
			gfx1010 gfx1011 gfx1012 gfx1030
		)
		;;
	*)
		ALL_AMDGPU_TARGETS=(
			gfx803 gfx900 gfx906 gfx908 gfx90a gfx90a 
			gfx1010 gfx1011 gfx1012 gfx1030 gfx1031
		)
		;;
esac

# @ECLASS_VARIABLE: AMDGPU_TARGET_FLAGS
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The varuble passed to cmake by -DAMDGPU_TARGETS=${AMDGPU_TARGET_FLAGS}
# which controls what GPU target to be compiled




_ROCM_ECLASS=1
fi
