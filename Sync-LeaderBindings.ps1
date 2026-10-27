[CmdletBinding()]
param([switch]$Check, [switch]$ApplyToUser)

$ErrorActionPreference = 'Stop'
function Read-Jsonc([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $text = [regex]::Replace($text, '(?m)^\s*//[^\r\n]*', '')
    $text = [regex]::Replace($text, ',(\s*[}\]])', '$1')
    ConvertFrom-Json -InputObject $text
}
function Convert-Key([string[]]$Keys) {
    ($Keys | ForEach-Object {
        if ($_ -eq '<leader>') { 'space' }
        elseif ($_ -cmatch '^[A-Z]$') { 'shift+' + $_.ToLowerInvariant() }
        else { $_ }
    }) -join ' '
}
$settings = Read-Jsonc (Join-Path $PSScriptRoot 'settings.json')
if ($settings.'vim.leader' -ne '<space>') { throw 'This configuration expects Space as the leader.' }
$bindingsPath = Join-Path $PSScriptRoot 'keybindings.json'
$bindings = @(Read-Jsonc $bindingsPath)
$modeSpecs = @(
    @{ Name = 'normal'; Marker = "vim.mode == 'Normal'"; When = "editorTextFocus && (vim.mode == 'Normal' || neovim.mode == 'normal')" },
    @{ Name = 'visual'; Marker = "vim.mode == 'Visual'"; When = "editorTextFocus && (vim.mode == 'Visual' || vim.mode == 'VisualLine' || vim.mode == 'VisualBlock' || neovim.mode == 'visual')" },
    @{ Name = 'operatorPending'; Marker = "vim.mode == 'OperatorPendingMode'"; When = "editorTextFocus && vim.mode == 'OperatorPendingMode'" }
)
$added = @()
$checked = 0
foreach ($mode in $modeSpecs) {
    foreach ($mapping in $settings.('vim.' + $mode.Name + 'ModeKeyBindingsNonRecursive')) {
        if ($mapping.before[0] -ne '<leader>') { continue }
        $checked++
        $key = Convert-Key $mapping.before
        $covered = @($bindings | Where-Object { $_.key -ceq $key -and $_.when -and $_.when.Contains('editorTextFocus') -and $_.when.Contains($mode.Marker) })
        if ($covered.Count) { continue }
        $binding = [ordered]@{ key = $key; when = $mode.When }
        $commands = @($mapping.commands)
        if (-not $commands.Count -and -not $mapping.after) { throw "Empty mapping: $key" }
        $vimOnly = @($commands | Where-Object { ($_ -is [string] -and $_.StartsWith(':')) -or ($_.command -and $_.command.StartsWith(':')) }).Count -gt 0
        if ($mapping.after -or $vimOnly) {
            $binding.command = 'vim.remap'
            $args = [ordered]@{}
            if ($mapping.after) { $args.after = @($mapping.after) }
            if ($commands.Count) { $args.commands = @($commands | ForEach-Object { if ($_ -is [string]) { @{ command = $_ } } else { $_ } }) }
            $binding.args = $args
        } elseif ($commands.Count -eq 1) {
            if ($commands[0] -is [string]) { $binding.command = $commands[0] }
            else {
                $binding.command = $commands[0].command
                if ($commands[0].PSObject.Properties['args']) { $binding.args = $commands[0].args }
            }
        } else {
            $binding.command = 'runCommands'
            $binding.args = @{ commands = $commands }
        }
        $added += $binding
    }
}
if ($Check) {
    if ($added.Count) { throw ('Missing native leader bindings: ' + (($added | ForEach-Object { $_.key + ' [' + $_.when + ']' }) -join ', ')) }
    Write-Output "All $checked leader mappings have native coverage in their configured modes."
    return
}
if ($added.Count) {
    $text = [IO.File]::ReadAllText($bindingsPath)
    $newJson = ($added | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 15 -Compress }) -join ",`r`n    "
    $text = $text.Insert($text.LastIndexOf(']'), ",`r`n    " + $newJson + "`r`n")
    [IO.File]::WriteAllText($bindingsPath, $text, [Text.UTF8Encoding]::new($false))
    $null = Read-Jsonc $bindingsPath
}
if ($ApplyToUser) {
    $target = Join-Path $env:APPDATA 'Code\User\keybindings.json'
    Copy-Item -LiteralPath $target -Destination ($target + '.before-leader-audit-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak')
    Copy-Item -LiteralPath $bindingsPath -Destination $target -Force
}
Write-Output "Added $($added.Count) native bindings for $checked configured leader mappings."
