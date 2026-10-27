ARG PYTHON_IMAGE=python:3.13.17-slim-trixie
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.13.5
ARG NODE_IMAGE=node:24


FROM ${UV_IMAGE} AS uv

FROM ${PYTHON_IMAGE} AS build-ffmpeg
ENV FFMPEG_VERSION=9.0.2

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    libdav1d-dev \
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
    --enable-libdav1d \
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

FROM ${NODE_IMAGE} AS build-frontend

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
COPY ./frontend/vite-plugin[s]/ /frontend/vite-plugins/
COPY ./frontend/shared /frontend/shared
COPY ./frontend/src /frontend/src

RUN yarn build

#
# Backend dependencies
#

FROM ${PYTHON_IMAGE} AS backend

COPY --from=uv /uv /usr/local/bin/uv

ENV UV_PROJECT_ENVIRONMENT=/venv \
  UV_PYTHON_DOWNLOADS=never \
  UV_COMPILE_BYTECODE=1 \
  UV_LINK_MODE=copy

WORKDIR /build

COPY ./backend/pyproject.toml ./backend/uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --locked --no-dev --no-install-project

#
# Final container
#

FROM ${PYTHON_IMAGE}
ENV PYTHONUNBUFFERED=1
ENV PATH="/venv/bin:$PATH"
ENV PYTHONPATH="/backend"

# Debian packages

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    curl \
    libdav1d7 \
    libgnutls-openssl27t64 \
    postgresql-client-17 \
    procps \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

#
# Pre-built dependencies
#

COPY --from=build-ffmpeg /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=build-ffmpeg /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=backend /venv /venv

#
# Backend files
#

WORKDIR /backend

COPY ./backend/static /backend/static
COPY ./backend/start.sh /backend/start.sh
COPY ./backend/reload.sh /backend/reload.sh
COPY ./backend/cli /backend/cli
COPY ./backend/nxtool[s] /backend/nxtools
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

