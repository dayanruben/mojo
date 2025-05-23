#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
# Copyright (c) 2025, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##===----------------------------------------------------------------------===##

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(realpath "${SCRIPT_DIR}/../..")
EXAMPLES_DIR="${REPO_ROOT}"/examples/mojo

BUILD_DIR="${REPO_ROOT}"/mojo/build
mkdir -p "${BUILD_DIR}"

source "${REPO_ROOT}"/mojo/stdlib/scripts/build-stdlib.sh

# Run the examples using `lit`.
lit -sv "${EXAMPLES_DIR}"
