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

NewLog "fase-4" "A-apagar.txt"
Log "=== Experimento A: apagar el servidor ==="
Run "docker stop web-g1"
Run "terraform plan -no-color -out fase4a.tfplan"
Gate
Run "terraform apply -no-color fase4a.tfplan"
Start-Sleep 2; Page "http://localhost:8080"

NewLog "fase-4" "B-borrar.txt"
Log "=== Experimento B: borrar el servidor ==="
Run "docker rm -f web-g1"
Log "`n--- plan -refresh-only ---"
Run "terraform plan -no-color -refresh-only"
Log "`n--- plan normal ---"
Run "terraform plan -no-color -out fase4b.tfplan"
Gate
Run "terraform apply -no-color fase4b.tfplan"
Start-Sleep 2; Page "http://localhost:8080"

NewLog "fase-4" "C-cambiar-por-dentro.txt"
Log "=== Experimento C: cambiar el contenido por dentro ==="
Log "`n> docker exec web-g1 sh -c `"echo '<h1>Cambio manual</h1>' > /usr/share/nginx/html/index.html`""
docker exec web-g1 sh -c "echo '<h1>Cambio manual</h1>' > /usr/share/nginx/html/index.html" 2>&1 | ForEach-Object { Log "$_" }
Page "http://localhost:8080"
Log "`n--- plan despues del cambio manual ---"
Run "terraform plan -no-color"
Log "`n--- correccion inmutable: -replace ---"
Run "terraform plan -no-color -replace=docker_container.web -out fase4c.tfplan"
Gate
Run "terraform apply -no-color fase4c.tfplan"
Start-Sleep 2; Page "http://localhost:8080"
Log "`n--- verificacion final ---"
Run "terraform plan -no-color"

Set-Location ..
git add .
git commit -m "fase-4: drift (apagar, borrar y cambiar por dentro)"
Write-Host "`nFase 4 lista. Evidencias en evidencias\fase-4" -ForegroundColor Green
