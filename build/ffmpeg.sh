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

  # --- AUDIO ONLY CONFIGURATION START ---
  
  # 1. Disable everything to start with a clean slate (reduces size massively)
  --disable-everything

  # 2. Disable video/image/device specific libraries
  --disable-avdevice
  --disable-swscale
  --disable-postproc
  --disable-network
  --disable-hwaccels
  
  # 3. Build setup for WebAssembly
  --enable-static
  --disable-shared
  --enable-gpl
  --enable-version3

  # 4. Essential Audio Libraries
  --enable-swresample   # Required for sample rate conversion

  # 5. Protocols
  --enable-protocol=file

  # 6. Parsers (Audio)
  --enable-parser=aac
  --enable-parser=ac3
  --enable-parser=mpegaudio
  --enable-parser=opus
  --enable-parser=vorbis
  --enable-parser=flac

  # 7. Demuxers (Input formats)
  --enable-demuxer=aac
  --enable-demuxer=ac3
  --enable-demuxer=mp3
  --enable-demuxer=wav
  --enable-demuxer=ogg
  --enable-demuxer=flac
  --enable-demuxer=mov      # Required for m4a/mp4 audio inputs
  --enable-demuxer=matroska # Required for mka/webm audio inputs

  # 8. Muxers (Output formats)
  --enable-muxer=mp3
  --enable-muxer=wav
  --enable-muxer=ogg
  --enable-muxer=flac
  --enable-muxer=mp4        # Required for m4a output
  --enable-muxer=matroska   # Required for webm/mka output
  
  # 9. Decoders (Input Codecs)
  --enable-decoder=aac
  --enable-decoder=ac3
  --enable-decoder=mp3*
  --enable-decoder=pcm*
  --enable-decoder=flac
  --enable-decoder=vorbis
  --enable-decoder=opus

  # 10. Encoders (Output Codecs)
  --enable-encoder=aac
  --enable-encoder=ac3
  --enable-encoder=libmp3lame
  --enable-encoder=pcm*
  --enable-encoder=flac
  --enable-encoder=libopus
  --enable-encoder=libvorbis

  # 11. Filters (Audio processing)
  --enable-filter=aresample
  --enable-filter=volume
  --enable-filter=anull
  --enable-filter=mix
  
  # --- AUDIO ONLY CONFIGURATION END ---

  # Toolchain configuration
  --nm=emnm
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
  --extra-cflags="$CFLAGS"
  --extra-cxxflags="$CXXFLAGS"

  # Disable thread when FFMPEG_ST is NOT defined
  ${FFMPEG_ST:+ --disable-pthreads --disable-w32threads --disable-os2threads}
)

emconfigure ./configure "${CONF_FLAGS[@]}" $@
emmake make -j
