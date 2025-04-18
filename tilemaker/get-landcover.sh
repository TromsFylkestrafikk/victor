#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DIR_TILEMAKER=$(realpath $(dirname $0))

mkdir -p $DIR_TILEMAKER/landcover
cd $DIR_TILEMAKER/landcover

if ! [ -f "ne_10m_antarctic_ice_shelves_polys.zip" ]; then
    curl -sfO https://naciscdn.org/naturalearth/10m/physical/ne_10m_antarctic_ice_shelves_polys.zip
    mkdir -p ne_10m_antarctic_ice_shelves_polys
    unzip -o ne_10m_antarctic_ice_shelves_polys.zip -d ne_10m_antarctic_ice_shelves_polys
fi

if ! [ -f "ne_10m_urban_areas.zip" ]; then
    curl -sfO https://naciscdn.org/naturalearth/10m/cultural/ne_10m_urban_areas.zip
    mkdir -p ne_10m_urban_areas
    unzip -o ne_10m_urban_areas.zip -d ne_10m_urban_areas
fi

if ! [ -f "ne_10m_glaciated_areas.zip" ]; then
    curl -sfO https://naciscdn.org/naturalearth/10m/physical/ne_10m_glaciated_areas.zip
    mkdir -p ne_10m_glaciated_areas
    unzip -o ne_10m_glaciated_areas.zip -d ne_10m_glaciated_areas
fi
