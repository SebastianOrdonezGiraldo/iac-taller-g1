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

NewLog "fase-5" "flexibilidad.txt"
Log "=== Paso 1: separar el codigo en archivos ==="
Copy-Item scripts\fase5\*.tf, scripts\fase5\terraform.tfvars infra\ -Force
Set-Location infra
Run "Get-ChildItem -Name"
Run "terraform fmt"
Run "terraform validate -no-color"
Log "`n=== Paso 6: planear y aplicar ==="
Run "terraform plan -no-color -out fase5.tfplan"
Gate
Run "terraform apply -no-color fase5.tfplan"
Start-Sleep 2; Page "http://localhost:8080"
Run "terraform output -no-color"
Log "`n=== Paso 7: terraform console ==="
$exprs = 'local.nombre', 'upper(var.mensaje)', 'format("web-g%02d", var.grupo)', 'local.etiquetas', 'data.docker_network.bridge.driver'
foreach ($e in $exprs) { Log "`n> $e"; ($e | terraform console 2>&1) | ForEach-Object { Log "$_" } }
Log "`n=== Paso 8: validacion del puerto (solo plan) ==="
Run 'terraform plan -no-color "-var=puerto=9500"'
Run 'terraform plan -no-color "-var=puerto=8085"'
Log "`n=== Verificacion: el apply anterior sigue sin cambios ==="
Run "terraform plan -no-color"
Set-Location ..
git add .
git commit -m "fase-5: variables, locals, data source, outputs y validacion del puerto"
Write-Host "`nFase 5 lista. Evidencias en evidencias\fase-5" -ForegroundColor Green
