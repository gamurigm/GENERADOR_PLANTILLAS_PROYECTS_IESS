param(
    [Parameter(Mandatory = $true)]
    [string]$InputMarkdown,

    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $InputMarkdown).Path
$content = Get-Content -Raw -Encoding utf8 -LiteralPath $path

function Remove-Diacritics([string]$Value) {
    $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
    return -join @($normalized.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark
    })
}

$headingContent = Remove-Diacritics $content
$required = @(
    '1. ANTECEDENTES','2. PROPÓSITO','3. OBJETIVO','4. ALCANCE',
    '5. DEFINICIONES, ABREVIATURAS Y ACRÓNIMOS','6. RESPONSABLES Y PARTES INTERESADAS',
    '7. MARCO NORMATIVO Y DOCUMENTAL','8. DESARROLLO DEL DOCUMENTO',
    '9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS','10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO',
    '11. CONCLUSIONES','12. RECOMENDACIONES','13. REFERENCIAS','14. ANEXOS'
)
$requiredAscii = @(
    '1. ANTECEDENTES','2. PROPOSITO','3. OBJETIVO','4. ALCANCE',
    '5. DEFINICIONES, ABREVIATURAS Y ACRONIMOS','6. RESPONSABLES Y PARTES INTERESADAS',
    '7. MARCO NORMATIVO Y DOCUMENTAL','8. DESARROLLO DEL DOCUMENTO',
    '9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS','10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO',
    '11. CONCLUSIONES','12. RECOMENDACIONES','13. REFERENCIAS','14. ANEXOS'
)
$missing = @($requiredAscii | Where-Object { $headingContent -notmatch ('(?m)^# ' + [regex]::Escape($_) + '\s*$') })
$pending = ([regex]::Matches($content, '\[(?:Completar|INFORMACIÓN NO ENCONTRADA)[^\]]*\]', 'IgnoreCase')).Count
$pending = ([regex]::Matches($headingContent, '\[(?:Completar|INFORMACION NO ENCONTRADA)[^\]]*\]', 'IgnoreCase')).Count
$errors = @($missing | ForEach-Object { "Falta el encabezado: $_" })
$warnings = @()
if ($pending -gt 0) { $warnings += "Hay $pending marcador(es) pendiente(s) de completar." }
if ($content -match '(?i)(password|passwd|secret|token|api[_-]?key)\s*[:=]') { $warnings += 'Posible dato sensible detectado; revisar el Markdown.' }

if ($errors.Count -eq 0) { Write-Output 'OK: la estructura Markdown contiene todas las secciones requeridas.' }
else { $errors | ForEach-Object { Write-Output "ERROR: $_" } }
$warnings | ForEach-Object { Write-Output "ADVERTENCIA: $_" }

if ($errors.Count -gt 0 -or ($Strict -and $warnings.Count -gt 0)) { exit 1 }
exit 0
