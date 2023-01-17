AYON Server
===========

Ayon Server is a powerful tool for managing and automating the visual effects workflow for film and television productions.

Features
--------

 - Support for multiple projects and teams
 - Customizable task management and scheduling
 - File management and version control
 - Integration with industry-standard VFX software
 - Collaboration and communication tools
 - Real-time monitoring and reporting

Requirements
------------

Docker with **compose* plugin

or:

  - Python 3.10+ and Poetry
  - Node 18+ and yarn
  - PostgreSQL server 14
  - Redis server
 
Installation
------------

## Production

 - Clone this repo
 - Tweak `docker-compose.yml`
 - Comment out ` -"./backend:/backend` line in the backend/volumes section
 - Install addons to the `addons` directory
 - Create modify default settings in `settings` directory
 - Run `docker compose up -d` (Unix) or `docker-compose up -d` (Windows)
 - Run `make setup` (Unix) or `manage.ps1` (Windows)
 - http://localhost:5000/ and log in as admin/admin

## Development setup

 - Clone this repo
 - Run `make` to download required repositories and build the Docker image
 - Tweak `docker-compose.yml`
 - Install addons to the `addons` directory
 - Run `docker compose up`

## Demo Project

You can setup a demo which will create 3 project; `demo_Commercial`, `demo_Big_Episodic` and `demo_Big_Feature`.

- `make demo` (Unix) or `manage.ps1` (Windows)

**NOTE: These demo projects can take a while to create.**
