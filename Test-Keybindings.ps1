[CmdletBinding()]
param([switch]$CheckInstalledCommands)
$ErrorActionPreference = 'Stop'
function Read-Jsonc([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $text = [regex]::Replace($text, '(?m)^\s*//[^\r\n]*', '')
    $text = [regex]::Replace($text, ',(\s*[}\]])', '$1')
    ConvertFrom-Json -InputObject $text
}
function Assert-True($Value, [string]$Message) { if (-not $Value) { throw $Message } }
& (Join-Path $PSScriptRoot 'Sync-LeaderBindings.ps1') -Check
$bindings = @(Read-Jsonc (Join-Path $PSScriptRoot 'keybindings.json'))
$duplicates = @($bindings | Group-Object { $_.key + '|' + $_.when } | Where-Object Count -gt 1)
Assert-True ($duplicates.Count -eq 0) ('Duplicate shortcuts: ' + ($duplicates.Name -join ', '))
$rename = @($bindings | Where-Object { $_.key -eq 'space c r' -and $_.command -eq 'editor.action.rename' })
Assert-True ($rename.Count -eq 1) 'Leader CR must invoke Rename Symbol.'
Assert-True ($rename[0].when.Contains('editorTextFocus')) 'Rename must be editor-only.'
$normalWatch = @($bindings | Where-Object { $_.key -eq 'space d w' -and $_.command -eq 'workbench.debug.action.focusWatchView' })
$visualWatch = @($bindings | Where-Object { $_.key -eq 'space d w' -and $_.command -eq 'editor.debug.action.selectionToWatch' })
Assert-True ($normalWatch.Count -eq 1 -and $normalWatch[0].when.Contains("vim.mode == 'Normal'")) 'Normal DW must focus Watch.'
Assert-True ($visualWatch.Count -eq 1 -and $visualWatch[0].when.Contains('editorHasSelection') -and $visualWatch[0].when.Contains("vim.mode == 'Visual'")) 'Visual DW must add the selection.'
foreach ($binding in $bindings | Where-Object { $_.key.StartsWith('space ') -and $_.when.Contains('editorTextFocus && (vim.mode') }) {
    Assert-True (-not $binding.when.Contains("'Insert'")) ('Leader chord must not intercept insert mode: ' + $binding.key)
}
$visualFormat = @($bindings | Where-Object { $_.key -eq 'space c f' -and $_.command -eq 'editor.action.formatSelection' })
Assert-True ($visualFormat.Count -eq 1 -and $visualFormat[0].when.Contains("vim.mode == 'Visual'")) 'Visual CF must format selection.'
foreach ($binding in $bindings | Where-Object { $_.when -and $_.when.Contains('workbench.debug.watchExpressionsView') -and $_.key -in @('j','k','a','d','e','p','enter','space') }) {
    Assert-True ($binding.when.Contains('!inputFocus') -and $binding.when.Contains('!textInputFocus')) ('Panel binding intercepts input: ' + $binding.key)
}
$listQuickOpen = @($bindings | Where-Object { $_.key -eq 'space space' -and $_.when.StartsWith('listFocus') })
Assert-True ($listQuickOpen.Count -eq 1 -and $listQuickOpen[0].when.Contains("focusedView != 'workbench.debug.watchExpressionsView'")) 'List Quick Open must not intercept Watch Space expansion.'
$marks = @($bindings | Where-Object { $_.key -eq "space '" })
Assert-True ($marks.Count -eq 1 -and $marks[0].command -eq 'vim.remap' -and $marks[0].args.commands[0].command -eq ':marks') 'Marks must use the supported Vim remap command format.'
$testTree = @($bindings | Where-Object { $_.when -and $_.when.StartsWith("focusedView == 'workbench.view.testing' &&") })
Assert-True ($testTree.Count -eq 8) 'Expected eight Testing tree controls.'
$expectedTests = @{ j = 'list.focusDown'; k = 'list.focusUp'; r = 'beagle.testing.runFocused'; d = 'beagle.testing.debugFocused'; o = 'testing.editFocusedTest'; 'shift+r' = 'testing.refreshTests'; enter = 'list.toggleExpand'; space = 'list.toggleExpand' }
foreach ($key in $expectedTests.Keys) {
    $matching = @($testTree | Where-Object { $_.key -eq $key -and $_.command -eq $expectedTests[$key] })
    Assert-True ($matching.Count -eq 1) ("Incorrect Testing control: $key")
    Assert-True ($matching[0].when.Contains('listFocus && !inputFocus && !textInputFocus')) ("Testing control intercepts input: $key")
}
Assert-True ($listQuickOpen[0].when.Contains("focusedView != 'workbench.view.testing'")) 'List Quick Open must not intercept Testing Space expansion.'
if ($CheckInstalledCommands) {
    $codeRoot = Split-Path (Split-Path (Get-Command code -ErrorAction Stop).Source)
    $app = Get-ChildItem -LiteralPath $codeRoot -Directory | ForEach-Object { Join-Path $_.FullName 'resources\app' } | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'out\vs\workbench\workbench.desktop.main.js') } | Select-Object -First 1
    Assert-True ($null -ne $app) 'Could not locate installed VS Code command definitions.'
    $definitions = [IO.File]::ReadAllText((Join-Path $app 'out\vs\workbench\workbench.desktop.main.js'))
    foreach ($root in @((Join-Path $app 'extensions'), (Join-Path $env:USERPROFILE '.vscode\extensions'))) {
        foreach ($extension in Get-ChildItem -LiteralPath $root -Directory) {
            $manifest = Join-Path $extension.FullName 'package.json'
            if (Test-Path -LiteralPath $manifest) { $definitions += [IO.File]::ReadAllText($manifest) }
        }
    }
    $commands = @()
    foreach ($binding in $bindings) {
        if ($binding.command -and -not $binding.command.StartsWith('-')) { $commands += $binding.command }
        if ($binding.command -in @('runCommands','vim.remap')) {
            foreach ($nested in $binding.args.commands) { if ($nested -is [string]) { $commands += $nested } else { $commands += $nested.command } }
        }
    }
    foreach ($command in $commands | Sort-Object -Unique) {
        if (-not $command.StartsWith(':')) {
            $found = $definitions.Contains('"' + $command + '"')
            if (-not $found -and $command -eq 'vim.remap') {
                $vim = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.vscode\extensions') -Directory -Filter 'vscodevim.vim-*' | Sort-Object Name -Descending | Select-Object -First 1
                if ($vim) { $found = [IO.File]::ReadAllText((Join-Path $vim.FullName 'out\extension.js')).Contains('"vim.remap"') }
            }
            Assert-True $found ('Command missing from installed definitions: ' + $command)
        }
    }
    Write-Output 'All native command targets are present in installed VS Code or extension definitions.'
}
Write-Output 'Passed: leader coverage, duplicate chords, rename, visual Watch/formatting, marks, and panel/input restrictions.'
