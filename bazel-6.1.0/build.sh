#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2018, 2023. All Rights Reserved.
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
source open-ce-common-utils.sh

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

if [[ $ppc_arch == "p10" ]]
then
    if [[ -z "${GCC_HOME}" ]];
    then
        echo "Please set GCC_HOME to the install path of gcc-toolset-12"
        exit 1
    fi
fi

#Linux - set flags for statically linking libstdc++
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39

export BAZEL_LINKOPTS="-static-libstdc++ -static-libgcc"
export BAZEL_LINKLIBS="-l%:libstdc++.a:-lm"

# Use the system-installed JDK (from RHEL or compatible)

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export PATH=$JAVA_HOME/bin:$PATH

bash compile.sh
mkdir -p $PREFIX/bin
mv output/bazel $PREFIX/bin

# Run test here, because we lose $RECIPE_DIR in the test portion
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial

bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world

bazel info | grep "java-home.*embedded_tools"

PID=$(bazel info server_pid)
echo "PID: $PID"

cleanup_bazel $PID

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
