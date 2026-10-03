FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# BOMBKI FPC Win64 cross-compilation image.
# Contains the FPC Linux compiler, MinGW cross-binutils, and the matching
# FPC Win64 RTL, configured by the repository's own cross-setup script.
# Inside the container, `tools/build_fpc.py --target windows --fpc fpc-win64`
# builds BOMBKI for Win64 with no further setup.

RUN apt-get update -qq && \
    apt-get install -y -qq \
      fpc python3 curl \
      binutils-mingw-w64-x86-64 mingw-w64-x86-64-dev && \
    rm -rf /var/lib/apt/lists/*

COPY tools/ /src/tools/
RUN /src/tools/setup_fpc_windows_cross.sh --skip-packages \
      --install-dir /opt/fpc-cross \
      --path-dir /opt/fpc-bin

# Puts the fpc-win64 wrapper and the x86_64-w64-mingw32-* cross-binutils
# symlinks on PATH, so build_fpc.py's default cross prefix resolves.
ENV PATH="/opt/fpc-cross/bin:/opt/fpc-bin:${PATH}"

WORKDIR /src
