FROM python:3.11-slim-bookworm AS build-ffmpeg
ENV FFMPEG_VERSION=7.1

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    libgnutls-openssl-dev \
    cmake \
    git \
    libtool \
    pkg-config \
    texinfo \
    wget \
    yasm \
    nasm \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN \
  wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz \
  && tar -xzf ffmpeg-${FFMPEG_VERSION}.tar.gz \
  && rm ffmpeg-${FFMPEG_VERSION}.tar.gz \
  && mv ffmpeg-${FFMPEG_VERSION} ffmpeg

WORKDIR /src/ffmpeg
RUN ./configure \
    --prefix=/usr/local \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    --enable-static \
    --disable-shared \
    --enable-gpl \
    --enable-gnutls \
    --enable-runtime-cpudetect \
    --extra-version=AYON && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/ffmpeg

#
# Build frontend
#

FROM node:22 AS build-frontend

WORKDIR /frontend

COPY \
  ./frontend/index.html \
  ./frontend/tsconfig.node.json \
  ./frontend/tsconfig.json \
  ./frontend/vite.config.ts \
  .
COPY ./frontend/package.json ./frontend/yarn.lock .

RUN yarn install

COPY ./frontend/public /frontend/public
COPY ./frontend/share[d] /frontend/shared
COPY ./frontend/src /frontend/src

RUN yarn build

#
# Main container
#

FROM python:3.11-slim-bookworm
ENV PYTHONUNBUFFERED=1

# Debian packages

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    curl \
    libgnutls-openssl27 \
    postgresql-client \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build-ffmpeg /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=build-ffmpeg /usr/local/bin/ffprobe /usr/local/bin/ffprobe

WORKDIR /backend

COPY ./backend/pyproject.toml ./backend/uv.lock .
RUN --mount=from=ghcr.io/astral-sh/uv,source=/uv,target=/bin/uv \
    uv pip install -r pyproject.toml --system

COPY ./backend/static /backend/static
COPY ./backend/start.sh /backend/start.sh
COPY ./backend/reload.sh /backend/reload.sh
COPY ./backend/nxtool[s] /backend/nxtools
COPY ./backend/cl[i] /backend/cli
COPY ./backend/demogen /backend/demogen
COPY ./backend/linker /backend/linker
COPY ./backend/setup /backend/setup
COPY ./backend/aycli /usr/bin/ay
COPY ./backend/dbshell /usr/bin/dbshell
COPY ./backend/maintenance /backend/maintenance
COPY ./backend/schemas /backend/schemas
COPY ./backend/ayon_server /backend/ayon_server
COPY ./backend/api /backend/api
COPY ./RELEAS[E] /backend/RELEASE

COPY --from=build-frontend /frontend/dist/ /frontend

RUN sh -c 'date +%y%m%d%H%M > /backend/BUILD_DATE'

CMD ["/bin/bash", "/backend/start.sh"]

