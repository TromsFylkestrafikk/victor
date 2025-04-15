DIR_VICTOR=$(dirname $(dirname $(realpath $0)))

cd $DIR_VICTOR/tilemaker

# tilemaker --bbox 15.35593,68.32156,23.32592,70.89372 \
#           --input ./osm/norway-latest.osm.pbf \
#           --store ../tmp \
#           --output ../tiles/tromso.mbtiles \
#           --config ./resources/config-coastline.json \
#           --process ./resources/process-coastline.lua

cp ../tiles/_tromso.mbtiles ../tiles/tromso.mbtiles
tilemaker --merge \
          --bbox 15.35593,68.32156,23.32592,70.89372 \
          --input ./osm/norway-latest.osm.pbf \
          --store ../tmp \
          --output ../tiles/tromso.mbtiles \
          --config ./resources/config-openmaptiles.json \
          --process ./resources/process-openmaptiles.lua
