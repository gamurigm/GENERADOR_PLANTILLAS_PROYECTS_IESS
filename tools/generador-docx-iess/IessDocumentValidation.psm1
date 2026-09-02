Set-StrictMode -Version Latest

function New-IessDiagnostic {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('error', 'warning')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [AllowNull()][string]$Field = $null,
        [AllowNull()][Nullable[int]]$Line = $null
    )

    [pscustomobject][ordered]@{
        severity = $Severity
        code     = $Code
        message  = $Message
        field    = $Field
        line     = $Line
    }
}

function Remove-IessDiacritics {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
    return -join @($normalized.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark
    })
}

function Get-IessLineNumber {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][int]$Index
    )

    if ($Index -le 0) { return 1 }
    return ([regex]::Matches($Content.Substring(0, $Index), "`n")).Count + 1
}

function Test-IessMarkdownSafety {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [int]$MaxLength = 5242880
    )

    $diagnostics = [Collections.Generic.List[object]]::new()

    if ($Content.Length -gt $MaxLength) {
        $diagnostics.Add((New-IessDiagnostic -Severity error -Code 'MARKDOWN_TOO_LARGE' `
            -Message "El Markdown supera el límite de $MaxLength caracteres." -Field 'markdown'))
    }

    $unsafePatterns = @(
        [pscustomobject]@{
            Code = 'UNSAFE_EXECUTABLE_CHUNK'
            Pattern = '(?im)^[ \t]*(?:`{3,}|~{3,})\s*\{[a-z][^}\r\n]*\}'
            Message = 'No se permiten bloques ejecutables de knitr dentro del Markdown.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_INLINE_R'
            Pattern = '(?i)`r\s+[^`\r\n]+`'
            Message = 'No se permiten expresiones R inline dentro del Markdown.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_EXTERNAL_RESOURCE'
            Pattern = '(?i)!\[[^\]]*\]\(\s*<?(?:https?|ftp|file):'
            Message = 'No se permiten imágenes obtenidas desde recursos externos.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_EXTERNAL_HTML_RESOURCE'
            Pattern = '(?i)<(?:img|iframe|object)\b[^>]*(?:src|data)\s*=\s*(?:["'']\s*)?(?:https?|ftp|file):'
            Message = 'No se permiten recursos HTML externos dentro del Markdown.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_ABSOLUTE_IMAGE_PATH'
            Pattern = '(?i)!\[[^\]]*\]\(\s*<?(?:[a-z]:[\\/]|/|\\\\)'
            Message = 'Las imágenes no pueden usar rutas absolutas del contenedor.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_ABSOLUTE_HTML_RESOURCE'
            Pattern = '(?i)<(?:img|iframe|object)\b[^>]*(?:src|data)\s*=\s*(?:["'']\s*)?(?:[a-z]:[\\/]|/|\\\\|\.\.[\\/])'
            Message = 'Los recursos HTML no pueden usar rutas absolutas ni salir del directorio de trabajo.'
        },
        [pscustomobject]@{
            Code = 'UNSAFE_IMAGE_TRAVERSAL'
            Pattern = '(?i)!\[[^\]]*\]\([^)]*\.\.[\\/]'
            Message = 'Las imágenes no pueden salir del directorio de trabajo.'
        }
    )

    foreach ($definition in $unsafePatterns) {
        foreach ($match in [regex]::Matches($Content, $definition.Pattern)) {
            $diagnostics.Add((New-IessDiagnostic -Severity error -Code $definition.Code `
                -Message $definition.Message -Field 'markdown' `
                -Line (Get-IessLineNumber -Content $Content -Index $match.Index)))
        }
    }

    return @($diagnostics)
}

function Test-IessMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [ValidateSet('standard', 'strict')][string]$Mode = 'standard',
        [int]$MaxLength = 5242880
    )

    $diagnostics = [Collections.Generic.List[object]]::new()
    foreach ($diagnostic in @(Test-IessMarkdownSafety -Content $Content -MaxLength $MaxLength)) {
        $diagnostics.Add($diagnostic)
    }

    if (-not $Content.Trim()) {
        $diagnostics.Add((New-IessDiagnostic -Severity error -Code 'EMPTY_MARKDOWN' `
            -Message 'El Markdown de entrada está vacío.' -Field 'markdown'))
    }

    $requiredHeadings = @(
        '1. ANTECEDENTES',
        '2. PROPOSITO',
        '3. OBJETIVO',
        '4. ALCANCE',
        '5. DEFINICIONES, ABREVIATURAS Y ACRONIMOS',
        '6. RESPONSABLES Y PARTES INTERESADAS',
        '7. MARCO NORMATIVO Y DOCUMENTAL',
        '8. DESARROLLO DEL DOCUMENTO',
        '9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS',
        '10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO',
        '11. CONCLUSIONES',
        '12. RECOMENDACIONES',
        '13. REFERENCIAS',
        '14. ANEXOS'
    )
    $headingContent = Remove-IessDiacritics -Value $Content
    foreach ($heading in $requiredHeadings) {
        if ($headingContent -notmatch ('(?m)^# ' + [regex]::Escape($heading) + '\s*$')) {
            $diagnostics.Add((New-IessDiagnostic -Severity error -Code 'MISSING_REQUIRED_HEADING' `
                -Message "Falta el encabezado: $heading" -Field 'markdown'))
        }
    }

    $pendingCount = ([regex]::Matches(
        $headingContent,
        '\[(?:Completar|INFORMACION NO ENCONTRADA)[^\]]*\]',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )).Count
    if ($pendingCount -gt 0) {
        $diagnostics.Add((New-IessDiagnostic -Severity warning -Code 'PENDING_PLACEHOLDERS' `
            -Message "Hay $pendingCount marcador(es) pendiente(s) de completar." -Field 'markdown'))
    }

    if ($Content -match '(?im)\b(password|passwd|secret|token|api[_-]?key|private[_-]?key)\b\s*[:=]\s*\S+') {
        $diagnostics.Add((New-IessDiagnostic -Severity warning -Code 'POSSIBLE_SECRET' `
            -Message 'Se detectó un posible dato sensible; revise el Markdown.' -Field 'markdown'))
    }

    $errors = @($diagnostics | Where-Object severity -eq 'error')
    $warnings = @($diagnostics | Where-Object severity -eq 'warning')
    $valid = $errors.Count -eq 0 -and -not ($Mode -eq 'strict' -and $warnings.Count -gt 0)

    [pscustomobject][ordered]@{
        valid       = $valid
        mode        = $Mode
        diagnostics = [object[]]$diagnostics.ToArray()
    }
}

Export-ModuleMember -Function Test-IessMarkdown, Test-IessMarkdownSafety
