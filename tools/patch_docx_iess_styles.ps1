param(
    [Parameter(Mandatory=$true)][string]$InputDocx,
    [Parameter(Mandatory=$true)][string]$OutputDocx,

    # Campos opcionales para reemplazar placeholders de la cabecera institucional
    [string]$Direction,
    [string]$Subdirection,
    [string]$DocType,
    [string]$FormCode,
    [string]$DocDate,
    [string]$Version
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
            if ($pair.Key -in @('Titre1','Titre2','Titre3')) {
                $block = [regex]::Replace($block, '<w:numPr>[\s\S]*?</w:numPr>', '')
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

    # Las tablas Markdown que Pandoc crea directamente pueden quedar con
    # ancho automático. La cabecera ocupa el 100% del ancho útil, por lo que
    # normalizamos también esas tablas a la misma extensión y a layout fijo.
    $document = $document.Replace(
        '<w:tblW w:type="auto" w:w="0"/>',
        '<w:tblW w:type="pct" w:w="5000"/><w:tblLayout w:type="fixed"/>'
    )
    [IO.File]::WriteAllText($documentPath, $document, [Text.UTF8Encoding]::new($false))

    # --- Reemplazar placeholders de la cabecera institucional en header*.xml ---
    $headerPlaceholders = @{}
    if ($Direction)    { $headerPlaceholders['{{DIRECTION}}']    = $Direction }
    if ($Subdirection) { $headerPlaceholders['{{SUBDIRECTION}}'] = $Subdirection }
    if ($DocType)      { $headerPlaceholders['{{DOC_TYPE}}']     = $DocType }
    if ($FormCode)     { $headerPlaceholders['{{FORM_CODE}}']    = $FormCode }
    if ($DocDate)      { $headerPlaceholders['{{DATE}}']         = $DocDate }
    if ($Version)      { $headerPlaceholders['{{VERSION}}']      = $Version }

    if ($headerPlaceholders.Count -gt 0) {
        $headerFiles = Get-ChildItem -Path (Join-Path $work 'word') -Filter 'header*.xml' -File -ErrorAction SilentlyContinue
        foreach ($hf in $headerFiles) {
            $headerXml = [IO.File]::ReadAllText($hf.FullName)
            foreach ($ph in $headerPlaceholders.GetEnumerator()) {
                $headerXml = $headerXml.Replace($ph.Key, $ph.Value)
            }
            [IO.File]::WriteAllText($hf.FullName, $headerXml, [Text.UTF8Encoding]::new($false))
        }
    }

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
