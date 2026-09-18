$ErrorActionPreference = 'Stop'

$Repo = if ([string]::IsNullOrWhiteSpace($env:BAMARK_REPO)) { '44m0n/CommonMark.baml' } else { $env:BAMARK_REPO }
$Version = $env:BAMARK_VERSION
$InstallDir = if ([string]::IsNullOrWhiteSpace($env:BAMARK_INSTALL_DIR)) {
    Join-Path $env:LOCALAPPDATA 'Programs\bamark'
} else {
    $env:BAMARK_INSTALL_DIR
}

function Fail([string]$Message) {
    throw "bamark installer: $Message"
}

if ($Repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    Fail 'BAMARK_REPO must be in owner/repository form'
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $release = Invoke-RestMethod -Headers @{ Accept = 'application/vnd.github+json' } `
        -Uri "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $release.tag_name
}

if ($Version -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
    $Version = "v$Version"
}
if ($Version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
    Fail "invalid release version: $Version"
}

$BaseUrl = if ([string]::IsNullOrWhiteSpace($env:BAMARK_BASE_URL)) {
    "https://github.com/$Repo/releases/download/$Version"
} else {
    $env:BAMARK_BASE_URL.TrimEnd('/')
}
$Archive = "bamark-${Version}-windows-x86_64.zip"
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bamark-install-" + [guid]::NewGuid())
$ArchivePath = Join-Path $TempDir $Archive
$ChecksumsPath = Join-Path $TempDir 'SHA256SUMS'
$ExtractDir = Join-Path $TempDir 'extract'

try {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/$Archive" -OutFile $ArchivePath
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/SHA256SUMS" -OutFile $ChecksumsPath

    $checksumLine = Get-Content -LiteralPath $ChecksumsPath | Where-Object {
        $parts = $_ -split '\s+'
        $parts.Length -ge 2 -and $parts[1].TrimStart('*') -eq $Archive
    } | Select-Object -First 1
    if ($null -eq $checksumLine) {
        Fail "no checksum found for $Archive"
    }

    $Expected = (($checksumLine -split '\s+')[0]).ToLowerInvariant()
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath).Hash.ToLowerInvariant()
    if ($Actual -ne $Expected) {
        Fail 'checksum verification failed'
    }

    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExtractDir -Force
    $Binary = Join-Path $ExtractDir 'bamark.exe'
    if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) {
        Fail 'release archive did not contain bamark.exe'
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -LiteralPath $Binary -Destination (Join-Path $InstallDir 'bamark.exe') -Force

    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $PathEntries = if ([string]::IsNullOrWhiteSpace($UserPath)) { @() } else { $UserPath -split ';' | Where-Object { $_ } }
    if (-not ($PathEntries | Where-Object { $_.TrimEnd('\') -ieq $InstallDir.TrimEnd('\') })) {
        [Environment]::SetEnvironmentVariable('Path', (($PathEntries + $InstallDir) -join ';'), 'User')
        $PathAdded = $true
    } else {
        $PathAdded = $false
    }

    Write-Host "Installed bamark $Version to $InstallDir\bamark.exe"
    if ($PathAdded) {
        Write-Host 'Added the install directory to your user PATH; open a new shell to use it.'
    } else {
        Write-Host 'Open a new shell if bamark is not already available on PATH.'
    }
} finally {
    if (Test-Path -LiteralPath $TempDir) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
