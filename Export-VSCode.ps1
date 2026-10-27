[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$userRoot = Join-Path $env:APPDATA 'Code\User'
$repoRoot = $PSScriptRoot

function Export-UserFiles {
    param([string]$Source, [string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($name in @('settings.json', 'keybindings.json', 'tasks.json')) {
        $sourceFile = Join-Path $Source $name
        if (Test-Path -LiteralPath $sourceFile) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $Destination $name) -Force
        }
    }
    $snippets = Join-Path $Source 'snippets'
    if (Test-Path -LiteralPath $snippets) {
        Copy-Item -LiteralPath $snippets -Destination $Destination -Recurse -Force
    }
}

Export-UserFiles -Source $userRoot -Destination $repoRoot
$profileRoot = Join-Path $userRoot 'profiles'
if (Test-Path -LiteralPath $profileRoot) {
    foreach ($profile in Get-ChildItem -LiteralPath $profileRoot -Directory) {
        Export-UserFiles -Source $profile.FullName -Destination (Join-Path $repoRoot "profiles\$($profile.Name)")
        $extensionFile = Join-Path $profile.FullName 'extensions.json'
        if (Test-Path -LiteralPath $extensionFile) {
            $extensions = Get-Content -Raw -LiteralPath $extensionFile | ConvertFrom-Json
            $extensions | ForEach-Object { $_.identifier.id } | Sort-Object -Unique |
                Set-Content -LiteralPath (Join-Path $repoRoot "profiles\$($profile.Name)\extensions.txt") -Encoding utf8
        }
    }
}
$installed = Join-Path $env:USERPROFILE '.vscode\extensions\extensions.json'
if (Test-Path -LiteralPath $installed) {
    $extensions = Get-Content -Raw -LiteralPath $installed | ConvertFrom-Json
    $extensions | ForEach-Object { $_.identifier.id } | Sort-Object -Unique |
        Set-Content -LiteralPath (Join-Path $repoRoot 'extensions.txt') -Encoding utf8
}
Write-Output 'Exported VS Code settings, keybindings, tasks, snippets, and extension IDs.'
Write-Output 'Review git diff before committing. Deleted local files are not automatically removed from this repository.'
