#!/bin/bash
# ***************************************************************** 
#                                                              
# Licensed Materials - Property of IBM                            
#                                                                   
# (C) Copyright IBM Corp. 2019. All Rights Reserved.                
#                                                                  
# US Government Users Restricted Rights - Use, duplication or      
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp. 
#                                                                  
# *****************************************************************
set -v -x

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"
#Linux - set flags for statically linking libstdc++
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
export BAZEL_LINKOPTS="-static-libstdc++ -static-libgcc"
export BAZEL_LINKLIBS="-l%:libstdc++.a"

#Use the Java8 CDT
if [[ ${target_platform} =~ .*ppc.* ]]; then
  SYSROOT_DIR="${BUILD_PREFIX}"/powerpc64le-conda_cos7-linux-gnu/sysroot/usr/
elif [[ ${target_platform} =~ .*x86_64.* || ${target_platform} =~ .*linux-64.* ]]; then
  SYSROOT_DIR="${BUILD_PREFIX}"/x86_64-conda_cos6-linux-gnu/sysroot/usr/
fi
jvm_slug=$(compgen -G "${SYSROOT_DIR}/lib/jvm/java-1.8.0-openjdk-*")
export JAVA_HOME=${jvm_slug}

#Use the zip CDT
zip_slug="${SYSROOT_DIR}"/bin
export PATH=$PATH:${zip_slug}

bash compile.sh
mkdir -p $PREFIX/bin
mv output/bazel $PREFIX/bin

# Run test here, because we lose $RECIPE_DIR in the test portion
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
bazel info | grep "java-home.*embedded_tools"

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
