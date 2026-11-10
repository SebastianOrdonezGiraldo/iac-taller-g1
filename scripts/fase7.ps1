$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
function Log($t) { Write-Host $t; Add-Content -Path $global:LOG -Value $t -Encoding UTF8 }
function Run($cmd) { Log "`n> $cmd"; Invoke-Expression "$cmd 2>&1" | ForEach-Object { Log "$_" } }
function NewLog($fase, $name) {
  $dir = Join-Path $Root "evidencias\$fase"; New-Item -ItemType Directory -Force $dir | Out-Null
  $global:LOG = Join-Path $dir $name; Remove-Item $global:LOG -ErrorAction SilentlyContinue
}
function Gate() {
  Write-Host "`nREVISOR/A DEL PLAN: lean la linea 'Plan:' de arriba." -ForegroundColor Yellow
  $ok = Read-Host "Escriban 'aprobado' para aplicar (cualquier otra cosa cancela)"
  Log "`nRevision del plan: $ok"
  $ok = $ok.Trim().Trim('"', "'").Trim(); if ($ok -notmatch "^aprobad[oa]$") { Write-Host "Cancelado." -ForegroundColor Red; exit 1 }
}
function Page($url) {
  Log "`n> GET $url"
  try { (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5).Content -split "`n" | Where-Object { $_ -match "<h1>|<title>" } | ForEach-Object { Log $_.Trim() } }
  catch { Log "ERROR: $_" }
}
function Serial() {
  $s = Get-Content (Join-Path $Root "infra\terraform.tfstate") -Raw | ConvertFrom-Json
  Log "serial = $($s.serial)"; Log "lineage = $($s.lineage)"
  Log "resources = $(($s.resources | ForEach-Object { "$($_.type).$($_.name)" }) -join ', ')"
}

function Mask($t) { if ($global:PG_PASS) { $t.Replace($global:PG_PASS, "********") } else { $t } }
function Log($t) { $t = Mask "$t"; Write-Host $t; Add-Content -Path $global:LOG -Value $t -Encoding UTF8 }
function Sql($q) { Run "docker exec tf-state-g1 psql -U terraform -d terraform_backend -c `"$q`"" }

NewLog "fase-7" "A-state-remoto.txt"
Log "=== Parte A, paso 1: backend PostgreSQL (fuera de Terraform) ==="
$sec = Read-Host "Contrasena para el backend (no se guarda en ningun archivo)" -AsSecureString
$global:PG_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if (-not $global:PG_PASS) { Write-Host "Contrasena vacia." -ForegroundColor Red; exit 1 }
Log "`n> docker run -d --name tf-state-g1 -e POSTGRES_USER=terraform -e POSTGRES_PASSWORD=******** -e POSTGRES_DB=terraform_backend -p 5433:5432 postgres:17-alpine"
docker run -d --name tf-state-g1 -e POSTGRES_USER=terraform -e "POSTGRES_PASSWORD=$global:PG_PASS" -e POSTGRES_DB=terraform_backend -p 5433:5432 postgres:17-alpine 2>&1 | ForEach-Object { Log "$_" }
for ($i = 0; $i -lt 30; $i++) { docker exec tf-state-g1 pg_isready -U terraform -d terraform_backend *> $null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 1 }
Start-Sleep 3
Run "docker exec tf-state-g1 pg_isready -U terraform -d terraform_backend"

Log "`n=== Paso 2: conexion en variable de entorno (solo en esta terminal) ==="
$env:PG_CONN_STR = "postgres://terraform:$($global:PG_PASS)@localhost:5433/terraform_backend?sslmode=disable"
Log '$env:PG_CONN_STR = "postgres://terraform:********@localhost:5433/terraform_backend?sslmode=disable"'

Log "`n=== Paso 3: backend pg vacio en main.tf ==="
Set-Location infra
$main = Get-Content main.tf -Raw
if ($main -notmatch 'backend "pg"') {
  $main = $main -replace '(?s)(required_providers \{.*?\r?\n  \})', "`$1`n`n  # La conexion llega desde la variable de entorno PG_CONN_STR`n  backend `"pg`" {}"
  Set-Content main.tf $main -NoNewline -Encoding UTF8
}
Run "Select-String -Path main.tf -Pattern 'backend'"

Log "`n=== Paso 4: migrar el state (-force-copy responde yes) ==="
Run "terraform init -no-color -migrate-state -force-copy"
Run "terraform state list"
Sql "SELECT id, name FROM terraform_remote_state.states;"

Log "`n=== Paso 5: prueba de bloqueo con dos terminales ==="
Write-Host "`nSe abre una SEGUNDA ventana (terminal 1) con un apply pendiente. NO respondan todavia." -ForegroundColor Yellow
Log "Terminal 1: terraform apply -replace=module.tienda.docker_container.this (queda esperando confirmacion)"
$cmd = "Set-Location '" + (Get-Location).Path + "'; terraform apply '-replace=module.tienda.docker_container.this'"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
Start-Process powershell -ArgumentList "-NoExit -EncodedCommand $enc"
Read-Host "Cuando la otra ventana muestre 'Enter a value:', presionen Enter aqui"
Log "`nTerminal 2:"
Run "terraform plan -no-color -lock-timeout=0s"
Write-Host "`nAhora escriban 'no' en la otra ventana y cierrenla." -ForegroundColor Yellow
Read-Host "Cuando hayan respondido 'no', presionen Enter aqui"
Log "Terminal 1 respondio 'no': Apply cancelled."
Run "terraform plan -no-color"

NewLog "fase-7" "B-ambientes.txt"
Log "=== Parte B, paso 6: destroy del workspace default ==="
Run "terraform plan -no-color -destroy -out fase7-destroy.tfplan"
Gate
Run "terraform apply -no-color fase7-destroy.tfplan"

Log "`n=== Pasos 7-8: ambientes en locals.tf y module sitio con for_each ==="
Copy-Item ..\scripts\fase7\main.tf, ..\scripts\fase7\locals.tf, ..\scripts\fase7\outputs.tf . -Force
Run "terraform fmt -recursive"
Log "`n=== Paso 9: init y prueba en el workspace default (debe fallar) ==="
Run "terraform init -no-color"
Run "terraform plan -no-color"

foreach ($ws in "dev", "staging", "prod") {
  Log "`n=== Workspace $ws ==="
  Run "terraform workspace new $ws"
  Run "terraform workspace show"
  Run "terraform plan -no-color -out fase7-$ws.tfplan"
  Write-Host "`nREVISOR/A: estan en el workspace '$ws'." -ForegroundColor Cyan
  Gate
  Run "terraform apply -no-color fase7-$ws.tfplan"
}
Run "terraform workspace list"
Start-Sleep 2
foreach ($p in 8101, 8201, 8202, 8203, 8301, 8302, 8303) { Page "http://localhost:$p" }
Sql "SELECT id, name FROM terraform_remote_state.states;"
Run "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' --filter name=-g1"

Log "`n=== Verificacion: la contrasena no esta en el repositorio ==="
Set-Location ..
git add .
git grep -F -q $global:PG_PASS
if ($LASTEXITCODE -eq 0) { Write-Host "La contrasena aparece en el repo. NO se hace commit." -ForegroundColor Red; exit 1 }
Log "git grep <contrasena del backend>: sin coincidencias"
git commit -m "fase-7: state remoto en PostgreSQL con bloqueo y ambientes dev, staging y prod"
Write-Host "`nFase 7 lista. Evidencias en evidencias\fase-7" -ForegroundColor Green
