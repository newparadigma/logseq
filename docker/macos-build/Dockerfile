# Toolchain for building the Blocklog macOS (ARM64) app on Linux.
# Rebuilt from the layers of the original logseq-macos-builder:local image.
FROM debian:13.7-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends opam ocaml ca-certificates curl git rsync build-essential m4 pkg-config \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node:24-bookworm-slim /usr/local/ /usr/local/

RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-21-jdk-headless python3 libsecret-1-dev file zip \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@10.33.0

RUN mkdir -p /opt/clojure \
 && curl -fsSL https://download.clojure.org/install/clojure-tools-1.12.4.1618.tar.gz | tar -xz --strip-components=1 -C /opt/clojure \
 && mkdir -p /opt/clojure/libexec \
 && mv /opt/clojure/*.jar /opt/clojure/libexec/ \
 && sed -i 's@install_dir=PREFIX@install_dir=/opt/clojure@' /opt/clojure/clojure \
 && ln -s /opt/clojure/clojure /usr/local/bin/clojure

ENV OPAMROOT=/work/opam OPAMYES=1 OPAMROOTISOK=1 JAVA_TOOL_OPTIONS=-Xmx2560m
WORKDIR /work/src
