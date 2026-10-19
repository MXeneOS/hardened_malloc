#!/usr/bin/env bash
# Checks for the candidate branch (run from inside the repository):
#  1. no added line in .c/.h files uses MADV_DONTNEED_LOCKED (needs Linux 5.18, garnet runs 5.10)
#  2. the allocator builds with the Android settings (1 GiB class region, one arena)
#  3. upstream's tests pass on a normal kernel
#  4. upstream's tests pass when MADV_DONTNEED_LOCKED fails with EINVAL, like on Linux 5.10
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(git rev-parse --show-toplevel)
base=${BASE_REF:-origin/${BASE_BRANCH:-main}}
cd "$root"

echo "== 1. guard: no new MADV_DONTNEED_LOCKED"
if git diff "$base"...HEAD -- '*.c' '*.h' | grep '^+' | grep -v '^+++' | grep -n 'MADV_DONTNEED_LOCKED'; then
  echo "FAIL: the new commits use MADV_DONTNEED_LOCKED"; exit 1
fi

gcc -shared -fPIC -O1 "$here/shim510.c" -o "$root/shim510.so" -ldl

echo "== 2. build with the Android settings"
make clean > /dev/null 2>&1 || true
CC=${CC:-gcc} CXX=${CXX:-g++} make CONFIG_CLASS_REGION_SIZE=1073741824 CONFIG_N_ARENA=1

echo "== 3. make test (normal kernel)"
make clean > /dev/null 2>&1 || true
CC=${CC:-gcc} CXX=${CXX:-g++} make test

echo "== 4. make test (MADV_DONTNEED_LOCKED -> EINVAL, like Linux 5.10)"
make clean > /dev/null 2>&1 || true
LD_PRELOAD="$root/shim510.so" CC=${CC:-gcc} CXX=${CXX:-g++} make test
