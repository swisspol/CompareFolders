#!/bin/sh -e

for DIRECTORY in *; do
  if [ -d "$DIRECTORY" ]; then
    if [ -e "$DIRECTORY/.git" ]; then
      echo "Updating $DIRECTORY..."
      git fetch
      git pull
    fi
  fi
done
