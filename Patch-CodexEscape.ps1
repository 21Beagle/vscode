[CmdletBinding()]
param(
    [string]$ExtensionPath,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
if (-not $ExtensionPath) {
    $extensionRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
    $ExtensionPath = (Get-ChildItem -LiteralPath $extensionRoot -Directory -Filter 'openai.chatgpt-*' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $ExtensionPath) { throw 'The installed Codex VS Code extension was not found.' }
$manifest = Get-Content -Raw -LiteralPath (Join-Path $ExtensionPath 'package.json') | ConvertFrom-Json
if ($manifest.publisher -ne 'openai' -or $manifest.name -ne 'chatgpt') {
    throw 'The target is not the OpenAI Codex extension.'
}
$assets = Join-Path $ExtensionPath 'webview\assets'
$files = @(Get-ChildItem -LiteralPath $assets -File -Filter 'wsl-remote-connections-feature-*.js' |
    Where-Object { (Get-Content -Raw -LiteralPath $_.FullName).Contains('canStopFromEscape') })
if ($files.Count -ne 1) { throw 'The expected Escape handler was not found uniquely. This extension version needs a fresh review.' }
$target = $files[0].FullName
$backup = "$target.before-editor-escape.bak"
if ($Restore) {
    if (-not (Test-Path -LiteralPath $backup)) { throw "Backup not found: $backup" }
    Copy-Item -LiteralPath $backup -Destination $target -Force
    Write-Output 'Original Codex Escape behavior restored. Reload VS Code.'
    return
}
$source = [System.IO.File]::ReadAllText($target)
$stopOriginal = 'return(e===`local`||e===`cloud`)&&t&&n&&!r'
$stopPatched = 'return(e===`local`||e===`cloud`)&&t&&!1&&!r'
$inputOriginal = ':e.key===`Escape`&&!e.metaKey&&!e.ctrlKey&&!e.altKey&&!e.shiftKey&&!n&&'
$inputPatched = ':!1&&e.key===`Escape`&&!e.metaKey&&!e.ctrlKey&&!e.altKey&&!e.shiftKey&&!n&&'
if ($source.Contains($stopPatched) -and $source.Contains($inputPatched)) {
    Write-Output 'Codex Escape patch is already applied.'
    return
}
foreach ($anchor in @($stopOriginal, $inputOriginal)) {
    if ([regex]::Matches($source, [regex]::Escape($anchor)).Count -ne 1) {
        throw 'Escape handler differs from the reviewed version; no changes were made.'
    }
}
if (Test-Path -LiteralPath $backup) {
    if ([System.IO.File]::ReadAllText($backup) -cne $source) { throw 'The existing backup differs from the original source; no changes were made.' }
} else {
    Copy-Item -LiteralPath $target -Destination $backup
}
$updated = $source.Replace($stopOriginal, $stopPatched).Replace($inputOriginal, $inputPatched)
[System.IO.File]::WriteAllText($target, $updated, $utf8)
Write-Output "Patched Codex $($manifest.version). Backup: $backup"
Write-Output 'Run Developer: Reload Window to load the changed webview code.'
