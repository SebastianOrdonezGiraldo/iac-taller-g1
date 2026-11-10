$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
function Run($cmd, $log) {
  "`n> $cmd" | Tee-Object -FilePath $log -Append
  Invoke-Expression "$cmd 2>&1" | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
}
$E = "evidencias\fase-1"; New-Item -ItemType Directory -Force $E | Out-Null
$log = "$E\clickops.txt"; Remove-Item $log -ErrorAction SilentlyContinue
Run "docker run -d --name clickops-g1 -p 8090:80 nginx:1.27-alpine" $log
Start-Sleep 2
"`n> GET http://localhost:8090" | Tee-Object -FilePath $log -Append
try { (Invoke-WebRequest http://localhost:8090 -UseBasicParsing).Content | Select-String "Welcome to nginx" | ForEach-Object { "$_".Trim() } | Tee-Object -FilePath $log -Append } catch { "$_" | Tee-Object -FilePath $log -Append }
Run "docker run -d --name clickops-g1 -p 8090:80 nginx:1.27-alpine" $log
Run "docker run -d --name clickops-g1-2 -p 8090:80 nginx:1.27-alpine" $log
Run "docker rm -f clickops-g1 clickops-g1-2" $log
Run "docker ps -a" $log
git add .
git commit -m "fase-1: servidor a mano (ClickOps) y evidencias"
Write-Host "`nFase 1 lista. Evidencias en $E" -ForegroundColor Green
