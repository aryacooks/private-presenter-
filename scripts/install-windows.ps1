$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Private Presenter requires 64-bit Windows.' }
$release = 'https://github.com/aryacooks/private-presenter-/releases/latest/download'
$asset = 'PrivatePresenter-windows-x64.zip'
$work = Join-Path ([IO.Path]::GetTempPath()) ('PrivatePresenter-' + [Guid]::NewGuid().ToString('N'))
$destination = Join-Path $env:LOCALAPPDATA 'Programs\Private Presenter'
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    Invoke-WebRequest "$release/$asset" -OutFile (Join-Path $work $asset)
    Invoke-WebRequest "$release/SHA256SUMS" -OutFile (Join-Path $work 'SHA256SUMS')
    $line = Get-Content (Join-Path $work 'SHA256SUMS') | Where-Object { $_ -match "  $([Regex]::Escape($asset))$" }
    if (-not $line) { throw 'The release checksum is missing.' }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash (Join-Path $work $asset) -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw 'Download checksum verification failed.' }
    $running = Get-Process PrivatePresenter -ErrorAction SilentlyContinue
    if ($running) { throw 'Quit Private Presenter from its tray menu, then run this installer again.' }
    Expand-Archive (Join-Path $work $asset) -DestinationPath (Join-Path $work 'app') -Force
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item (Join-Path $work 'app\*') -Destination $destination -Recurse -Force
    $shell = New-Object -ComObject WScript.Shell
    $programs = [Environment]::GetFolderPath('Programs')
    New-Item -ItemType Directory -Path $programs -Force | Out-Null
    $shortcut = $shell.CreateShortcut((Join-Path $programs 'Private Presenter.lnk'))
    $shortcut.TargetPath = Join-Path $destination 'PrivatePresenter.exe'
    $shortcut.WorkingDirectory = $destination
    $shortcut.Save()
    Write-Host "Installed Private Presenter in $destination"
    Start-Process (Join-Path $destination 'PrivatePresenter.exe')
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
