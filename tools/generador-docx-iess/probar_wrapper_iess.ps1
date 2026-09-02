[CmdletBinding()]
param(
    [switch]$IncludeRender
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$wrapper = Join-Path $PSScriptRoot 'iess-docx-wrapper.ps1'
$generator = Join-Path $PSScriptRoot 'generar_docx_desde_md_iess.ps1'
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('iess-docx-wrapper-tests-' + [guid]::NewGuid().ToString('N'))

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Prueba fallida: $Message" }
}

function Get-DocxHeaderText {
    param([Parameter(Mandatory = $true)][string]$Path)

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $texts = [Collections.Generic.List[string]]::new()
        foreach ($entry in @($archive.Entries | Where-Object { $_.FullName -like 'word/header*.xml' })) {
            $stream = $entry.Open()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
            try {
                $xmlDocument = [xml]$reader.ReadToEnd()
                $texts.Add($xmlDocument.DocumentElement.InnerText)
            }
            finally {
                $reader.Dispose()
                $stream.Dispose()
            }
        }
        return ($texts -join "`n")
    }
    finally {
        $archive.Dispose()
    }
}

function Invoke-TestRequest {
    param(
        [Parameter(Mandatory = $true)][object]$Request,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$TimeoutSeconds = 120
    )

    $caseDirectory = Join-Path $testRoot $Name
    $outputDirectory = Join-Path $caseDirectory 'output'
    New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
    $requestPath = Join-Path $caseDirectory 'request.json'
    [IO.File]::WriteAllText(
        $requestPath,
        ($Request | ConvertTo-Json -Depth 20),
        [Text.UTF8Encoding]::new($false)
    )

    $rawOutput = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $wrapper `
        -RequestFile $requestPath -OutputDirectory $outputDirectory `
        -TimeoutSeconds $TimeoutSeconds 2>&1) -join "`n"
    $processExitCode = $LASTEXITCODE
    try {
        $response = $rawOutput | ConvertFrom-Json -Depth 20
    }
    catch {
        throw "El caso '$Name' no devolvió JSON válido. Salida: $rawOutput"
    }

    [pscustomobject]@{
        exit_code       = $processExitCode
        response        = $response
        output_directory = $outputDirectory
    }
}

$validMarkdown = @'
# 1. ANTECEDENTES

Contexto confirmado.

# 2. PROPÓSITO

Propósito confirmado.

# 3. OBJETIVO

Objetivo confirmado.

# 4. ALCANCE

Alcance confirmado.

# 5. DEFINICIONES, ABREVIATURAS Y ACRÓNIMOS

Definiciones confirmadas.

# 6. RESPONSABLES Y PARTES INTERESADAS

Responsables confirmados.

# 7. MARCO NORMATIVO Y DOCUMENTAL

Marco confirmado.

# 8. DESARROLLO DEL DOCUMENTO

Contenido técnico confirmado.

# 9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS

Riesgos confirmados.

# 10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO

Indicadores confirmados.

# 11. CONCLUSIONES

Conclusiones confirmadas.

# 12. RECOMENDACIONES

Recomendaciones confirmadas.

# 13. REFERENCIAS

Referencias confirmadas.

# 14. ANEXOS

Anexos confirmados.
'@

