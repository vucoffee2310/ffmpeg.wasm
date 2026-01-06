#!/bin/bash
set -euo pipefail

# ==========================================
# 0. CHECK ENVIRONMENT
# ==========================================
if ! command -v emcc &> /dev/null; then
    echo "Error: 'emcc' not found."
    echo "Please run: source /path/to/emsdk/emsdk_env.sh"
    exit 1
fi

echo ">>> Setting up Audio-Only Build Environment..."

# Define Installation Directory (Temporary workspace)
mkdir -p build_workspace
export INSTALL_DIR=$(pwd)/build_workspace
export FFMPEG_VERSION=n5.1.4

# Emscripten Flags
export CFLAGS="-I$INSTALL_DIR/include -O3"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$INSTALL_DIR/lib -O3"
export PKG_CONFIG_PATH=$INSTALL_DIR/lib/pkgconfig
export FFMPEG_ST=yes # Single Threaded (Standard for browser compatibility)

# ==========================================
# 1. OVERWRITE CONFIG SCRIPTS (AUDIO ONLY)
# ==========================================
echo ">>> Overwriting build/ffmpeg.sh with Audio-Only config..."
cat << 'EOF' > build/ffmpeg.sh
#!/bin/bash
set -euo pipefail

CONF_FLAGS=(
  --target-os=none
  --arch=x86_32
  --enable-cross-compile
  --disable-asm
  --disable-stripping
  --disable-programs
  --disable-doc
  --disable-debug
  --disable-runtime-cpudetect
  --disable-autodetect
  --disable-everything
  --disable-avdevice
  --disable-swscale
  --disable-postproc
  --disable-network
  --disable-hwaccels
  --enable-static
  --disable-shared
  --enable-gpl
  --enable-version3
  --enable-swresample
  --enable-protocol=file
  --enable-parser=aac
  --enable-parser=ac3
  --enable-parser=mpegaudio
  --enable-parser=opus
  --enable-parser=vorbis
  --enable-parser=flac
  --enable-demuxer=aac
  --enable-demuxer=ac3
  --enable-demuxer=mp3
  --enable-demuxer=wav
  --enable-demuxer=ogg
  --enable-demuxer=flac
  --enable-demuxer=mov
  --enable-demuxer=matroska
  --enable-muxer=mp3
  --enable-muxer=wav
  --enable-muxer=ogg
  --enable-muxer=flac
  --enable-muxer=mp4
  --enable-muxer=matroska
  --enable-decoder=aac
  --enable-decoder=ac3
  --enable-decoder=mp3*
  --enable-decoder=pcm*
  --enable-decoder=flac
  --enable-decoder=vorbis
  --enable-decoder=opus
  --enable-encoder=aac
  --enable-encoder=ac3
  --enable-encoder=libmp3lame
  --enable-encoder=pcm*
  --enable-encoder=flac
  --enable-encoder=libopus
  --enable-encoder=libvorbis
  --enable-filter=aresample
  --enable-filter=volume
  --enable-filter=anull
  --enable-filter=mix
  --nm=emnm
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
  --extra-cflags="$CFLAGS"
  --extra-cxxflags="$CXXFLAGS"
  ${FFMPEG_ST:+ --disable-pthreads --disable-w32threads --disable-os2threads}
)

emconfigure ./configure "${CONF_FLAGS[@]}" $@
emmake make -j
EOF

echo ">>> Overwriting build/ffmpeg-wasm.sh with Audio-Only linker..."
cat << 'EOF' > build/ffmpeg-wasm.sh
#!/bin/bash
set -euo pipefail

EXPORT_NAME="createFFmpegCore"

