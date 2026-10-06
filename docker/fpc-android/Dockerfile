# The base image is pinned by digest, not by tag: a tag can be
# re-pushed with different content, which would silently change
# every build done "on the same base". To move to a newer Ubuntu
# 24.04 image, update the digest and the helper images rebuild
# (their cache key covers this file).
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

ENV DEBIAN_FRONTEND=noninteractive

# BOMBKI FPC Android arm64 cross-toolchain image.
# Contains the FPC Linux compiler with the aarch64 code generator, the official
# FPC aarch64-android RTL units, and the Android NDK binutils/sysroot wired up
# by the repository's own setup script. Inside the container,
# `tools/build_fpc.py --target android --fpc fpc-android` builds BOMBKI for
# Android arm64 with no further setup.

RUN apt-get update -qq && \
    apt-get install -y -qq \
      fpc python3 curl ca-certificates unzip make \
      binutils-aarch64-linux-gnu && \
    rm -rf /var/lib/apt/lists/*

COPY tools/ /src/tools/
RUN /src/tools/setup_fpc_android_cross.sh --skip-packages \
      --install-dir /opt/fpc-android \
      --path-dir /opt/fpc-bin \
      --ndk-root /opt/android-ndk

# Puts the fpc-android wrapper on PATH, so build_fpc.py's --fpc fpc-android
# resolves by name.
ENV PATH="/opt/fpc-bin:${PATH}"

WORKDIR /src