$baseRequest = [ordered]@{
    schema_version = '1.0'
    request_id = 'test-valid-001'
    operation = 'validate'
    validation_mode = 'standard'
    markdown = $validMarkdown
}
$unsafeBlock = @'
```{r}
system('id')
```
'@
$unsafeShellBlock = @'
```{bash}
id
```
'@

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $valid = Invoke-TestRequest -Request $baseRequest -Name 'valid'
    Assert-Condition ($valid.exit_code -eq 0) 'la validación correcta debe finalizar con código 0'
    Assert-Condition ($valid.response.status -eq 'completed') 'la validación correcta debe completarse'
    Assert-Condition ([bool]$valid.response.valid) 'la validación correcta debe marcar valid=true'

    $missingHeadingRequest = [ordered]@{} + $baseRequest
    $missingHeadingRequest.request_id = 'test-missing-heading'
    $missingHeadingRequest.markdown = $validMarkdown.Replace("# 14. ANEXOS", "## 14. ANEXOS")
    $missing = Invoke-TestRequest -Request $missingHeadingRequest -Name 'missing-heading'
    Assert-Condition ($missing.exit_code -eq 3) 'un encabezado faltante debe finalizar con código 3'
    Assert-Condition ($missing.response.code -eq 'INVALID_MARKDOWN') 'un encabezado faltante debe reportar INVALID_MARKDOWN'

    $unsafeRequest = [ordered]@{} + $baseRequest
    $unsafeRequest.request_id = 'test-unsafe-r'
    $unsafeRequest.markdown = $validMarkdown + "`n`n" + $unsafeBlock
    $unsafe = Invoke-TestRequest -Request $unsafeRequest -Name 'unsafe-r'
    Assert-Condition ($unsafe.exit_code -eq 3) 'un bloque R debe finalizar con código 3'
    Assert-Condition ($unsafe.response.code -eq 'UNSAFE_MARKDOWN') 'un bloque R debe reportar UNSAFE_MARKDOWN'

    $unsafeShellRequest = [ordered]@{} + $baseRequest
    $unsafeShellRequest.request_id = 'test-unsafe-shell'
    $unsafeShellRequest.markdown = $validMarkdown + "`n`n" + $unsafeShellBlock
    $unsafeShell = Invoke-TestRequest -Request $unsafeShellRequest -Name 'unsafe-shell'
    Assert-Condition ($unsafeShell.exit_code -eq 3) 'un bloque bash debe finalizar con código 3'
    Assert-Condition ($unsafeShell.response.code -eq 'UNSAFE_MARKDOWN') 'un bloque bash debe reportar UNSAFE_MARKDOWN'

    $strictRequest = [ordered]@{} + $baseRequest
    $strictRequest.request_id = 'test-strict'
    $strictRequest.validation_mode = 'strict'
    $strictRequest.markdown = $validMarkdown + "`n`n[Completar dato institucional]"
    $strict = Invoke-TestRequest -Request $strictRequest -Name 'strict'
    Assert-Condition ($strict.exit_code -eq 3) 'un marcador en modo estricto debe bloquear la solicitud'
    Assert-Condition ($strict.response.code -eq 'INVALID_MARKDOWN') 'el modo estricto debe reportar INVALID_MARKDOWN'

    $invalidContract = [ordered]@{} + $baseRequest
    $invalidContract.Remove('request_id')
    $contract = Invoke-TestRequest -Request $invalidContract -Name 'invalid-contract'
    Assert-Condition ($contract.exit_code -eq 2) 'un contrato inválido debe finalizar con código 2'
    Assert-Condition ($contract.response.code -eq 'INVALID_METADATA') 'un contrato inválido debe reportar INVALID_METADATA'

    $externalImageRequest = [ordered]@{} + $baseRequest
    $externalImageRequest.request_id = 'test-external-image'
    $externalImageRequest.markdown = $validMarkdown + "`n`n![imagen](https://example.invalid/image.png)"
    $externalImage = Invoke-TestRequest -Request $externalImageRequest -Name 'external-image'
    Assert-Condition ($externalImage.exit_code -eq 3) 'una imagen externa debe finalizar con código 3'
    Assert-Condition ($externalImage.response.code -eq 'UNSAFE_MARKDOWN') 'una imagen externa debe reportar UNSAFE_MARKDOWN'

    $warningRequest = [ordered]@{} + $baseRequest
    $warningRequest.request_id = 'test-standard-warning'
    $warningRequest.markdown = $validMarkdown + "`n`ntoken: valor-de-prueba"
    $warning = Invoke-TestRequest -Request $warningRequest -Name 'standard-warning'
    Assert-Condition ($warning.exit_code -eq 0) 'una advertencia estándar no debe bloquear la validación'
    Assert-Condition (@($warning.response.diagnostics | Where-Object code -eq 'POSSIBLE_SECRET').Count -eq 1) 'debe informarse el posible secreto'

    $invalidDateRequest = [ordered]@{} + $baseRequest
    $invalidDateRequest.request_id = 'test-invalid-date'
    $invalidDateRequest.operation = 'generate'
    $invalidDateRequest.metadata = [ordered]@{
        title = 'Documento con fecha inválida'
        doc_code = 'TEST-DATE-001'
        form_code = 'TEST-FORM-001'
        date = '31/02/2026'
    }
    $invalidDate = Invoke-TestRequest -Request $invalidDateRequest -Name 'invalid-date'
    Assert-Condition ($invalidDate.exit_code -eq 2) 'una fecha inexistente debe finalizar con código 2'
    Assert-Condition ($invalidDate.response.code -eq 'INVALID_METADATA') 'una fecha inexistente debe reportar INVALID_METADATA'

    $directDirectory = Join-Path $testRoot 'direct-unsafe'
    New-Item -ItemType Directory -Path $directDirectory | Out-Null
    $directMarkdown = Join-Path $directDirectory 'unsafe.md'
    $directOutput = Join-Path $directDirectory 'unsafe.docx'
    [IO.File]::WriteAllText($directMarkdown, ($validMarkdown + "`n`n" + $unsafeBlock), [Text.UTF8Encoding]::new($false))
    $null = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $generator `
        -InputMarkdown $directMarkdown -OutputDocx $directOutput 2>&1)
    $directExitCode = $LASTEXITCODE
    Assert-Condition ($directExitCode -ne 0) 'el generador directo también debe rechazar bloques R'
    Assert-Condition (-not (Test-Path -LiteralPath $directOutput)) 'el generador directo no debe crear un artefacto inseguro'

    if ($IncludeRender) {
        $renderRequest = [ordered]@{} + $baseRequest
        $renderRequest.request_id = 'test-render-001'
        $renderRequest.operation = 'generate'
        $renderRequest.metadata = [ordered]@{
            title = 'Documento de integración'
            doc_code = 'TEST-DOC-001'
            doc_type = 'ESTÁNDAR'
            form_code = 'TEST-FORM-001'
            version = '1.0'
            security_level = 'Restringido'
            direction = 'Dirección de I+D & Arquitectura'
            date = '01/09/2026'
            copyright_year = '2026'
        }
        $render = Invoke-TestRequest -Request $renderRequest -Name 'render'
        Assert-Condition ($render.exit_code -eq 0) 'la generación completa debe finalizar con código 0'
        Assert-Condition ($render.response.status -eq 'completed') 'la generación completa debe completarse'
        Assert-Condition (Test-Path -LiteralPath $render.response.artifact.path -PathType Leaf) 'el DOCX debe existir'
        Assert-Condition ($render.response.artifact.sha256 -match '^[0-9a-f]{64}$') 'el DOCX debe incluir SHA-256'
        $headerText = Get-DocxHeaderText -Path $render.response.artifact.path
        Assert-Condition ($headerText -like '*I+D & Arquitectura*') 'la cabecera debe conservar caracteres que requieren escape XML'

        $timeoutRequest = [ordered]@{} + $renderRequest
        $timeoutRequest.request_id = 'test-timeout-001'
        $timeout = Invoke-TestRequest -Request $timeoutRequest -Name 'timeout' -TimeoutSeconds 1
        Assert-Condition ($timeout.exit_code -eq 6) 'un render fuera de tiempo debe finalizar con código 6'
        Assert-Condition ($timeout.response.code -eq 'TIMEOUT') 'un render fuera de tiempo debe reportar TIMEOUT'
        Assert-Condition (@(Get-ChildItem -LiteralPath $timeout.output_directory -Filter '*.docx' -File -ErrorAction SilentlyContinue).Count -eq 0) 'un timeout no debe conservar un DOCX parcial'
    }

    $count = if ($IncludeRender) { 12 } else { 10 }
    Write-Output "OK: $count casos del wrapper IESS superados."
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
