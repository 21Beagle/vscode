[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'extensions\scm-keybindings'
$manifest = Get-Content -Raw -LiteralPath (Join-Path $source 'package.json') | ConvertFrom-Json
$buildRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('beagle-scm-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $buildRoot 'package'
$extensionRoot = Join-Path $packageRoot 'extension'
New-Item -ItemType Directory -Path $extensionRoot -Force | Out-Null
foreach ($name in @('package.json', 'extension.cjs')) {
    Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $extensionRoot $name)
}
$utf8 = [System.Text.UTF8Encoding]::new($false)
$contentTypes = '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="cjs" ContentType="application/javascript"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>'
[System.IO.File]::WriteAllText((Join-Path $packageRoot '[Content_Types].xml'), $contentTypes, $utf8)
$vsixManifest = @"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="$($manifest.name)" Version="$($manifest.version)" Publisher="$($manifest.publisher)"/>
    <DisplayName>$($manifest.displayName)</DisplayName>
    <Description xml:space="preserve">$($manifest.description)</Description>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="$($manifest.engines.vscode)"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
"@
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'extension.vsixmanifest'), $vsixManifest, $utf8)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$vsix = Join-Path $buildRoot 'scm-keybindings.vsix'
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $vsix)
& code --install-extension $vsix --force
if ($LASTEXITCODE -ne 0) { throw 'The local Source Control helper could not be installed.' }
Write-Output 'Installed the local Source Control helper. Reload VS Code if the command is not available yet.'
