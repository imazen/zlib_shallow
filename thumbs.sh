#!/bin/bash

# THe Ultimate Make Bash Script
# Used to wrap build scripts for easy dep
# handling and multiplatform support


# Basic usage on *nix:
# export tbs_arch=x86
# ./thumbs.sh make


# On Win (msvc 2015):
# C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall x86_amd64
# SET tbs_tools=msvc14
# thumbs make

# On Win (mingw32):
# SET path=C:\mingw32\bin;%path%
# SET tbs_tools=mingw
# SET tbs_arch=x86
# thumbs make


# Global settings are stored in env vars
# Should be inherited

[ $tbs_conf ]           || export tbs_conf=Release
[ $tbs_arch ]           || export tbs_arch=x64
[ $tbs_tools ]          || export tbs_tools=gnu
[ $tbs_static_runtime ] || export tbs_static_runtime=0

# -----------

if [ $# -lt 1 ]
then
  echo ""
  echo " Usage : ./thumbs.sh [command]"
  echo ""
  echo " Commands:"
  echo "   make [target]   - builds everything"
  echo "   check           - runs tests"
  echo "   clean           - removes build files"
  echo "   list            - echo paths to any interesting files"
  echo "                     space separated; relative"
  echo "   list_bin        - echo binary paths"
  echo "   list_inc        - echo lib include files"
  echo "   list_slib       - echo static lib path"
  echo "   list_dlib       - echo dynamic lib path"
  echo ""
  exit
fi

# -----------

upper()
{
  echo $1 | tr [:lower:] [:upper:]
}

# Local settings

l_inc="./zlib.h ./zutil.h ./build/zconf.h"
l_slib=
l_dlib=
l_bin=
list=

make=
c_flags=
cm_tools=
cm_args=(-DCMAKE_BUILD_TYPE=$tbs_conf)

target=
[ $2 ] && target=$2

# -----------

case "$tbs_tools" in
msvc14)
  # d suffix for debug builds
  csx=
  [ "$tbs_conf" = "Debug" ] && csx=d
  
  cm_tools="Visual Studio 14"
  [ "$target" = "" ] && mstrg="zlib.sln" || mstrg="$target.vcxproj"
  make="msbuild.exe $mstrg //p:Configuration=$tbs_conf //v:m"
  l_slib="./build/$tbs_conf/zlibstatic$csx.lib"
  l_dlib="./build/$tbs_conf/zlib$csx.lib"
  l_bin="./build/$tbs_conf/zlib$csx.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;
  
gnu)
  cm_tools="Unix Makefiles"
  c_flags+=" -fPIC"
  make="make $target"
  l_slib="./build/libz.a"
  l_dlib="./build/libz.so.1.2.7.3"
  l_bin="$l_dlib"
  list="$l_slib $l_dlib $l_inc" ;;
  
mingw)
  cm_tools="MinGW Makefiles"
  make="mingw32-make $target"
  
  # allow sh in path; some old cmake/mingw bug?
  cm_args+=(-DCMAKE_SH=)
  
  l_slib="./build/libzlibstatic.a"
  l_dlib="./build/libzlib.dll.a"
  l_bin="./build/libzlib.dll"
  list="$l_bin $l_slib $l_dlib $l_inc" ;;

*) echo "Tool config not found for $tbs_tools"
   exit 1 ;;
esac

# -----------

case "$tbs_arch" in
x64)
  [ $tbs_tools = msvc14 ] && cm_tools="$cm_tools Win64"
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m64" ;;
x86)
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && c_flags+=" -m32" ;;

*) echo "Arch config not found for $tbs_arch"
   exit 1 ;;
esac

# -----------

if [ $tbs_static_runtime -gt 0 ]
then
  [ $tbs_tools = msvc12 ] && c_flags+=" /MT"
  [ $tbs_tools = gnu -o $tbs_tools = mingw ] && cm_args+=(-DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc)
fi

# -----------

case "$1" in
make)
  mkdir build
  cd build
  cm_args+=(-DCMAKE_C_FLAGS_$(upper $tbs_conf)="$c_flags")
  cmake -G "$cm_tools" "${cm_args[@]}" .. || exit 1
  $make || exit 1
  cd .. ;;
  
check)
  cd build
  ctest . || exit 1
  cd .. ;;
  
clean)
  rm -rf build ;;

list) echo $list ;;
list_bin) echo $l_bin ;;
list_inc) echo $l_inc ;;
list_slib) echo $l_slib ;;
list_dlib) echo $l_dlib ;;

*) echo "Unknown command $1"
   exit 1 ;;
esac
