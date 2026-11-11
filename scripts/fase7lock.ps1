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



$sec = Read-Host "Contrasena del backend (la misma de antes)" -AsSecureString
$global:PG_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PG_CONN_STR = "postgres://terraform:$($global:PG_PASS)@localhost:5433/terraform_backend?sslmode=disable"
Set-Location infra
terraform workspace select dev *> $null

$global:LOG = Join-Path $Root "evidencias\fase-7\C-prueba-bloqueo.txt"
Log "`n=== Incidente: en la terminal 1 se confirmo el apply (-var=grupo=2) en lugar de cancelarlo ==="
Log "El contenedor de dev quedo como tienda-g2-dev; por eso la terminal 2 no encontro bloqueo. Se corrige volviendo al codigo."
Run "terraform workspace show"
Run "terraform plan -no-color -out fase7-fix.tfplan"
Gate
Run "terraform apply -no-color fase7-fix.tfplan"

Log "`n=== Prueba de bloqueo, nuevo intento ==="
Log "Terminal 1: terraform console (mantiene el bloqueo del state mientras esta abierta; no puede aplicar cambios)"
$cmd = "`$env:PG_CONN_STR = '" + $env:PG_CONN_STR + "'; Set-Location '" + (Get-Location).Path + "'; terraform workspace select dev; Write-Host 'TERMINAL 1: consola abierta con el state bloqueado. Para liberar escriban exit' -ForegroundColor Yellow; terraform console"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
Start-Process powershell -ArgumentList "-NoExit -EncodedCommand $enc"
$ok = $false
for ($i = 1; $i -le 3 -and -not $ok; $i++) {
  Write-Host "`nEsperen a que la OTRA ventana muestre el prompt '>' de la consola." -ForegroundColor Yellow
  Read-Host "Cuando lo vean, presionen Enter aqui"
  Log "`nTerminal 2 (intento $i):"
  $out = terraform plan -no-color -lock-timeout=0s 2>&1 | ForEach-Object { "$_" }
  $out | ForEach-Object { Log $_ }
  if (($out -join "`n") -match "Error acquiring the state lock") { $ok = $true }
  else { Write-Host "La terminal 2 no encontro el bloqueo todavia; se repite." -ForegroundColor Red }
}
if (-not $ok) { Write-Host "No se logro reproducir el bloqueo. Peguen lo que muestra la otra ventana." -ForegroundColor Red; exit 1 }
Write-Host "`nBloqueo comprobado. Escriban 'exit' en la OTRA ventana y luego cierrenla." -ForegroundColor Green
$r = Read-Host "Cuando hayan salido de la consola, escriban 'listo' aqui"
Log "`nTerminal 1 (confirmado por el grupo): $r - se cerro la consola y se libero el bloqueo."
Log "`n=== Verificacion: bloqueo liberado y dev igual al codigo ==="
Run "terraform plan -no-color -lock-timeout=0s"
Set-Location ..
git add .
git grep -F -q $global:PG_PASS
if ($LASTEXITCODE -eq 0) { Write-Host "La contrasena aparece en el repo. NO se hace commit." -ForegroundColor Red; exit 1 }
git commit -m "fase-7: prueba de bloqueo del state verificada"
Write-Host "`nPrueba de bloqueo lista." -ForegroundColor Green
