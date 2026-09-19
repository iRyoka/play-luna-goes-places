[CmdletBinding()]
param(
    [string]$GodotBin,
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$project = Join-Path $root 'godot'
$version = (Get-Content -LiteralPath (Join-Path $root 'version.txt') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'version.txt must contain three-part SemVer.' }
if ([string]::IsNullOrWhiteSpace($GodotBin) -and (Test-Path -LiteralPath (Join-Path $root 'local.paths.ps1'))) {
    . (Join-Path $root 'local.paths.ps1')
    $GodotBin = $LunaGodotBin
}
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = (Get-Command godot -ErrorAction SilentlyContinue).Source }
if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    throw 'Pass -GodotBin or set $LunaGodotBin in local.paths.ps1.'
}
$output = Join-Path $root "builds/$version"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$mode = if ($Release) { '--export-release' } else { '--export-debug' }
& $GodotBin --path $project --headless $mode Android (Join-Path $output "luna-goes-places-$version.apk")
if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
$webStaging = Join-Path $output 'web-staging'
New-Item -ItemType Directory -Force -Path $webStaging | Out-Null
& $GodotBin --path $project --headless $mode Web (Join-Path $webStaging 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web export failed.' }
$webFiles = @(Get-ChildItem -LiteralPath $webStaging -Recurse -File)
foreach ($extension in @('.html', '.js', '.pck', '.wasm')) {
    if (@($webFiles | Where-Object { $_.Extension -eq $extension }).Count -eq 0) { throw "Web export is missing a $extension runtime file." }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$webArchive = Join-Path $output "luna-goes-places-web-$version.zip"
if (Test-Path -LiteralPath $webArchive) { Remove-Item -LiteralPath $webArchive -Force }
[IO.Compression.ZipFile]::CreateFromDirectory($webStaging, $webArchive, [IO.Compression.CompressionLevel]::Optimal, $false)
Remove-Item -LiteralPath $webStaging -Recurse -Force
