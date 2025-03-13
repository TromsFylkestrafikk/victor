#!/bin/bash

DIR_VICTOR=$(dirname $(dirname $(realpath $0)))
PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf
MBTILES_WORLD=$DIR_VICTOR/tiles/world_coastlines.mbtiles

function usage {
    echo "$(basename $0) [OPTIONS] [PBF_URL ...]

This is a simple frontend to tilemaker for generating openmaptiles compatible
mbtiles files based on regional data.

PBF_URL is a url containing a osm.pbf dump, usually from geofabrik.de.  Defaults
is $PBF_URL.  Use of multiple URLs will merge all data into the tile set
specified with the -m option, which then is required.

OPTIONS
    -h                  This help.
    -m TILE_FILE        Basename of destination mbtiles file. It will end up in
                        tiles/<MBTILE>.mbtiles.
"
}

MBTILES=""

while getopts "hm:" option; do
    case $option in
        h) usage
           exit
           ;;
        m) MBTILES=$OPTARG
           ;;
        *) usage
           exit
           ;;
    esac
done
shift $(($OPTIND - 1))

if [[ ! -z $2 ]] && [[ $MBTILES = "" ]]; then
    echo "-m option is required with multiple PBF sources" >> /dev/stderr
    exit
fi

if [[ ! -z $1 ]]; then
    PBF_URL=$1
fi

if [[ ${PBF_URL: -8} != '.osm.pbf' ]]; then
    echo "Wrong file extension in downloaded chunk. Expected '.osm.pbf'" > /dev/stderr
    exit
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)
PBF=$DIR_VICTOR/tilemaker/osm/$AREA.osm.pbf

if [[ $MBTILES = "" ]]; then
    MBTILES=$DIR_VICTOR/tiles/$AREA.mbtiles
else
    MBTILES=$DIR_VICTOR/tiles/$MBTILES.mbtiles
fi
echo "Victor dir:       $DIR_VICTOR"
echo "Downloading from: $PBF_URL"
echo "Saving to:        $PBF"
echo "Writing tiles to: $MBTILES"
echo "Lets go!"

function init {
    if ! which tilemaker > /dev/null; then
        echo "tilemaker executable not found. Install and continue" > /dev/stderr
        exit
    fi
}

function download_world_data {
    echo "--- BEGIN coastline download"
    $DIR_VICTOR/tilemaker/get-coastline.sh
    echo "--- END coastline download"
    echo "--- BEGIN landcover download"
    $DIR_VICTOR/tilemaker/get-landcover.sh
    echo "--- END landcover download"
}

function download_pbf {
    PBF_URL=$1
    echo "--- BEGIN osm download for $AREA"
    # If osm data doesn't exist or is outdated, download it.
    if [ ! -r $PBF ] || [ $(($(date +%s) - $(date -r $PBF +%s))) -gt 604800 ]; then
        curl -Ssf --output $PBF $PBF_URL
    fi

    if [[ ! -f $PBF ]]; then
        echo "Download of OSM data from '$PBF_URL' to destination '$PBF' failed" > /dev/stderr
        exit
    fi
    echo "--- END osm download for $AREA"
}

function make_world {
    if [[ -f $MBTILES_WORLD ]]; then
        return
    fi
    download_world_data
    echo "--- BEGIN generating world-wide coastlines and landcover ..."
    pushd $DIR_VICTOR/tilemaker > /dev/null
    resources=$DIR_VICTOR/tilemaker/resources
    echo tilemaker --input $PBF \
              --output $MBTILES_WORLD \
              --bbox -180,-85,180,85 \
              --store /tmp \
              --config $resources/config-coastline.json \
              --process $resources/process-coastline.lua
    popd > /dev/null
    echo "--- END generating world-wide coastlines and landcover ..."
}

function prepare_mbtiles {
    echo rm -f $MBTILES
    echo cp -vp $MBTILES_WORLD $MBTILES
}

function gen_tiles {
    echo "--- BEGIN generating tiles for $AREA"
    pushd $DIR_VICTOR/tilemaker > /dev/null
    echo tilemaker --input $PBF \
              --output $MBTILES \
              --merge \
              --store /tmp \
              --process $resources/process-openmaptiles.lua \
              --config $resources/config-openmaptiles.json
    popd > /dev/null
    echo "--- END generating tiles for $AREA"
}

function process_pbfs {
    while [[ $# -gt 0 ]]; do
        echo $1
        shift
    done
}

init
make_world
prepare_mbtiles
process_pbfs $*
