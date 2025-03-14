#!/bin/bash

set -e
set -u

# Don't update unless destination mbtiles is younger than this many seconds.
MIN_AGE=604800

# Default map source unless given as parameter.
PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf

DIR_VICTOR=$(dirname $(dirname $(realpath $0)))
RESOURCES=$DIR_VICTOR/tilemaker/resources
PBF_URLS=$PBF_URL
MBTILES_WORLD=$DIR_VICTOR/tiles/world_coastlines.mbtiles
SCRIPT_START=$(date +%s)

function usage {
    echo "$(basename $0) [OPTIONS] [PBF_URL ...]

This is a simple frontend to tilemaker for generating openmaptiles compatible
mbtiles files based on regional data. It will create a mbtiles tile set in the
/tiles folder of this repo.

PBF_URL is a url containing a osm.pbf dump, usually from geofabrik.de.  Defaults
is $PBF_URL.  Use of multiple URLs will merge all data into the tile set
specified with the -m option, which then is required.

If the target mbtiles exist and is to be re-created, the tile generation will
work on a shadow mbtiles file until complete and *then* replaced.

OPTIONS
    -a                  Append PBFs from parameters to existing mbtiles. Useful
                        when a previous step failed or you want to add
                        additional data to a tile set. NOTE! This will not
                        operate on a shadow mbtiles file, but write to the
                        target mbtiles file directly.

    -c                  Remove PBF files after generation. Repeat to remove
                        world coastline mbtiles too.

    -f                  Force generation of mbtiles. Repeat to force download
                        of source PBFs too.

    -h                  This help.

    -m MBTILES          Basename of destination mbtiles file. It will end up in
                        tiles/<MBTILE>.mbtiles. Required when using multiple
                        URLs.
"
}

APPEND=0
CLEAN=0
FORCE=0
MBTILES=""

while getopts "acfhm:" option; do
    case $option in
        a) APPEND=1 ;;
        c) CLEAN=$((CLEAN + 1)) ;;
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

if [[ $# -gt 1 ]] && [[ $MBTILES = "" ]]; then
    echo "-m option is required with multiple PBF sources" >> /dev/stderr
    exit 1
fi

if [[ $# -gt 0 ]]; then
    PBF_URL=$1
    PBF_URLS=$*
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)

if [[ $MBTILES = "" ]]; then
    MBTILES=$DIR_VICTOR/tiles/$AREA.mbtiles
else
    MBTILES=$DIR_VICTOR/tiles/$MBTILES.mbtiles
fi

# While creating tiles, write to this to omit overriding existing tile.
if [[ -f $MBTILES ]] && [[ $APPEND = 0 ]]; then
    MBTILES_SHADOW=$(dirname $MBTILES)/__$(basename $MBTILES)
else
    MBTILES_SHADOW=$MBTILES
fi

echo "Victor dir:       $DIR_VICTOR"
echo "First PBF URL:    $PBF_URL"
echo "Writing tiles to: $MBTILES"
echo

function init {
    if ! which tilemaker > /dev/null; then
        echo "tilemaker executable not found. Install and continue" > /dev/stderr
        exit 1
    fi

    if [[ $APPEND = 0 ]] &&
       [[ $FORCE -lt 1 ]] &&
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
        echo "--- BEGIN osm download of $AREA"
        rm -f $PBF_DEST
        curl -Ssf --output $PBF_DEST $PBF_URL
        echo "--- END osm download of $AREA"
    else
        echo "Not downloading PBF of $AREA: File exists and is recent."
    fi

    if [[ ! -f $PBF_DEST ]]; then
        echo "Download of OSM data from '$PBF_URL' to destination '$PBF_DEST' failed" > /dev/stderr
        exit 1
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
    rm -f $MBTILES_SHADOW
    cp -vp $MBTILES_WORLD $MBTILES_SHADOW
}

function gen_tiles {
    local PBF=$1
    local PBF_FILE=$(basename $PBF)
    echo "--- BEGIN generating tiles from $PBF_FILE"
    pushd $DIR_VICTOR/tilemaker > /dev/null
    tilemaker --input $PBF \
              --output $MBTILES_SHADOW \
              --merge \
              --store /tmp \
              --process $RESOURCES/process-openmaptiles.lua \
              --config $RESOURCES/config-openmaptiles.json
    popd > /dev/null
    echo "--- END generating tiles for $PBF_FILE"
}

function process_pbfs {
    while [[ $# -gt 0 ]]; do
        URL=$1
        download_pbf $URL
        gen_tiles $PBF_DEST
        if [[ $CLEAN -gt 0 ]]; then
            echo rm -f $PBF_DEST
        fi
        shift
    done
}

function finalize {
    if [[ $CLEAN -gt 1 ]]; then
        rm -f $MBTILES_WORLD
    fi

    # Move working tile set to final destination
    if [[ $MBTILES != $MBTILES_SHADOW ]]; then
        mv -f $MBTILES_SHADOW $MBTILES
    fi
    local SCRIPT_END=$(($(date +%s) - $SCRIPT_START))
    local MBTILES_SIZE=$(stat -c %s $MBTILES)
    echo
    echo "------------------------------------------------------------------------------"
    echo "Summary:"
    echo
    echo "Finished writing tiles to $MBTILES"
    echo "Spent $(($SCRIPT_END / 60)):$(($SCRIPT_END % 60)) minutes"
    echo "Target MBTILES file is $(($MBTILES_SIZE % 1048576)) MB"
}

init
if [[ $APPEND = 0 ]] || [[ ! -f $MBTILES ]]; then
    make_world $PBF_URL
    prepare_mbtiles
else
    echo "Appending PBFs to existing mbtiles"
    echo
fi
process_pbfs $PBF_URLS
finalize
