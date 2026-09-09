# libbox.ps1 - Windows-local twin of the root Makefile (same args, same order).
# Usage: pwsh scripts/libbox.ps1 main|legacy|windows
# Requires: sagernet/gomobile v0.1.13, ANDROID_HOME, ANDROID_NDK_HOME (NDK 28), JDK 17.
param(
    [Parameter(Mandatory)][ValidateSet('main', 'legacy', 'windows')][string]$Variant
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fork = Join-Path $root 'go\amnezia-box'
$version = '1.14.0-rc.1-awgm.15'
$ldflags = "-X github.com/sagernet/sing-box/constant.Version=$version -X runtime.godebugDefault=multipathtcp=0,tlssha1=1,tlsunsafeekm=1 -checklinkname=0 -s -w -buildid="
$tagsMain = 'with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_usbip,with_openvpn,with_openconnect,badlinkname,tfogo_checklinkname0,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird,with_awg'
$tagsWindows = "$tagsMain,with_purego"
$tagsLegacy = $tagsMain -replace 'with_naive_outbound,', ''

if ($Variant -eq 'windows') {
    $out = Join-Path $root 'windows\sing-box.exe'
    New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
    Push-Location $fork
    try { $env:CGO_ENABLED = '0'; & go build -trimpath -buildvcs=false -ldflags $ldflags -tags $tagsWindows -o $out ./cmd/sing-box } finally { Pop-Location }
    exit $LASTEXITCODE
}

$out = if ($Variant -eq 'main') { '../../android/app/libs/libbox.aar' } else { '../../android/app/libs/libbox-legacy.aar' }
$api = if ($Variant -eq 'main') { '24' } else { '21' }
$tags = if ($Variant -eq 'main') { $tagsMain } else { $tagsLegacy }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'android\app\libs') | Out-Null

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$goBin = (& go env GOPATH | Select-Object -First 1).Trim()
$gomobile = Join-Path $goBin 'bin\gomobile.exe'
if (-not (Test-Path $gomobile)) { throw "gomobile not found at $gomobile" }
$psi.FileName = $gomobile
$psi.WorkingDirectory = $fork
$psi.UseShellExecute = $false
foreach ($a in @(
    'bind', '-v', '-o', $out, '-target', 'android', '-androidapi', $api,
    '-javapkg=com.qanatvpn', '-libname=box', '-trimpath', '-buildvcs=false',
    '-ldflags', $ldflags, '-tags', $tags, './experimental/libbox'
)) { [void]$psi.ArgumentList.Add($a) }

foreach ($k in @($psi.EnvironmentVariables.Keys)) {
    if ($k.StartsWith('=')) { [void]$psi.EnvironmentVariables.Remove($k) }
}

$logOut = Join-Path $env:TEMP "libbox-$Variant-out.log"
$logErr = Join-Path $env:TEMP "libbox-$Variant-err.log"
$staleBuild = Join-Path $fork 'build'
if (Test-Path $staleBuild) { Remove-Item -Recurse -Force $staleBuild }
$p = [System.Diagnostics.Process]::Start($psi)
$outTask = $p.StandardOutput.ReadToEndAsync()
$errTask = $p.StandardError.ReadToEndAsync()
$p.WaitForExit()
[System.IO.File]::WriteAllText($logOut, $outTask.Result)
[System.IO.File]::WriteAllText($logErr, $errTask.Result)
Get-Content $logErr -Tail 12
exit $p.ExitCode
