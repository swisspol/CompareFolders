#!/bin/sh -e

for DIRECTORY in *; do
  if [ -d "$DIRECTORY" ]; then
    if [ -e "$DIRECTORY/.git" ]; then
      echo "Updating $DIRECTORY..."
      pushd "$DIRECTORY"
      git fetch
      git pull
      popd
    fi
  fi
done
