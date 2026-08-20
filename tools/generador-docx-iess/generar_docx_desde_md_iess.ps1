param(
    [Parameter(Mandatory = $true)]
    [string]$InputMarkdown,

    [Parameter(Mandatory = $true)]
    [string]$OutputDocx,

    [string]$MetadataJson,

    [switch]$KeepIntermediate
)

$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $toolDir
$docDir = Get-ChildItem -LiteralPath $repoRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'plantilla_general_iess.Rmd')
} | Select-Object -First 1 -ExpandProperty FullName
if (-not $docDir) { throw 'No se encontró la carpeta que contiene plantilla_general_iess.Rmd.' }
$templateRmd = Join-Path $docDir 'plantilla_general_iess.Rmd'
$referenceDocx = Join-Path $docDir 'referencia_estilo_iess.docx'
$patcher = Join-Path $toolDir 'patch_docx_iess_styles.ps1'

if (-not (Test-Path -LiteralPath $templateRmd)) { throw "No se encontró la plantilla RMarkdown: $templateRmd" }
if (-not (Test-Path -LiteralPath $referenceDocx)) { throw "No se encontró el documento de referencia: $referenceDocx" }
if (-not (Test-Path -LiteralPath $patcher)) { throw "No se encontró el normalizador DOCX: $patcher" }

$inputPath = (Resolve-Path -LiteralPath $InputMarkdown).Path
$outputPath = if ([IO.Path]::IsPathRooted($OutputDocx)) {
    [IO.Path]::GetFullPath($OutputDocx)
} else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputDocx))
}
$outputParent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputParent)) {
    New-Item -ItemType Directory -Path $outputParent | Out-Null
}

$metadata = $null
if ($MetadataJson) {
    $metadataPath = (Resolve-Path -LiteralPath $MetadataJson).Path
    $metadata = Get-Content -Raw -Encoding utf8 -LiteralPath $metadataPath | ConvertFrom-Json
}

function Set-YamlScalar {
    param([string]$Text, [string]$Key, [object]$Value, [switch]$Boolean)
    if ($null -eq $Value) { return $Text }
    if ($Boolean) {
        $rendered = if ([bool]$Value) { 'true' } else { 'false' }
    } else {
        $rendered = '"' + ([string]$Value).Replace('\', '\\').Replace('"', '\"') + '"'
    }
    $pattern = '(?m)^' + [regex]::Escape($Key) + ':.*$'
    return [regex]::Replace($Text, $pattern, {
        param($match)
        $Key + ': ' + $rendered
    }, 1)
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('iess-md-render-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$originalLocation = (Get-Location).Path

try {
    Copy-Item -LiteralPath $templateRmd -Destination (Join-Path $temp 'plantilla_general_iess.Rmd')
    Copy-Item -LiteralPath $referenceDocx -Destination (Join-Path $temp 'referencia_estilo_iess.docx')

    $body = Get-Content -Raw -Encoding utf8 -LiteralPath $inputPath
    # Permite que el Markdown tenga front matter propio sin duplicarlo dentro del Rmd.
    $body = [regex]::Replace($body, '(?s)^---\r?\n.*?\r?\n---\r?\n', '')
    $body = $body.Trim()
    if (-not $body) { throw 'El Markdown de entrada está vacío después de retirar el front matter.' }

    $rmd = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $temp 'plantilla_general_iess.Rmd')
    $bodySection = "# 8. DESARROLLO DEL DOCUMENTO`r`n`r`n" + $body + "`r`n`r`n"
    $bodyPattern = '(?s)# 8\. DESARROLLO DEL DOCUMENTO.*?(```\{r heading-riesgos)'
    if (-not [regex]::IsMatch($rmd, $bodyPattern)) {
        throw 'No se encontró el bloque de desarrollo en la plantilla general.'
    }
    $rmd = [regex]::Replace($rmd, $bodyPattern, {
        param($match)
        $bodySection + $match.Groups[1].Value
    }, 1)

    if ($metadata) {
        $scalarKeys = @('title','doc_code','doc_type','form_code','version','security_level','institution','direction','subdirection','date','copyright_year')
        foreach ($key in $scalarKeys) {
            if ($metadata.PSObject.Properties.Name -contains $key) {
                $rmd = Set-YamlScalar -Text $rmd -Key $key -Value $metadata.$key
            }
        }
        foreach ($key in @('include_toc','include_definitions','include_background','include_purpose','include_responsibilities','include_legal_framework','include_risks','include_indicators','include_conclusions','include_recommendations','include_references','include_annexes')) {
            if ($metadata.PSObject.Properties.Name -contains $key) {
                $rmd = Set-YamlScalar -Text $rmd -Key $key -Value $metadata.$key -Boolean
            }
        }
    }

    [IO.File]::WriteAllText((Join-Path $temp 'plantilla_general_iess.Rmd'), $rmd, [Text.UTF8Encoding]::new($false))

    Push-Location $temp
    & Rscript --vanilla -e "rmarkdown::render('plantilla_general_iess.Rmd', output_file='rendered.docx', clean=TRUE)"
    if ($LASTEXITCODE -ne 0) { throw 'La conversión R Markdown falló.' }
    Pop-Location

    & powershell -ExecutionPolicy Bypass -File $patcher -InputDocx (Join-Path $temp 'rendered.docx') -OutputDocx $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'La normalización de estilos del DOCX falló.' }

    Write-Output "Documento creado: $outputPath"
    if ($KeepIntermediate) {
        $savedTemp = Join-Path $outputParent (([IO.Path]::GetFileNameWithoutExtension($outputPath)) + '-intermedio')
        Copy-Item -LiteralPath $temp -Destination $savedTemp -Recurse -Force
        Write-Output "Intermedios conservados en: $savedTemp"
    }
}
finally {
    if ((Get-Location).Path -ne $originalLocation) { Pop-Location }
    if ((Test-Path -LiteralPath $temp) -and -not $KeepIntermediate) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
