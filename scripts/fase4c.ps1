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

Set-Location infra
$global:LOG = Join-Path $Root "evidencias\fase-4\C-cambiar-por-dentro.txt"
Log "`n=== Reintento de la correccion inmutable (el argumento -replace necesitaba comillas en PowerShell) ==="
Page "http://localhost:8080"
Run 'terraform plan -no-color "-replace=docker_container.web" -out fase4c.tfplan'
Gate
Run "terraform apply -no-color fase4c.tfplan"
Start-Sleep 2; Page "http://localhost:8080"
Log "`n--- verificacion final ---"
Run "terraform plan -no-color"
Set-Location ..
git add .
git commit -m "fase-4: correccion inmutable del experimento C con -replace"
Write-Host "`nExperimento C corregido." -ForegroundColor Green
