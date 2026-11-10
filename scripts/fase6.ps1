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
  if ($ok -notmatch "^aprobad[oa]$") { Write-Host "Cancelado." -ForegroundColor Red; exit 1 }
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

NewLog "fase-6" "modulos.txt"
Log "=== Pasos 1-7: modulo sitio_web y raiz limpia ==="
New-Item -ItemType Directory -Force infra\modules\sitio_web | Out-Null
Copy-Item scripts\fase6\modules\sitio_web\*.tf infra\modules\sitio_web\ -Force
Copy-Item scripts\fase6\*.tf, scripts\fase6\terraform.tfvars infra\ -Force
Set-Location infra
Run "Get-ChildItem -Recurse -Name -Include *.tf,*.tfvars"
Log "`n=== Paso 8: init (modulo nuevo), plan y apply ==="
Run "terraform init -no-color"
Run "terraform fmt -recursive"
Run "terraform validate -no-color"
Run "terraform plan -no-color -out fase6.tfplan"
Gate
Run "terraform apply -no-color fase6.tfplan"
Start-Sleep 2
Page "http://localhost:8081"
Page "http://localhost:8082"
Page "http://localhost:8083"
Run "terraform output -no-color urls"
Run "docker ps --filter name=-g1"
Log "`n=== Verificacion: sin cambios pendientes ==="
Run "terraform plan -no-color"
Set-Location ..
git add .
git commit -m "fase-6: modulo sitio_web usado tres veces (tienda, blog, docs)"
Write-Host "`nFase 6 lista. Evidencias en evidencias\fase-6" -ForegroundColor Green
