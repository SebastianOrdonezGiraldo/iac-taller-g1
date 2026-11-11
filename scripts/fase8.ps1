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


$Bash = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path $Bash)) { $Bash = "bash" }
function RunBash($label) {
  Log "`n> bash validar.sh   ($label)"
  & $Bash validar.sh 2>&1 | ForEach-Object { Log "$_" }
  Log "Codigo de salida: $LASTEXITCODE"
}

Copy-Item scripts\fase8\validar.sh . -Force
New-Item -ItemType Directory -Force seguridad, infra\modules\sitio_web\tests | Out-Null
Copy-Item scripts\fase8\seguridad\bucket.tf seguridad\ -Force
Copy-Item scripts\fase8\tests\sitio_web.tftest.hcl infra\modules\sitio_web\tests\ -Force

# --- checkov ---
$env:CHECKOV = ""
if (Get-Command checkov -ErrorAction SilentlyContinue) { $env:CHECKOV = "checkov" }
else {
  python -c "import checkov" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Instalando checkov con pip (puede tardar unos minutos)..." -ForegroundColor Yellow
    python -m pip install --user checkov 2>&1 | Select-Object -Last 3
  }
  python -c "import checkov" 2>$null
  if ($LASTEXITCODE -eq 0) { $env:CHECKOV = "python -m checkov.main" }
}
if (-not $env:CHECKOV) { Write-Host "No se pudo instalar checkov (falta Python?). Avisenle a Claude." -ForegroundColor Red; exit 1 }

NewLog "fase-8" "1-analisis-estatico.txt"
Set-Location infra
terraform workspace select dev *> $null
Run "terraform workspace show"
Run "terraform fmt -check -recursive"
if ($LASTEXITCODE -ne 0) { Run "terraform fmt -recursive"; Run "terraform fmt -check -recursive" }
Run "terraform validate -no-color"

NewLog "fase-8" "2-terraform-test.txt"
Set-Location modules\sitio_web
Run "terraform init -no-color"
Log "`n(en paralelo se observa docker ps cada segundo mientras corren las pruebas)"
$obs = Start-Job { 1..40 | ForEach-Object { $t = Get-Date -Format "HH:mm:ss"; $r = docker ps --filter name=prueba-g1 --format "{{.Names}} {{.Status}} {{.Ports}}"; if ($r) { "$t  $r" } else { "$t  (sin contenedor prueba-g1)" }; Start-Sleep 1 } }
Run "terraform test -no-color"
Start-Sleep 3; Stop-Job $obs
$global:LOG = Join-Path $Root "evidencias\fase-8\2-docker-ps-durante-test.txt"; Remove-Item $global:LOG -ErrorAction SilentlyContinue
Receive-Job $obs | Get-Unique | ForEach-Object { Log $_ }
Remove-Job $obs
Set-Location $Root

NewLog "fase-8" "3-escaneo-seguridad.txt"
Log "=== Escaneo con el bucket publico (cuatro valores en false) ==="
Run "$env:CHECKOV -d seguridad --compact --quiet"
Log "`n=== Correccion: los cuatro valores a true ==="
(Get-Content seguridad\bucket.tf -Raw).Replace("= false", "= true") | Set-Content seguridad\bucket.tf -NoNewline -Encoding ASCII
Run "Get-Content seguridad\bucket.tf"
Log "`n=== Escaneo despues de corregir ==="
Run "$env:CHECKOV -d seguridad --compact --quiet"
Log "`n=== Resumen antes / despues ==="
$antes = (Get-Content (Join-Path $Root "evidencias\fase-8\3-escaneo-seguridad.txt") | Select-String "Passed checks:")
$antes | ForEach-Object { Log $_.Line.Trim() }

NewLog "fase-8" "4-validar-sh.txt"
Log "=== Ejecucion normal ==="
RunBash "todo correcto"
Log "`n=== Prueba: indentacion desordenada en infra/outputs.tf ==="
$orig = Get-Content infra\outputs.tf -Raw
($orig -replace '(?m)^  value', '        value') | Set-Content infra\outputs.tf -NoNewline -Encoding UTF8
RunBash "fmt desordenado"
Set-Content infra\outputs.tf $orig -NoNewline -Encoding UTF8
Log "`n=== Prueba: un valor del bucket de nuevo en false ==="
$b = Get-Content seguridad\bucket.tf -Raw
$b.Replace("block_public_acls       = true", "block_public_acls       = false") | Set-Content seguridad\bucket.tf -NoNewline -Encoding ASCII
RunBash "bucket publico"
Set-Content seguridad\bucket.tf $b -NoNewline -Encoding ASCII
Log "`n=== Ejecucion final con todo restaurado ==="
RunBash "restaurado"

git add .
git commit -m "fase-8: fmt, validate, terraform test, escaneo con checkov y validar.sh"
Write-Host "`nFase 8 lista. Evidencias en evidencias\fase-8" -ForegroundColor Green
