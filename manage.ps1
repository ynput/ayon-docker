# Receive first positional argument
Param([Parameter(Position=0)]$FunctionName)

# Settings
$SCRIPT_DIR = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location "$($SCRIPT_DIR)"
$SETTINGS_FILE = "settings/template.json"
$IMAGE_NAME = "ynput/ayon:dev"
$SERVER_CONTAINER = "server"

# Variables

# TODO: tag needs to be set to the current version. TBD.
$TAG = (git describe --tags --always --dirty)

# Abstract the 'docker compose' / 'docker-compose' command
$COMPOSE = "docker-compose"

# By default, just show the usage message
function defaultfunc {
  Write-Host ""
  Write-Host "Ayon server $($TAG)"
  Write-Host ""
  Write-Host "Usage: make [target]"
  Write-Host ""
  Write-Host "Runtime targets:"
  Write-Host "  setup     Apply settings temlpate form the settings/template.json"
  Write-Host "  dbshell   Open a PostgreSQL shell"
  Write-Host "  reload    Reload the running server"
  Write-Host "  demo      Create demo projects based on settings in demo directory"
  Write-Host ""
  Write-Host "Development:"
  Write-Host "  backend   Download / update backend"
  Write-Host "  frontend  Download / update frontend"
  Write-Host "  build     Build docker image"
  Write-Host "  dist      Publish docker image to docker hub"
}

# Makefile syntax, oh so bad
# Errors abound, frustration high
# Gotta love makefiles

function setup {
    Write-Host "Server container: $($SERVER_CONTAINER)"
  if (!(Test-Path "$($SCRIPT_DIR)/settings/template.json")) {
    & "$($COMPOSE)" exec -T "$($SERVER_CONTAINER)" python -m setup
  } else {
    Get-Content "$($SCRIPT_DIR)/settings/template.json" | & "$($COMPOSE)" exec -T "$($SERVER_CONTAINER)" python -m setup -
  }
  & "$($COMPOSE)" exec "$($SERVER_CONTAINER)" bash "/backend/reload.sh"
}

function dbshell {
  & "$($COMPOSE)" exec postgres psql -U ayon ayon
}

function reload {
  & "$($COMPOSE)" exec "$($SERVER_CONTAINER)" bash "/backend/reload.sh"
}

function demo {
  foreach ($file in (Get-ChildItem "demo/*.json")) {
    Get-Content "$($file.FullName)" | & "$($COMPOSE)" exec -T "$($SERVER_CONTAINER)" python -m demogen
  }
}

function update {
  docker pull $IMAGE_NAME
  & "$($COMPOSE)" up --detach --build "$($SERVER_CONTAINER)"
}

# The following targets are for development purposes only.

function build {
  backend
  frontend
  # Build the docker image
  docker build -t "$($IMAGE_NAME):$($TAG)" -t "$($IMAGE_NAME):latest" .
}

function dist {
  build
  # Publish the docker image to the registry
  docker push "$($IMAGE_NAME):$($TAG)"
  docker push "$($IMAGE_NAME):latest"
}

function backend {
  & git -C "$($SCRIPT_DIR)/backend" pull
  if ($lastexitCode) {
    & git clone https://github.com/pypeclub/ayon-backend "$($SCRIPT_DIR)/backend"
  }
}

function frontend {
  & git -C "$($SCRIPT_DIR)/frontend" pull
  if ($lastexitCode) {
    & git clone https://github.com/pypeclub/ayon-frontend "$($SCRIPT_DIR)/frontend"
  }
}

function main {
  if ($FunctionName -eq "setup") {
    setup
  } elseif ($FunctionName -eq "dbshell") {
    dbshell
  } elseif ($FunctionName -eq "reload") {
    reload
  } elseif ($FunctionName -eq "demo") {
    demo
  } elseif ($FunctionName -eq "update") {
    update
  } elseif ($FunctionName -eq "build") {
    build
  } elseif ($FunctionName -eq "dist") {
    dist
  } elseif ($FunctionName -eq "backend") {
    backend
  } elseif ($FunctionName -eq "frontend") {
    frontend
  } elseif ($FunctionName -eq $null) {
    defaultfunc
  } else {
    Write-Host "Unknown function ""$FunctionName"""
    defaultfunc
  }
}

main
