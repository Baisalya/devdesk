[CmdletBinding()]
param(
  [string]$BuildDirectory = "build/windows/x64/runner/Release",
  [string]$OutputDirectory = "dist",
  [switch]$RequireSignature
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required Windows runtime file is missing: $Path"
  }
}

function Get-VersionFromPubspec {
  $line = Get-Content -LiteralPath "pubspec.yaml" | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
  if (-not $line) { throw "pubspec.yaml version was not found." }
  return (($line -replace '^version:\s*', '') -replace '\+', '-')
}

function Find-SignTool {
  $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $kitsRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
  if (Test-Path $kitsRoot) {
    $candidate = Get-ChildItem $kitsRoot -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
  }
  return $null
}

function Sign-PortableFiles([string]$Root) {
  $signTool = Find-SignTool
  $thumbprint = $env:DEVDESK_WINDOWS_CERT_SHA1
  $pfxPath = $env:DEVDESK_WINDOWS_PFX_PATH
  $pfxPassword = $env:DEVDESK_WINDOWS_PFX_PASSWORD
  $timestampUrl = $env:DEVDESK_WINDOWS_TIMESTAMP_URL
  $hasCertificate = (-not [string]::IsNullOrWhiteSpace($thumbprint)) -or
                    (-not [string]::IsNullOrWhiteSpace($pfxPath))

  if (-not $hasCertificate) {
    if ($RequireSignature) { throw "Windows signing credentials are required but unavailable." }
    Write-Warning "Portable bundle is unsigned. This is not a public release artifact."
    return $false
  }
  if (-not $signTool) { throw "signtool.exe was not found." }
  if ([string]::IsNullOrWhiteSpace($timestampUrl)) {
    throw "DEVDESK_WINDOWS_TIMESTAMP_URL is required for signed release artifacts."
  }

  $targets = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object { $_.Extension -in '.exe', '.dll' }
  foreach ($target in $targets) {
    $args = @('sign', '/fd', 'SHA256', '/tr', $timestampUrl, '/td', 'SHA256')
    if (-not [string]::IsNullOrWhiteSpace($thumbprint)) {
      $args += @('/sha1', $thumbprint)
    } else {
      if (-not (Test-Path -LiteralPath $pfxPath -PathType Leaf)) {
        throw "PFX file does not exist: $pfxPath"
      }
      $args += @('/f', $pfxPath)
      if (-not [string]::IsNullOrWhiteSpace($pfxPassword)) { $args += @('/p', $pfxPassword) }
    }
    $args += $target.FullName
    & $signTool @args
    if ($LASTEXITCODE -ne 0) { throw "Signing failed: $($target.FullName)" }
    & $signTool verify /pa /all $target.FullName
    if ($LASTEXITCODE -ne 0) { throw "Signature verification failed: $($target.FullName)" }
  }
  return $true
}

$build = (Resolve-Path -LiteralPath $BuildDirectory).Path
Require-File (Join-Path $build "devdesk.exe")
Require-File (Join-Path $build "flutter_windows.dll")
if (-not (Test-Path -LiteralPath (Join-Path $build "data") -PathType Container)) {
  throw "Flutter data directory is missing. Do not package only the executable."
}

$version = Get-VersionFromPubspec
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$stagingRoot = Join-Path $OutputDirectory "DevDesk-$version-windows-x64"
if (Test-Path $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
Copy-Item -Path (Join-Path $build '*') -Destination $stagingRoot -Recurse -Force
$stagingRoot = (Resolve-Path -LiteralPath $stagingRoot).Path

$signed = Sign-PortableFiles $stagingRoot
$inventoryPath = Join-Path $stagingRoot "ARTIFACT_INVENTORY.sha256"
$inventory = Get-ChildItem -LiteralPath $stagingRoot -Recurse -File |
  Where-Object { $_.FullName -ne $inventoryPath } |
  Sort-Object FullName |
  ForEach-Object {
    # Windows PowerShell 5.1 runs on .NET Framework, which does not expose
    # Path.GetRelativePath. Every enumerated file is already constrained to
    # $stagingRoot, so a prefix-relative path is safe and portable here.
    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $relative = $_.FullName.Substring($stagingRoot.Length).TrimStart($separators).Replace([IO.Path]::DirectorySeparatorChar, [char]'/')
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $relative"
  }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($inventoryPath, [string[]]$inventory, $utf8NoBom)

$zipPath = Join-Path $OutputDirectory "DevDesk-$version-windows-x64-portable.zip"
if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -LiteralPath $stagingRoot -DestinationPath $zipPath -CompressionLevel Optimal

$temp = Join-Path ([IO.Path]::GetTempPath()) ("devdesk-portable-" + [guid]::NewGuid())
Expand-Archive -LiteralPath $zipPath -DestinationPath $temp
$extractedRoot = Join-Path $temp (Split-Path $stagingRoot -Leaf)
Require-File (Join-Path $extractedRoot "devdesk.exe")
Require-File (Join-Path $extractedRoot "flutter_windows.dll")
Require-File (Join-Path $extractedRoot "ARTIFACT_INVENTORY.sha256")

foreach ($line in Get-Content -LiteralPath (Join-Path $extractedRoot "ARTIFACT_INVENTORY.sha256")) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $parts = $line -split '\s{2}', 2
  $file = Join-Path $extractedRoot ($parts[1].Replace('/', [IO.Path]::DirectorySeparatorChar))
  Require-File $file
  $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $parts[0]) { throw "Portable extraction hash mismatch: $($parts[1])" }
}
Remove-Item -LiteralPath $temp -Recurse -Force

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Write-Output "Portable ZIP: $((Resolve-Path $zipPath).Path)"
Write-Output "SHA-256: $zipHash"
Write-Output "Signed: $signed"
