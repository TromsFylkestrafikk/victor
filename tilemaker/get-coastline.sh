#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DIR_TILEMAKER=$(realpath $(dirname $0))

mkdir -p $DIR_TILEMAKER/coastline
cd $DIR_TILEMAKER/coastline

if ! [ -f "water-polygons-split-4326.zip" ]; then
  curl -sfO https://osmdata.openstreetmap.de/download/water-polygons-split-4326.zip
  unzip -o -j water-polygons-split-4326.zip
fi
