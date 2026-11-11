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


$env:CHECKOV = ""
if (Get-Command checkov -ErrorAction SilentlyContinue) { $env:CHECKOV = "checkov" } else { $env:CHECKOV = "python -m checkov.main" }
Set-Location infra; terraform workspace select dev *> $null; Set-Location $Root

$global:LOG = Join-Path $Root "evidencias\fase-8\4-validar-sh.txt"
Log "`n=== Correccion: al restaurar infra/outputs.tf el script anterior le agrego un BOM (UTF-8), por eso fmt -check seguia fallando en las dos ultimas ejecuciones. Se quito el BOM y se repiten. ==="
Log "`n=== Prueba: un valor del bucket de nuevo en false ==="
$b = [IO.File]::ReadAllText("$Root\seguridad\bucket.tf")
[IO.File]::WriteAllText("$Root\seguridad\bucket.tf", $b.Replace("block_public_acls       = true", "block_public_acls       = false"))
RunBash "bucket publico"
[IO.File]::WriteAllText("$Root\seguridad\bucket.tf", $b)
Log "`n=== Ejecucion final con todo restaurado ==="
RunBash "restaurado"
git add .
git commit -m "fase-8: correccion de codificacion en outputs.tf y validar.sh final"
Write-Host "`nListo." -ForegroundColor Green