CONF_FLAGS=(
  -I. 
  -I./src/fftools 
  -I$INSTALL_DIR/include 
  -L$INSTALL_DIR/lib 
  -Llibavcodec 
  -Llibavfilter 
  -Llibavformat 
  -Llibavutil 
  -Llibswresample 
  -lavcodec 
  -lavfilter 
  -lavformat 
  -lavutil 
  -lswresample 
  -Wno-deprecated-declarations 
  $LDFLAGS 
  -sENVIRONMENT=worker
  -sWASM_BIGINT
  -sUSE_SDL=2
  -sSTACK_SIZE=5MB
  -sMODULARIZE
  ${FFMPEG_MT:+ -sINITIAL_MEMORY=1024MB -sPTHREAD_POOL_SIZE=32}
  ${FFMPEG_ST:+ -sINITIAL_MEMORY=32MB -sALLOW_MEMORY_GROWTH}
  -sEXPORT_NAME="$EXPORT_NAME"
  -sEXPORTED_FUNCTIONS=$(node src/bind/ffmpeg/export.js)
  -sEXPORTED_RUNTIME_METHODS=$(node src/bind/ffmpeg/export-runtime.js)
  -lworkerfs.js
  --pre-js src/bind/ffmpeg/bind.js
  src/fftools/cmdutils.c 
  src/fftools/ffmpeg.c 
  src/fftools/ffmpeg_filter.c 
  src/fftools/ffmpeg_hw.c 
  src/fftools/ffmpeg_mux.c 
  src/fftools/ffmpeg_opt.c 
  src/fftools/opt_common.c 
  src/fftools/ffprobe.c 
)

emcc "${CONF_FLAGS[@]}" $@
EOF

chmod +x build/ffmpeg.sh
chmod +x build/ffmpeg-wasm.sh

# ==========================================
# 2. BUILD DEPENDENCIES
# ==========================================
build_lib() {
    local REPO=$1
    local BRANCH=$2
    local DIR=$3
    local SCRIPT=$4
    
    echo ">>> Building $DIR ($BRANCH)..."
    if [ -d "$DIR" ]; then rm -rf "$DIR"; fi
    git clone --depth 1 --branch "$BRANCH" "$REPO" "$DIR"
    cd "$DIR"
    bash "../build/$SCRIPT"
    cd ..
    rm -rf "$DIR"
}

build_lib "https://github.com/ffmpegwasm/zlib.git"   "v1.2.11" "zlib_src"   "zlib.sh"
build_lib "https://github.com/ffmpegwasm/lame.git"   "master"  "lame_src"   "lame.sh"
build_lib "https://github.com/ffmpegwasm/Ogg.git"    "v1.3.4"  "ogg_src"    "ogg.sh"
build_lib "https://github.com/ffmpegwasm/vorbis.git" "v1.3.3"  "vorbis_src" "vorbis.sh"
build_lib "https://github.com/ffmpegwasm/opus.git"   "v1.3.1"  "opus_src"   "opus.sh"

# ==========================================
# 3. BUILD FFMPEG & LINK WASM
# ==========================================
echo ">>> Building FFmpeg Core..."
if [ -d "ffmpeg_src" ]; then rm -rf "ffmpeg_src"; fi
git clone --depth 1 --branch "$FFMPEG_VERSION" https://github.com/FFmpeg/FFmpeg.git ffmpeg_src

# Copy Helper files
cp -r src/bind ffmpeg_src/src/bind
cp -r src/fftools ffmpeg_src/src/fftools

cd ffmpeg_src

# Compile FFmpeg object files
bash ../build/ffmpeg.sh \
      --enable-gpl \
      --enable-libmp3lame \
      --enable-libvorbis \
      --enable-libopus \
      --enable-zlib

# Prepare Output Directories
mkdir -p ../packages/core/dist/umd
mkdir -p ../packages/core/dist/esm

# Define Audio-Only Libraries for Linker
export FFMPEG_LIBS="-lmp3lame -logg -lvorbis -lvorbisenc -lvorbisfile -lopus -lz"

echo ">>> Linking UMD..."
bash ../build/ffmpeg-wasm.sh \
    $FFMPEG_LIBS \
    -o ../packages/core/dist/umd/ffmpeg-core.js

echo ">>> Linking ESM..."
bash ../build/ffmpeg-wasm.sh \
    $FFMPEG_LIBS \
    -sEXPORT_ES6 \
    -o ../packages/core/dist/esm/ffmpeg-core.js

cd ..
rm -rf ffmpeg_src

echo "=========================================="
echo "Build Complete!"
echo "Files located in packages/core/dist/"
echo "=========================================="
