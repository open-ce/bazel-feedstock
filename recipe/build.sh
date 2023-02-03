#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2018, 2022. All Rights Reserved.
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
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

if [[ $ppc_arch == "p10" ]]
then
    if [[ -z "${GCC_11_HOME}" ]];
    then
        echo "Please set GCC_11_HOME to the install path of gcc-toolset-11"
        exit 1
    fi
fi

#Linux - set flags for statically linking libstdc++
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39

export BAZEL_LINKOPTS="-static-libstdc++ -static-libgcc"
export BAZEL_LINKLIBS="-l%:libstdc++.a:-lm"

#Use the Java11 CDT for PPC builds and Anaconda's openjdk 11 on x86

if [[ ${target_platform} =~ .*ppc.* ]]; then
  SYSROOT_DIR="${BUILD_PREFIX}"/powerpc64le-conda_cos7-linux-gnu/sysroot/usr/
  jvm_slug=$(compgen -G "${SYSROOT_DIR}/lib/jvm/java-11-openjdk-*")
  export JAVA_HOME=${jvm_slug}

  #Use the zip CDT
  zip_slug="${SYSROOT_DIR}"/bin
  export PATH=$PATH:${zip_slug}

elif [[ ${target_platform} =~ .*x86_64.* || ${target_platform} =~ .*linux-64.* ]]; then
  export JAVA_HOME=$BUILD_PREFIX
  SYSROOT_DIR="${BUILD_PREFIX}"/x86_64-conda_cos6-linux-gnu/sysroot/usr/
elif [[ ${target_platform} =~ .*s390x.* ]]; then
  SYSROOT_DIR="${BUILD_PREFIX}"/s390x-conda_cos7-linux-gnu/sysroot/usr/
  jvm_slug=$(compgen -G "${SYSROOT_DIR}/lib/jvm/java-11-openjdk-*")
  export JAVA_HOME=${jvm_slug}

  #Use the zip CDT
  zip_slug="${SYSROOT_DIR}"/bin
  export PATH=$PATH:${zip_slug}

fi

export PATH=$PATH:$JAVA_HOME/bin
bash compile.sh
mkdir -p $PREFIX/bin
mv output/bazel $PREFIX/bin

# Run test here, because we lose $RECIPE_DIR in the test portion
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial

bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
#PID1=$(bazel build server_pid)
#echo "PID: $PID1"

bazel info | grep "java-home.*embedded_tools"

PID2=$(bazel info server_pid)
echo "PID: $PID2"

sleep 100
#ls -ltrh /proc | grep $PID

bazel clean --expunge
bazel shutdown

#sleep 6000

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
