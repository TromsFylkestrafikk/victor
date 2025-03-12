#!/bin/bash

DIR_VICTOR=$(dirname $(dirname $(realpath $0)))
PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf

function usage {
    echo "$(basename $0) [OPTIONS] [PBF_URL]

This is a simple frontend to tilemaker for generating openmaptiles compatible
mbtiles files based on regional data.

PBF_URL is a url containing a osm.pbf dump, usually from geofabrik.de.
Defaults is $PBF_URL

OPTIONS
    -h          This help
    -o OUTPUT   Destination of .mbtiles file. Default destination is in the
                tiles folder.
"
}

PBF=""
while getopts "ho:" option; do
    case $option in
        h) usage
           exit
           ;;
        o) PBF=$OPTARG
           ;;
        *) usage
           exit
           ;;
    esac
done
shift $(($OPTIND - 1))


if [[ ! -z $1 ]]; then
    PBF_URL=$1
fi

if [[ ${PBF_URL: -8} != '.osm.pbf' ]]; then
    echo "Wrong file extension in downloaded chunk. Expected '.osm.pbf'" > /dev/stderr
    exit
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)
if [[ $PBF = "" ]]; then
    PBF=$DIR_VICTOR/tilemaker/osm/$AREA.osm.pbf
fi
MBTILES=$DIR_VICTOR/tiles/$AREA.mbtiles
echo "Victor dir:       $DIR_VICTOR"
echo "Downloading from: $PBF_URL"
echo "Saving to:        $PBF"
echo "Writing tiles to: $MBTILES"
echo "Lets go!"

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
        curl -Ssf --output $PBF $PBF_URL
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
    pushd $DIR_VICTOR/tilemaker > /dev/null
    echo -n "Generating world-wide coastlines and landcover ..."
    if ! which tilemaker > /dev/null; then
        echo "\ntilemaker executable not found. Install and continue" > /dev/stderr
        exit
    fi
    rm -f $MBTILES
    resources=$DIR_VICTOR/tilemaker/resources
    tilemaker --input $PBF \
              --output $MBTILES \
              --bbox -180,-85,180,85 \
              --config $resources/config-coastline.json \
              --process $resources/process-coastline.lua
    echo "done"
    return
    echo -n "Adding $AREA to tiles ..."
    tilemaker --input $PBF \
              --output $MBTILES \
              --merge \
              --process $resources/process-openmaptiles.lua \
              --config $resources/config-openmaptiles.json
    popd > /dev/null
    echo "done"
}

download
gen_tiles
