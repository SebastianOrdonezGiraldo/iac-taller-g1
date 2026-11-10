$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
function Run($cmd, $log) {
  "`n> $cmd" | Tee-Object -FilePath $log -Append
  Invoke-Expression "$cmd 2>&1" | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
}
$E = "evidencias\fase-0"; New-Item -ItemType Directory -Force $E | Out-Null
$log = "$E\herramientas.txt"; Remove-Item $log -ErrorAction SilentlyContinue
Run "terraform -version" $log
Run "docker version" $log
Run "git --version" $log
$log = "$E\imagenes.txt"; Remove-Item $log -ErrorAction SilentlyContinue
Run "docker pull nginx:1.27-alpine" $log
Run "docker pull nginx:1.28-alpine" $log
Run "docker pull postgres:17-alpine" $log
if (-not (git config user.name)) { Write-Host "`nFalta configurar git user.name / user.email (git config --global ...)" -ForegroundColor Red; exit 1 }
if (-not (Test-Path .git)) { git init }
git add .
git commit -m "fase-0: estructura inicial"
Write-Host "`nFase 0 lista. Evidencias en $E" -ForegroundColor Green
