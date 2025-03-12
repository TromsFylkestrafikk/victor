#!/bin/bash

DIR_VICTOR=$(realpath $(dirname $(dirname $0)))

PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf

if [[ ${PBF_URL: -8} != '.osm.pbf' ]]; then
    echo "Wrong file extension in downloaded chunk. Expected '.osm.pbf'" > /dev/stderr
    exit
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)
PBF=$DIR_VICTOR/tilemaker/osm/$AREA.osm.pbf

function download {
    pushd $DIR_VICTOR/tilemaker > /dev/null
    echo -n "Downloading coastlines ... "
    ./get-coastline.sh
    echo "OK"
    echo -n "Downloading landcover ... "
    ./get-landcover.sh
    echo "OK"

    mkdir -p $DIR_VICTOR/tilemaker/osm

    echo -n "Downloading OSM data for $AREA "
    if [ ! -f $PBF -o $(($(date +%s) - $(date -r $PBF +%s))) -gt 86000 ]; then
        #curl -Ssf --output $PBF $PBF_URL
        echo -n " ... "
    fi
    echo "OK"

    if [[ ! -f $PBF ]]; then
        echo "Download of OSM data from '$PBF_URL' to destination '$PBF' failed" > /dev/stderr
        exit
    fi
    popd > /dev/null
}

function gen_tiles {
    echo -n "Generating world-wide coastlines and landcover ..."
}

download
gen_tiles
