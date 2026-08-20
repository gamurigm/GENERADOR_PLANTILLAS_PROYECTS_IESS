param(
    [Parameter(Mandatory=$true)][string]$InputDocx,
    [Parameter(Mandatory=$true)][string]$OutputDocx
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$work = Join-Path ([IO.Path]::GetTempPath()) ("iess-docx-style-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
    [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $InputDocx).Path, $work)
    $stylesPath = Join-Path $work 'word\styles.xml'
    $styles = [IO.File]::ReadAllText($stylesPath)

    foreach ($pair in @{
        'Titre1' = '2E74B5'
        'Titre2' = '2E74B5'
        'Titre3' = '1F4D78'
        'Titre'  = '0B2545'
    }.GetEnumerator()) {
        $pattern = '(<w:style\b[^>]*w:styleId="' + [regex]::Escape($pair.Key) + '"[\s\S]*?</w:style>)'
        $styles = [regex]::Replace($styles, $pattern, {
            param($m)
            $block = $m.Groups[1].Value
            $block = [regex]::Replace($block, '(<w:color\b[^>]*w:val=")[0-9A-Fa-f]{6}("[^>]*/>)', {
                param($cm)
                $cm.Groups[1].Value + $pair.Value + $cm.Groups[2].Value
            }, 1)
            $block = [regex]::Replace($block, '\s+w:themeColor="[^"]+"', '')
            $block = [regex]::Replace($block, '\s+w:themeTint="[^"]+"', '')
            $block = [regex]::Replace($block, '\s+w:themeShade="[^"]+"', '')
            if ($pair.Key -eq 'Titre') {
                $block = [regex]::Replace($block, '<w:pBdr>[\s\S]*?</w:pBdr>', '')
            }
            $block
        }, 1)
    }

    [IO.File]::WriteAllText($stylesPath, $styles, [Text.UTF8Encoding]::new($false))
    $documentPath = Join-Path $work 'word\document.xml'
    $document = [IO.File]::ReadAllText($documentPath)
    $document = [regex]::Replace($document, '&lt;U\+([0-9A-Fa-f]{4,6})&gt;', {
        param($m)
        [char]::ConvertFromUtf32([Convert]::ToInt32($m.Groups[1].Value, 16))
    })
    foreach ($replacement in @{
        '[Recomendacion' = ('[Recomendaci' + [char]0x00F3 + 'n')
        '[Autor o institucion]' = ('[Autor o instituci' + [char]0x00F3 + 'n]')
        '([Ano])' = ('([A' + [char]0x00F1 + 'o])')
        '[Titulo del documento' = ('[' + [char]0x0054 + [char]0x00ED + 'tulo del documento')
        '[Incluya aqui anexos' = ('[Incluya aqu' + [char]0x00ED + ' anexos')
        'informacion complementaria' = ('informaci' + [char]0x00F3 + 'n complementaria')
        'ACRONIMOS' = ('ACR' + [char]0x00D3 + 'NIMOS')
    }.GetEnumerator()) {
        $document = $document.Replace($replacement.Key, $replacement.Value)
    }
    [IO.File]::WriteAllText($documentPath, $document, [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $OutputDocx) { Remove-Item -LiteralPath $OutputDocx -Force }
    $archive = [IO.Compression.ZipFile]::Open($OutputDocx, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $work -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($work.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            $inputStream = [IO.File]::OpenRead($_.FullName)
            $outputStream = $entry.Open()
            try { $inputStream.CopyTo($outputStream) }
            finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
