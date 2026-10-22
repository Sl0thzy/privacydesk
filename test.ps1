$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$ps=Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Engine.ps1') -Mode SelfTest -DataRoot (Join-Path $root 'tests')
if($LASTEXITCODE -ne 0){throw 'Engine tests failed'}
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'src\Engine.ps1') -Mode Audit | Set-Content (Join-Path $root 'tests\audit.local.jsonl') -Encoding utf8
if($LASTEXITCODE -ne 0){throw 'Read-only audit failed'}
$testHost=Join-Path $root 'tests\PrivacyDesk.Preview.exe'
if(-not (Test-Path $testHost)){throw 'Run build.ps1 first'}
$arguments='--ui-test "'+(Join-Path $root 'tests\audit.local.jsonl')+'" "'+(Join-Path $root 'tests')+'"'
$p=Start-Process -FilePath $testHost -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
if($p.ExitCode -ne 0){throw 'UI tests failed. See tests\ui-error.txt if present.'}
Get-Content (Join-Path $root 'tests\ui-tests.txt')
