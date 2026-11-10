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


$global:LOG = Join-Path $Root "evidencias\fase-7\B-ambientes.txt"
Log "`n=== Reanudacion: el apply de dev se cancelo en la revision; se retoma desde dev ==="
$sec = Read-Host "Contrasena del backend (la misma de antes)" -AsSecureString
$global:PG_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PG_CONN_STR = "postgres://terraform:$($global:PG_PASS)@localhost:5433/terraform_backend?sslmode=disable"
Set-Location infra
foreach ($ws in "dev", "staging", "prod") {
  Log "`n=== Workspace $ws ==="
  terraform workspace select $ws *> $null
  if ($LASTEXITCODE -ne 0) { Run "terraform workspace new $ws" }
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
