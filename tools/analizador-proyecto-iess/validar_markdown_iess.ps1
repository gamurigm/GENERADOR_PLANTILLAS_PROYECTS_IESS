param(
    [Parameter(Mandatory = $true)]
    [string]$InputMarkdown,

    [switch]$Strict,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

$path = (Resolve-Path -LiteralPath $InputMarkdown).Path
$content = Get-Content -Raw -Encoding utf8 -LiteralPath $path
$toolRoot = Split-Path -Parent $PSScriptRoot
$validationModule = Join-Path (Join-Path $toolRoot 'generador-docx-iess') 'IessDocumentValidation.psm1'
if (-not (Test-Path -LiteralPath $validationModule -PathType Leaf)) {
    throw "No se encontró el módulo de validación: $validationModule"
}

Import-Module $validationModule -Force
$mode = if ($Strict) { 'strict' } else { 'standard' }
$result = Test-IessMarkdown -Content $content -Mode $mode

if ($AsJson) {
    [pscustomobject][ordered]@{
        schema_version = '1.0'
        status         = if ($result.valid) { 'completed' } else { 'failed' }
        valid          = $result.valid
        mode           = $result.mode
        diagnostics    = [object[]]@($result.diagnostics)
    } | ConvertTo-Json -Depth 10 -Compress | Write-Output
} else {
    $errors = @($result.diagnostics | Where-Object severity -eq 'error')
    $warnings = @($result.diagnostics | Where-Object severity -eq 'warning')
    if ($errors.Count -eq 0) {
        Write-Output 'OK: la estructura Markdown contiene todas las secciones requeridas.'
    } else {
        $errors | ForEach-Object { Write-Output "ERROR: $($_.message)" }
    }
    $warnings | ForEach-Object { Write-Output "ADVERTENCIA: $($_.message)" }
}

if (-not $result.valid) { exit 1 }
exit 0
