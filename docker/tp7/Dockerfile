# The base image is pinned by digest, not by tag: a tag can be
# re-pushed with different content, which would silently change
# every build done "on the same base". To move to a newer Ubuntu
# 24.04 image, update the digest and the helper images rebuild
# (their cache key covers this file).
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

ENV DEBIAN_FRONTEND=noninteractive

# BOMBKI DOSBox-X + Turbo Pascal 7.01 image.
# Contains DOSBox-X with the genuine Borland TPC.EXE and TURBO.TPL of
# TP7.01 - the compiler whose LONG.OBJ semantics the original game was
# built with. Inside the container, `tools/build_tp7_dosbox.py` compiles
# _reconstructed/*.PAS with no further setup; that is what the
# tp7-conformance workflow compares against _reference/. No X server is
# installed: the build script runs DOSBox-X through SDL's dummy video and
# audio drivers, which is what TPC.EXE needs to compile and nothing more.

RUN apt-get update -qq && \
    apt-get install -y -qq \
      dosbox-x python3 unzip && \
    rm -rf /var/lib/apt/lists/*

# The payload is vendored next to the Dockerfile: the conformance check is
# only meaningful with the exact TP7.01 files the original was built with,
# and a download would make the verdict depend on a mirror still being
# there. Both hashes are the ones tools/extract_tp701.sh verifies, so the
# local install path and this image are provably the same compiler.
# COPY paths are relative to the build context root (the repository, see the
# workflow), not to this Dockerfile's directory.
COPY docker/tp7/tools/TPC701.ZIP /tmp/TPC701.ZIP
COPY docker/tp7/tools/RTPL701.ZIP /tmp/RTPL701.ZIP
RUN set -eu && \
    mkdir -p /tools/tp7/BIN && \
    unzip -p /tmp/TPC701.ZIP TPC.EXE > /tools/tp7/BIN/TPC.EXE && \
    unzip -p /tmp/RTPL701.ZIP TURBO.TPL > /tools/tp7/BIN/TURBO.TPL && \
    echo "72211facc2159c758fd6db2a6076517568d82654f1a6b92539745af50274e3f0  /tools/tp7/BIN/TPC.EXE" | sha256sum -c - && \
    echo "025cf348b34b737f7db84e98b77041d25c7d62e6210e2c410e660f5149c05896  /tools/tp7/BIN/TURBO.TPL" | sha256sum -c - && \
    rm -f /tmp/TPC701.ZIP /tmp/RTPL701.ZIP

WORKDIR /src