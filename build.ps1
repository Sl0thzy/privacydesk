$ErrorActionPreference='Stop'
$root=$PSScriptRoot
[IO.Directory]::CreateDirectory((Join-Path $root 'dist')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $root 'tests')) | Out-Null
$framework=Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319'
$compiler=Join-Path $framework 'csc.exe'
& (Join-Path $root 'make-icon.ps1')
$references=@('System.dll','System.Core.dll','System.Xaml.dll','System.Web.Extensions.dll','WPF\WindowsBase.dll','WPF\PresentationCore.dll','WPF\PresentationFramework.dll') | ForEach-Object {'/reference:'+(Join-Path $framework $_)}
$arguments=@('/nologo','/target:winexe','/platform:x64','/optimize+','/utf8output',('/out:'+(Join-Path $root 'dist\PrivacyDesk.exe')),('/win32manifest:'+(Join-Path $root 'src\app.manifest')),('/resource:'+(Join-Path $root 'src\Main.xaml')+',Main.xaml'),('/resource:'+(Join-Path $root 'src\Engine.ps1')+',Engine.ps1'))+$references+@(
('/win32icon:'+(Join-Path $root 'assets\privacydesk.ico')),
('/resource:'+(Join-Path $root 'assets\privacydesk.ico')+',logo.ico'),
('/resource:'+(Join-Path $root 'assets\privacydesk-logo-v1.png')+',logo.png'),
(Join-Path $root 'src\App.cs'))
& $compiler @arguments
if($LASTEXITCODE -ne 0){throw 'Build failed.'}
# Unprivileged UI preview harness, used only for visual QA with synthetic data.
$previewArgs=@('/out:'+(Join-Path $root 'tests\PrivacyDesk.Preview.exe'))+@($arguments | Where-Object {$_ -notlike '/win32manifest:*' -and $_ -notlike '/out:*'})
& $compiler @previewArgs
if($LASTEXITCODE -ne 0){throw 'Preview build failed.'}
Get-FileHash (Join-Path $root 'dist\PrivacyDesk.exe') -Algorithm SHA256 | Format-List
