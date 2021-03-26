#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2018, 2021. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************
set -v -x

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"
#Linux - set flags for statically linking libstdc++
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
export BAZEL_LINKOPTS="-static-libstdc++ -static-libgcc"
export BAZEL_LINKLIBS="-l%:libstdc++.a"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

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
bazel shutdown
bazel clean --expunge


if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
