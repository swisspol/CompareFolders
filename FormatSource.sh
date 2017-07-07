#!/bin/bash -ex

# brew install clang-format

CLANG_FORMAT_VERSION=`clang-format -version | awk '{ print $3 }'`
if [[ "$CLANG_FORMAT_VERSION" != "5.0.0" ]]; then
  echo "Unsupported clang-format version"
  exit 1
fi

pushd "Classes"
clang-format -style=file -i *.h *.m
popd

echo "OK"
