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
$templateRmd = Join-Path $repoRoot 'plantilla_general_iess.Rmd'
$referenceDocx = Join-Path $repoRoot 'referencia_estilo_iess.docx'
$referenceFallback = Get-ChildItem -Path $repoRoot -Directory -Filter 'Documentaci*IESS' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'referencia_estilo_iess.docx' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not (Test-Path -LiteralPath $referenceDocx) -and $referenceFallback) {
    $referenceDocx = $referenceFallback
}
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

function ConvertTo-YamlQuoted {
    param([object]$Value)
    if ($null -eq $Value) { return '""' }
    return '"' + ([string]$Value).Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", ' ') + '"'
}

function Set-YamlBlock {
    param([string]$Text, [string]$StartKey, [string]$NextKey, [string[]]$Lines)
    if (-not $Lines -or $Lines.Count -eq 0) { return $Text }
    $pattern = '(?ms)^' + [regex]::Escape($StartKey) + ':\r?\n.*?(?=^' + [regex]::Escape($NextKey) + ':)'
    $replacement = ($Lines -join "`r`n") + "`r`n"
    return [regex]::Replace($Text, $pattern, { param($match) $replacement }, 1)
}

function Get-MetadataProperty {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) { return $null }
    return $Object.$Name
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
    # La numeración institucional admite como máximo cuatro niveles (1.2.3.4).
    # Se normalizan encabezados Markdown más profundos antes de renderizar.
    $body = [regex]::Replace($body, '(?m)^(#{5,})(?=\s)', '####')

    $rmd = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $temp 'plantilla_general_iess.Rmd')
    $fullBodyHandled = $false
    if ($body -match '(?m)^# 1\. ANTECEDENTES\s*$') {
        $fullBodyPattern = '(?s)# 1\. ANTECEDENTES.*$'
        if (-not [regex]::IsMatch($rmd, $fullBodyPattern)) {
            throw 'No se encontro el inicio del cuerpo institucional en la plantilla general.'
        }
        $rmd = [regex]::Replace($rmd, $fullBodyPattern, { param($match) $body + "`r`n" }, 1)
        $fullBodyHandled = $true
    }

    if (-not $fullBodyHandled) {
    $bodySection = "# 8. DESARROLLO DEL DOCUMENTO`r`n`r`n" + $body + "`r`n`r`n"
    $bodyPattern = '(?s)# 8\. DESARROLLO DEL DOCUMENTO.*?(```\{r heading-riesgos)'
    if (-not [regex]::IsMatch($rmd, $bodyPattern)) {
        throw 'No se encontró el bloque de desarrollo en la plantilla general.'
    }
    $rmd = [regex]::Replace($rmd, $bodyPattern, {
        param($match)
        $bodySection + $match.Groups[1].Value
    }, 1)
    }

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
        if ($metadata.PSObject.Properties.Name -contains 'firmas') {
            $signatureLines = @('firmas:')
            foreach ($role in @('elaborado','colaborado','revisado','aprobado')) {
                $people = @(Get-MetadataProperty -Object $metadata.firmas -Name $role)
                $people = @($people | Where-Object { $null -ne $_ })
                if ($people.Count -eq 0) { continue }
                $signatureLines += "  ${role}:"
                foreach ($person in $people) {
                    $signatureLines += '    - nombre: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $person 'nombre'))
                    $signatureLines += '      cargo: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $person 'cargo'))
                    $signatureLines += '      fecha: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $person 'fecha'))
                    $signatureLines += '      firma: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $person 'firma'))
                }
            }
            $rmd = Set-YamlBlock -Text $rmd -StartKey 'firmas' -NextKey 'control_cambios' -Lines $signatureLines
        }
        if ($metadata.PSObject.Properties.Name -contains 'control_cambios') {
            $changeLines = @('control_cambios:')
            foreach ($change in @($metadata.control_cambios)) {
                if ($null -eq $change) { continue }
                $changeLines += '  - version: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $change 'version'))
                $changeLines += '    fecha: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $change 'fecha'))
                $changeLines += '    autor: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $change 'autor'))
                $changeLines += '    descripcion: ' + (ConvertTo-YamlQuoted (Get-MetadataProperty $change 'descripcion'))
            }
            $rmd = Set-YamlBlock -Text $rmd -StartKey 'control_cambios' -NextKey 'output' -Lines $changeLines
        }
    }

    # Valores por defecto de la cabecera. La fecha se calcula en cada
    # generación para que el documento siempre use la fecha actual.
    $defaults = @{
        # Construido con Unicode para funcionar también con Windows PowerShell 5.1.
        'doc_type' = ('EST' + [char]0x00C1 + 'NDAR')
        'version'  = '1.0'
        'date'     = (Get-Date -Format 'dd/MM/yyyy')
    }
    foreach ($key in $defaults.Keys) {
        $current = $null
        if ($metadata -and $metadata.PSObject.Properties.Name -contains $key) {
            $current = [string]$metadata.$key
        }
        if (-not $current -or -not $current.Trim() -or $current -match '^\[') {
            $rmd = Set-YamlScalar -Text $rmd -Key $key -Value $defaults[$key]
        }
    }

    [IO.File]::WriteAllText((Join-Path $temp 'plantilla_general_iess.Rmd'), $rmd, [Text.UTF8Encoding]::new($false))

    Push-Location $temp
    & Rscript --vanilla -e "rmarkdown::render('plantilla_general_iess.Rmd', output_file='rendered.docx', clean=TRUE)"
    if ($LASTEXITCODE -ne 0) { throw 'La conversión R Markdown falló.' }
    Pop-Location

    # --- Extraer metadatos para la cabecera institucional ---
    # Se leen del JSON si están disponibles, o del YAML del RMD generado
    $headerArgs = @{}

    $headerFields = @{
        'Direction'    = 'direction'
        'Subdirection' = 'subdirection'
        'DocType'      = 'doc_type'
        'FormCode'     = 'form_code'
        'DocDate'      = 'date'
        'Version'      = 'version'
    }

    foreach ($entry in $headerFields.GetEnumerator()) {
        $paramName = $entry.Key
        $jsonKey   = $entry.Value
        $val = $null

        # Primero intentar desde el JSON de metadatos
        if ($metadata -and $metadata.PSObject.Properties.Name -contains $jsonKey) {
            $val = [string]$metadata.$jsonKey
        }

        # Si no viene del JSON, leer del RMD ya procesado
        if (-not $val -or -not $val.Trim()) {
            $rmdFinal = [IO.File]::ReadAllText((Join-Path $temp 'plantilla_general_iess.Rmd'))
            $yamlMatch = [regex]::Match($rmdFinal, '(?m)^' + [regex]::Escape($jsonKey) + ':\s*"([^"]*)"')
            if ($yamlMatch.Success) {
                $val = $yamlMatch.Groups[1].Value
            }
        }

        if ($val -and $val.Trim() -and $val -notmatch '^\[') {
            $headerArgs[$paramName] = $val
        }
    }

    # Construir argumentos para el patcher
    $patcherArgs = @(
        '-InputDocx', (Join-Path $temp 'rendered.docx'),
        '-OutputDocx', $outputPath
    )
    foreach ($ha in $headerArgs.GetEnumerator()) {
        $patcherArgs += "-$($ha.Key)"
        $patcherArgs += $ha.Value
    }

    & powershell -ExecutionPolicy Bypass -File $patcher @patcherArgs
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
