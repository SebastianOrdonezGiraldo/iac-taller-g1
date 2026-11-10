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
  if ($ok -ne "aprobado") { Write-Host "Cancelado." -ForegroundColor Red; exit 1 }
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

# Ajuste: evidencias anteriores convertidas a UTF-8 + git status de la fase 2
NewLog "fase-2" "git-status.txt"
Run "git status --short"
git add evidencias
git commit -m "fase-2: evidencias en texto UTF-8 y git status"

NewLog "fase-3" "idempotencia-y-estado.txt"
Set-Location infra
Log "`n=== Paso 1: aplicar otra vez sin cambios ==="
Run "terraform apply -no-color -input=false"
Log "`n=== Paso 2: consultar el state ==="
Run "terraform state list"
Run "terraform state show -no-color docker_container.web"
Log "`n=== Paso 3: campos de terraform.tfstate (antes del cambio) ==="
Serial
Log "`n=== Paso 4: cambiar la imagen a nginx:1.28-alpine ==="
(Get-Content main.tf -Raw).Replace('nginx:1.27-alpine', 'nginx:1.28-alpine') | Set-Content main.tf -NoNewline -Encoding ASCII
Run "terraform plan -no-color -out fase3.tfplan"
Gate
Run "terraform apply -no-color fase3.tfplan"
Page "http://localhost:8080"
Log "`n=== Paso 5: confirmar estabilidad ==="
Run "terraform plan -no-color"
Serial
Set-Location ..
git add .
git commit -m "fase-3: idempotencia, lectura del state y reemplazo por cambio de imagen"
Write-Host "`nFase 3 lista. Evidencias en evidencias\fase-3" -ForegroundColor Green
