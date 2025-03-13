#!/bin/bash

# Don't update unless destination mbtiles is younger than this many seconds.
let MIN_AGE=604800

# Default map source unless given as parameter.
PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf

DIR_VICTOR=$(dirname $(dirname $(realpath $0)))
RESOURCES=$DIR_VICTOR/tilemaker/resources
PBF_URLS=$PBF_URL
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
    -f                  Force generation of mbtiles. Repeat to force download
                        of source PBFs.
    -m TILE_FILE        Basename of destination mbtiles file. It will end up in
                        tiles/<MBTILE>.mbtiles.
"
}

MBTILES=""
let FORCE=0

while getopts "fhm:" option; do
    case $option in
        f) FORCE=$((FORCE + 1)) ;;
        h) usage
           exit
           ;;
        m) MBTILES=$OPTARG ;;
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
    PBF_URLS=$*
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)

if [[ $MBTILES = "" ]]; then
    MBTILES=$DIR_VICTOR/tiles/$AREA.mbtiles
else
    MBTILES=$DIR_VICTOR/tiles/$MBTILES.mbtiles
fi

echo "Victor dir:       $DIR_VICTOR"
echo "First PBF URL:    $PBF_URL"
echo "Writing tiles to: $MBTILES"
echo

function init {
    if ! which tilemaker > /dev/null; then
        echo "tilemaker executable not found. Install and continue" > /dev/stderr
        exit
    fi

    if [[ $FORCE -lt 1 ]] &&
       [[ -f $MBTILES ]] &&
       [[ $(($(date +%s) - $(date -r $MBTILES +%s))) -lt $MIN_AGE ]]
    then
        echo "Destination mbtiles is of recent age. Leaving."
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

## Destination of downloaded PBF
PBF_DEST=""

function download_pbf {
    local PBF_URL=$1
    PBF_DEST=$DIR_VICTOR/tilemaker/osm/${PBF_URL##*/}
    local AREA=$(basename $PBF_DEST .osm.pbf)

    # If osm data doesn't exist or is outdated, download it.
    if [[ $FORCE -gt 1 ]] ||
       [[ ! -r $PBF_DEST ]] ||
       [[ $(($(date +%s) - $(date -r $PBF_DEST +%s))) -gt $MIN_AGE ]]
    then
        echo "--- BEGIN osm download for $AREA"
        rm -f $PBF_DEST
        curl -Ssf --output $PBF_DEST $PBF_URL
        echo "--- END osm download for $AREA"
    else
        echo "Not downloading PBF of $AREA: File exists and is recent."
    fi

    if [[ ! -f $PBF_DEST ]]; then
        echo "Download of OSM data from '$PBF_URL' to destination '$PBF_DEST' failed" > /dev/stderr
        exit
    fi
}

function make_world {
    if [[ -f $MBTILES_WORLD ]]; then
        return
    fi
    download_world_data
    download_pbf $1
    echo "--- BEGIN generating world-wide coastlines and landcover"
    echo "Generating world mbtiles to $MBTILES_WORLD"
    pushd $DIR_VICTOR/tilemaker > /dev/null
    tilemaker --input $PBF_DEST \
              --output $MBTILES_WORLD \
              --bbox -180,-85,180,85 \
              --store /tmp \
              --config $RESOURCES/config-coastline.json \
              --process $RESOURCES/process-coastline.lua
    popd > /dev/null
    echo "--- END generating world-wide coastlines and landcover"
}

function prepare_mbtiles {
    rm -f $MBTILES
    cp -vp $MBTILES_WORLD $MBTILES
}

function gen_tiles {
    local PBF=$1
    local PBF_FILE=$(basename $PBF)
    echo "--- BEGIN generating tiles from $PBF_FILE"
    pushd $DIR_VICTOR/tilemaker > /dev/null
    tilemaker --input $PBF \
              --output $MBTILES \
              --merge \
              --store /tmp \
              --process $RESOURCES/process-openmaptiles.lua \
              --config $RESOURCES/config-openmaptiles.json
    popd > /dev/null
    echo "--- END generating tiles for $PBF_FILE"
}

function process_pbfs {
    while [[ $# -gt 0 ]]; do
        download_pbf $1
        gen_tiles $PBF_DEST
        shift
    done
}

init
make_world $PBF_URL
prepare_mbtiles
process_pbfs $PBF_URLS
