$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
function Run($cmd, $log) {
  "`n> $cmd" | Tee-Object -FilePath $log -Append
  Invoke-Expression "$cmd 2>&1" | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
}
$E = "evidencias\fase-2"; New-Item -ItemType Directory -Force $E | Out-Null
$log = "$E\ciclo.txt"; Remove-Item $log -ErrorAction SilentlyContinue
if (-not (Test-Path infra\main.tf)) { Copy-Item scripts\main.tf.fase2 infra\main.tf }
Set-Location infra
$log = "..\$log"
Run "terraform init -no-color" $log
Run "terraform fmt" $log
Run "terraform validate -no-color" $log
Run "terraform plan -no-color -out fase2.tfplan" $log
Write-Host "`nREVISOR/A DEL PLAN: lean la linea 'Plan:' de arriba." -ForegroundColor Yellow
$ok = Read-Host "Escriban 'aprobado' para aplicar (cualquier otra cosa cancela)"
"`nRevision del plan: $ok" | Tee-Object -FilePath $log -Append
if ($ok -ne "aprobado") { Write-Host "Cancelado." -ForegroundColor Red; exit 1 }
Run "terraform apply -no-color fase2.tfplan" $log
Run "terraform output -no-color" $log
"`n> GET http://localhost:8080" | Tee-Object -FilePath $log -Append
try { (Invoke-WebRequest http://localhost:8080 -UseBasicParsing).Content | Select-String "Welcome to nginx" | ForEach-Object { "$_".Trim() } | Tee-Object -FilePath $log -Append } catch { "$_" | Tee-Object -FilePath $log -Append }
Run "docker ps --filter name=web-g1" $log
Set-Location ..
git add .
Run "git status --short" $log
git add .
git commit -m "fase-2: primer despliegue con write-init-plan-apply"
Write-Host "`nFase 2 lista. Evidencias en $E" -ForegroundColor Green
