$FunctionName=$ARGS[0]
$arguments=@()
if ($ARGS.Length -gt 1) {
    $arguments = $ARGS[1..($ARGS.Length - 1)]
}

# Settings
$SCRIPT_DIR = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location "$($SCRIPT_DIR)"
$SETTINGS_FILE = "settings/template.json"
$IMAGE_NAME = "ynput/ayon"
$DEFAULT_IMAGE = "$($IMAGE_NAME):latest"
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
  Write-Host "Usage: ./manage.ps1 [target]"
  Write-Host ""
  Write-Host "Runtime targets:"
  Write-Host "  setup     Apply settings template from the settings/template.json"
  Write-Host "  dbshell   Open a PostgreSQL shell"
  Write-Host "  reload    Reload the running server"
  Write-Host "  demo      Create demo projects based on settings in demo directory"
  Write-Host ""
  Write-Host "Development:"
  Write-Host "  backend            Download / update backend"
  Write-Host "  frontend           Download / update frontend"
  Write-Host "  build              Build docker image"
  Write-Host "  relinfo            Create RELEASE file with version info (debugging)"
  Write-Host "  dist               Publish docker image to docker hub"
  Write-Host "  dump [PROJECT]     Dump project database into file"
  Write-Host "  restore [PROJECT]  Restore project database from file"
  Write-Host ""
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
  docker pull $DEFAULT_IMAGE
  & "$($COMPOSE)" up --detach --build "$($SERVER_CONTAINER)"
}

function relinfo {
  $backend_dir = "$($SCRIPT_DIR)\backend"
  $frontend_dir = "$($SCRIPT_DIR)\frontend"
  $output_file = "$($SCRIPT_DIR)\RELEASE"

  $cur_date = Get-Date

  $backend_version = Invoke-Expression -Command "python -c ""import os;import sys;content={};f=open(r'$($backend_dir)\ayon_server\version.py');exec(f.read(),content);f.close();print(content['__version__'])"""
  $build_date = Get-Date -Date $cur_date -Format "yyyyMMdd"
  $build_time = Get-Date -Date $cur_date -Format "HHmm"
  $cur_cwd = Get-Location

  Set-Location $backend_dir
  $backend_branch = Invoke-Expression -Command "git branch --show-current"
  $backend_commit = Invoke-Expression -Command "git rev-parse --short HEAD"
  Set-Location $frontend_dir
  $frontend_branch = Invoke-Expression -Command "git branch --show-current"
  $frontend_commit = Invoke-Expression -Command "git rev-parse --short HEAD"
  Set-Location $cur_cwd
  $output_content = @"
version=$($backend_version)
build_date=$($build_date)
build_time=$($build_time)
frontend_branch=$($backend_branch)
backend_branch=$($frontend_branch)
frontend_commit=$($backend_commit)
backend_commit=$($frontend_commit)
"@

  $output_content | Out-File -FilePath $output_file -Encoding utf8
}

# The following targets are for development purposes only.

function build {
  backend
  frontend
  relinfo
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
    & git clone https://github.com/ynput/ayon-backend "$($SCRIPT_DIR)/backend"
  }
}

function frontend {
  & git -C "$($SCRIPT_DIR)/frontend" pull
  if ($lastexitCode) {
    & git clone https://github.com/ynput/ayon-frontend "$($SCRIPT_DIR)/frontend"
  }
}

function dump {
  $projectname = $args[0]
  if ($projectname -eq $null) {
    Write-Error "Error: Project name is required. Usage: ./manage.ps1 dump [PROJECT]"
    exit 1
  }

  Write-Host "Dumping project '$projectname'"
  $dumpFile = "dump.$projectname.sql"
  "DROP SCHEMA IF EXISTS project_$projectname CASCADE;" | Out-File -FilePath $dumpFile -Encoding utf8
  "DELETE FROM public.projects WHERE name = '$projectname';" | Out-File -FilePath $dumpFile -Append -Encoding utf8

  # Project data dump (table public.projects)
  docker compose exec -t postgres pg_dump --table=public.projects --column-inserts ayon -U ayon |
      Select-String -Pattern "^INSERT INTO" |
      Select-String -Pattern "'$projectname'" |
      ForEach-Object { $_.Line } | Out-File -FilePath $dumpFile -Append -Encoding utf8

  # Get all product types on a project
  $types = docker compose exec postgres psql -U ayon ayon -Atc "SELECT DISTINCT(product_type) from project_$projectname.products;"
  foreach ($product_type in $types) {
      "INSERT INTO public.product_types (name) VALUES ('$product_type') ON CONFLICT DO NOTHING;" | Out-File -FilePath $dumpFile -Append -Encoding utf8
  }

  # Project schema dump
  docker compose exec postgres pg_dump --schema=project_$projectname ayon -U ayon | Out-File -FilePath $dumpFile -Append -Encoding utf8
}

function restore {
  $projectname = $arguments[0]
  if ($projectname -eq $null) {
    Write-Error "Error: Project name is required. Usage: ./manage.ps1 restore [PROJECT]"
    exit 1
  }

  $dumpfile = "dump.$projectname.sql"

  # Check if the dump file exists.
  if (-not (Test-Path $dumpfile)) {
    Write-Error "Error: Dump file $SCRIPT_DIR\$dumpfile not found"
    exit 1
  }

  # Restore the database from the dump file.
  Get-Content $dumpfile | docker-compose exec -T postgres psql -U ayon ayon
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
  } elseif ($FunctionName -eq "relinfo") {
    relinfo
  } elseif ($FunctionName -eq "dist") {
    dist
  } elseif ($FunctionName -eq "backend") {
    backend
  } elseif ($FunctionName -eq "frontend") {
    frontend
  } elseif ($FunctionName -eq "dump") {
    dump @arguments
  } elseif ($FunctionName -eq "restore") {
    restore @arguments
  } elseif ($null -eq $FunctionName) {
    defaultfunc
  } else {
    Write-Host "Unknown function ""$FunctionName"""
    defaultfunc
  }
}

main
