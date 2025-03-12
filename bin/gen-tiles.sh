#!/bin/bash

DIR_VICTOR=$(realpath $(dirname $(dirname $0)))

PBF_URL=https://download.geofabrik.de/europe/norway-latest.osm.pbf

if [[ ${PBF_URL: -8} != '.osm.pbf' ]]; then
    echo "Wrong file extension in downloaded chunk. Expected '.osm.pbf'" > /dev/stderr
    exit
fi

AREA=$(basename ${PBF_URL##*/} .osm.pbf)

cd $DIR_VICTOR/tilemaker
echo -n "Downloading coastlines ... "
./get-coastline.sh
echo "OK"
echo -n "Downloading landcover ... "
./get-landcover.sh
echo "OK"

mkdir -p $DIR_VICTOR/tilemaker/osm
PBF=$DIR_VICTOR/tilemaker/osm/$AREA.osm.pbf

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

