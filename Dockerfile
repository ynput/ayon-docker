FROM node:latest AS build

RUN mkdir /frontend

COPY ./frontend/index.html /frontend/index.html
COPY ./frontend/package.json /frontend/package.json
COPY ./frontend/vite.config.js /frontend/vite.config.js
COPY ./frontend/src /frontend/src
COPY ./frontend/public /frontend/public

WORKDIR /frontend
RUN yarn install && yarn build


FROM python:3.10

ENV PYTHONBUFFERED=1

RUN pip install -U pip
RUN pip install poetry
RUN mkdir /backend

COPY ./backend/api /backend/api
COPY ./backend/demogen /backend/demogen
COPY ./backend/openpype /backend/openpype
COPY ./backend/schemas /backend/schemas
COPY ./backend/setup /backend/setup
COPY ./backend/static /backend/static
COPY ./backend/pyproject.toml /backend/pyproject.toml
COPY ./backend/start.sh /backend/start.sh

COPY --from=build /frontend/dist/ /frontend

WORKDIR /backend

RUN poetry config virtualenvs.create false \
&& poetry install --no-interaction --no-ansi

# COPY [ \
#   "./backend/api", \
#   "./backend/demogen", \
#   "./backend/openpype", \
#   "./backend/schemas", \
#   "./backend/setup", \
#   "./backend/static", \
#   "./backend/pyproject.toml", \
#   "./backend/start.sh", \
#   "/backend/" \
# ]

ENTRYPOINT ./start.sh
