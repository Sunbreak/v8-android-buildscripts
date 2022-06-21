#!/bin/bash -e
source $(dirname $0)/env.sh
BUILD_TYPE="Release"
# BUILD_TYPE="Debug"

GN_ARGS_BASE='
  target_os="android"
  is_component_build=false
  use_debug_fission=false
  use_custom_libcxx=false
  v8_use_snapshot = true
  v8_use_external_startup_data = false
  icu_use_data_file=false
  v8_enable_lite_mode=true
  is_asan=true
'

if [[ ${NO_INTL} -eq "1" ]]; then
  GN_ARGS_BASE="${GN_ARGS_BASE} v8_enable_i18n_support=false"
fi

if [[ "$BUILD_TYPE" = "Debug" ]]
then
  GN_ARGS_BUILD_TYPE='
    is_debug=true
    symbol_level=2
  '
else
  GN_ARGS_BUILD_TYPE='
    is_debug=false
  '
fi

NINJA_PARAMS=""

if [[ ${CIRCLECI} ]]; then
  NINJA_PARAMS="-j4"
fi

cd $V8_DIR

function normalize_arch_for_android()
{
  local arch=$1
  case "$1" in
    arm)
      echo "armeabi-v7a"
      ;;
    x86)
      echo "x86"
      ;;
    arm64)
      echo "arm64-v8a"
      ;;
    x64)
      echo "x86_64"
      ;;
    *)
      echo "Invalid arch - $arch" >&2
      exit 1
      ;;
  esac
}

function build_arch()
{
    local arch=$1
    local arch_for_android=$(normalize_arch_for_android $arch)

    echo "Build v8 $arch variant NO_INTL=${NO_INTL}"
    gn gen --args="$GN_ARGS_BASE $GN_ARGS_BUILD_TYPE target_cpu=\"$arch\"" out.v8.$arch

    if [[ ${MKSNAPSHOT_ONLY} -eq "1" ]]; then
      date ; ninja ${NINJA_PARAMS} -C out.v8.$arch run_mksnapshot_default ; date
    else
      date ; ninja ${NINJA_PARAMS} -C out.v8.$arch libv8android ; date

      mkdir -p $BUILD_DIR/lib/$arch_for_android
      cp -f out.v8.$arch/libv8android.so $BUILD_DIR/lib/$arch_for_android/libv8android.so
      mkdir -p $BUILD_DIR/lib.unstripped/$arch_for_android
      cp -f out.v8.$arch/lib.unstripped/libv8android.so $BUILD_DIR/lib.unstripped/$arch_for_android/libv8android.so
    fi

    mkdir -p $BUILD_DIR/tools/$arch_for_android
    cp -f out.v8.$arch/clang_*/mksnapshot $BUILD_DIR/tools/$arch_for_android/mksnapshot
}

build_arch "arm"
build_arch "x86"
build_arch "arm64"
######################################################################################
# FIXME
# ninja: Entering directory `out.v8.x64'
# [1/1] SOLINK_MODULE ./libv8android.so
# FAILED: libv8android.so lib.unstripped/libv8android.so 
# ld.lld: error: cannot open v8-android-buildscripts/v8/third_party/llvm-build/Release+Asserts/lib/clang/10.0.0/lib/linux/libclang_rt.asan-x86_64-android.so: No such file or directory
######################################################################################
# build_arch "x64" 
