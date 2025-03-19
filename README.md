# Vector tile generation and server setup

This is a complete setup with configs and script necessary to have a self-hosted
map tile server. The server tiles are compatible with the
[OpenMapTiles](https://openmaptiles.org/) format.

The intended use of this is to have a self-hosted tile server with only some
regional data of the world. It will create coastlines and landuse of the entire
world, and detailed map data of your desired region.

Make sure you have ~50 - 100 GB of disk space available. The final mbtiles file
will be at least 28 GB, and during generation, 2x or 3x of this is used,
depending on your setup.

## Usage

Install at least Tilemaker (see below) in order to be able to generate the
necessary tiles. To serve tiles you also need Martin and preferably nginx as
front-end. Run the `./bin/gen-tiles.sh` with no arguments to generate a world
wide tile set with regional, detailed data of Norway. Run `./bin/gen-tiles.sh
-h` for more detailed synopsis.

## Tools and configs involved

### Tilemaker

[Tilemaker](https://github.com/systemed/tilemaker) is an excellent tool for
creating mvt vector tiles from raw osm.pbf data. There is no config for this,
but the script `bin/gen-tiles.sh` uses a slew of parameters. The generated tiles
are dumped in the `./tiles` folder as single MBTiles.

In Ubuntu 24.04, the version of Tilemaker available is a bit outdated, as the
3.0 version is a lot faster, so it's recommended to compile this yourself.

### Martin

[Martin](https://maplibre.org/martin/introduction.html) is a web server for
providing tiles, sprites and glyphs (fonts) needed for vector maps. It doesn't
cache the generated tiles, and in any case it's recommended to have these kind
of special-purpose servers behind a more robust http server. A simple config for
Nginx is provided. Be aware that the CORS header allows running this from
anywhere.

Install using e.g. `cargo binstall martin --root=/usr/local`, assuming you have
Rust's `cargo` and `cargo-binstall` installed.

A Systemd service file is provided to make martin a first-class service citizen
in your system. Copy this to `/etc/systemd/system/`, customize it, then enable
it with `systemctl enable martin` and finally run it with `service martin
start`.

### Nginx

Nginx is used as front-end web-server with a simple proxy cache setup. The
generation of tiles from mbtiles isn't costly at all, so this cache can easily
be dropped. Point your root folder to `./public/` in your nginx's vhost config.

Assuming your victor host is `victor.example.com` The most important URLs with
this setup are:

- https://victor.example.com/styles/{STYLE}/style.json where `{STYLE}` is one of the
  provided styles, e.g. `osm-bright`: The only URL needed to provide to e.g.
  MapLibre.
- https://victor.example.com/tiles/{MBTILES} where `{MBTILES}` is the base name of
  your mbtiles, e.g. `norway-latest`: Vector map json source.
- https://victor.example.com/tiles/MBTILES/{z}/{x}/{y} : Where individual vector
  tiles are downloaded from.
- https://victor.example.com/tiles/sprites/{SPRITE} : Basename of sprite used in
  style. The actual URLs will have an additional `.json` or `.png` added. These
  sprites are generated by Martin.
- https://victor.example.com/tiles/font/{FONT}/{RANGE} : Font glyphs used in
  style, generated by Martin on the fly.

### Scripts

- The `./bin/gen-tiles.sh` is the work-horse in this repo. It downloads and
  caches the required data for tile generation and has a lot of options to
  customize this setup. See `./bin/gen-tiles.sh -h` for synopsis.
- A companion cron script is provided in `./etc/cron.daily/update-tiles` which
  will run `gen-tiles.sh` with your desired config. Copy this to
  `/etc/cron.daily/`.

### Styles

The styles are available directly from nginx, if `./public/` is set to your
vhosts root. They have hardcoded values to tile server data, which must be
changed (branched out) for your installation.

### Configs

The `./etc` folder has all necessary configs used in this stack, and may be used
directly on top of your system's `/etc` folder, if using \*NIX-alike OSes.

## Running on Mac OS

1. Install Martin using HomeBrew by running `brew tap maplibre/martin` and `brew install martin`.
2. Install cUrl using HomeBrew by running `brew install curl-openssl`
3. Install dependencies for `tilemaker` using `brew installx boost lua51 shapelib rapidjson`
4. Clone the [tilemaker](https://github.com/systemed/tilemaker) repository, `cd` into it and run `make`
5. Install it by running `sudo make install`

_Now we can generate tiles using_ `./bin/gen-tiles.sh`

6. Serve the generated tiles by running `martin ./tiles`
> We need to enable CORS such that the Martin server can access our styles
7. Serve styles from the `./public` folder with your http-server of choice, e.g. `npx http-server --cors ./public` 
