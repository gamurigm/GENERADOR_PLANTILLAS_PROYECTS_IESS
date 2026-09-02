[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [ValidateRange(1, 900)]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$schemaVersion = '1.0'
$requestId = $null
$tempDirectory = $null
$outputPath = $null
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

function New-WrapperDiagnostic {
    param(
        [ValidateSet('error', 'warning')][string]$Severity,
        [string]$Code,
        [string]$Message,
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

function Write-WrapperResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )

    [Console]::Out.WriteLine(($Response | ConvertTo-Json -Depth 20 -Compress))
    exit $ExitCode
}

function Stop-WrapperRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$ExitCode = 1,
        [AllowNull()][string]$Field = $null,
        [AllowNull()][object[]]$Diagnostics = $null
    )

    $items = if ($null -ne $Diagnostics) {
        @($Diagnostics)
    } else {
        @(New-WrapperDiagnostic -Severity error -Code $Code -Message $Message -Field $Field)
    }
    $stopwatch.Stop()
    Write-WrapperResponse -ExitCode $ExitCode -Response ([pscustomobject][ordered]@{
        schema_version = $schemaVersion
        request_id     = $requestId
        status         = 'failed'
        valid          = $false
        code           = $Code
        diagnostics    = [object[]]@($items)
        artifact       = $null
        duration_ms    = $stopwatch.ElapsedMilliseconds
    })
}

function Get-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $command) { return $null }
    return $command.Source
}

function Test-GeneratedDocx {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -eq 0) { return $false }

    $archive = $null
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        return $null -ne $archive.GetEntry('[Content_Types].xml') -and
            $null -ne $archive.GetEntry('word/document.xml')
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $archive) { $archive.Dispose() }
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Stop-WrapperRequest -Code 'DEPENDENCY_UNAVAILABLE' -ExitCode 4 `
        -Message 'El wrapper requiere PowerShell 7 o superior.'
}

$scriptDirectory = $PSScriptRoot
$schemaPath = Join-Path $scriptDirectory 'request.schema.json'
$validationModule = Join-Path $scriptDirectory 'IessDocumentValidation.psm1'
$generatorPath = Join-Path $scriptDirectory 'generar_docx_desde_md_iess.ps1'
foreach ($requiredFile in @($schemaPath, $validationModule, $generatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        Stop-WrapperRequest -Code 'DEPENDENCY_UNAVAILABLE' -ExitCode 4 `
            -Message "No se encontró un componente requerido: $requiredFile"
    }
}

try {
    $resolvedRequest = (Resolve-Path -LiteralPath $RequestFile).Path
    $requestJson = [IO.File]::ReadAllText($resolvedRequest, [Text.Encoding]::UTF8)
}
catch {
    Stop-WrapperRequest -Code 'INVALID_JSON' -ExitCode 2 `
        -Message 'No se pudo leer el archivo JSON de solicitud.' -Field 'request'
}

try {
    $request = $requestJson | ConvertFrom-Json -Depth 20
    if ($request.PSObject.Properties.Name -contains 'request_id') {
        $requestId = [string]$request.request_id
    }
}
catch {
    Stop-WrapperRequest -Code 'INVALID_JSON' -ExitCode 2 `
        -Message 'El archivo de solicitud no contiene JSON válido.' -Field 'request'
}

$schemaErrors = @()
try {
    $schemaValid = Test-Json -Json $requestJson -SchemaFile $schemaPath `
        -ErrorAction SilentlyContinue -ErrorVariable +schemaErrors
}
catch {
    $schemaValid = $false
    $schemaErrors += $_
}
if (-not $schemaValid) {
    $schemaMessage = 'La solicitud no cumple el contrato JSON versión 1.0.'
    if ($schemaErrors.Count -gt 0) {
        $detail = [string]$schemaErrors[0]
        if ($detail.Length -gt 800) { $detail = $detail.Substring(0, 800) }
        $schemaMessage += ' ' + $detail
    }
    Stop-WrapperRequest -Code 'INVALID_METADATA' -ExitCode 2 `
        -Message $schemaMessage -Field 'request'
}

$validationMode = if ($request.PSObject.Properties.Name -contains 'validation_mode') {
    [string]$request.validation_mode
} else {
    'standard'
}

Import-Module $validationModule -Force
$validation = Test-IessMarkdown -Content ([string]$request.markdown) -Mode $validationMode
if (-not $validation.valid) {
    $hasUnsafeContent = @($validation.diagnostics | Where-Object { $_.code -like 'UNSAFE_*' }).Count -gt 0
    $failureCode = if ($hasUnsafeContent) { 'UNSAFE_MARKDOWN' } else { 'INVALID_MARKDOWN' }
    Stop-WrapperRequest -Code $failureCode -ExitCode 3 `
        -Message 'El Markdown no superó la validación.' -Diagnostics @($validation.diagnostics)
}

if ($request.operation -eq 'validate') {
    $stopwatch.Stop()
    Write-WrapperResponse -ExitCode 0 -Response ([pscustomobject][ordered]@{
        schema_version = $schemaVersion
        request_id     = $requestId
        status         = 'completed'
        valid          = $true
        code           = $null
        diagnostics    = [object[]]@($validation.diagnostics)
        artifact       = $null
        duration_ms    = $stopwatch.ElapsedMilliseconds
    })
}

if ($request.metadata.PSObject.Properties.Name -contains 'date') {
    $parsedDate = [datetime]::MinValue
    $validDate = [datetime]::TryParseExact(
        [string]$request.metadata.date,
        'dd/MM/yyyy',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsedDate
    )
    if (-not $validDate) {
        Stop-WrapperRequest -Code 'INVALID_METADATA' -ExitCode 2 `
            -Message 'El campo metadata.date no contiene una fecha válida con formato dd/MM/yyyy.' `
            -Field 'metadata.date'
    }
}

$pwshPath = Get-CommandPath -Name 'pwsh'
$rscriptPath = Get-CommandPath -Name 'Rscript'
$pandocPath = Get-CommandPath -Name 'pandoc'
$missingDependencies = @()
if (-not $pwshPath) { $missingDependencies += 'pwsh' }
if (-not $rscriptPath) { $missingDependencies += 'Rscript' }
if (-not $pandocPath) { $missingDependencies += 'pandoc' }
if ($missingDependencies.Count -gt 0) {
    Stop-WrapperRequest -Code 'DEPENDENCY_UNAVAILABLE' -ExitCode 4 `
        -Message ('No están disponibles estas dependencias: ' + ($missingDependencies -join ', ') + '.')
}

$rPackageCheck = 'packages <- c("rmarkdown","officedown","officer","flextable"); missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]; if (length(missing)) { cat(paste(missing, collapse=",")); quit(status=2) }'
$rPackageOutput = @(& $rscriptPath --vanilla -e $rPackageCheck 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) {
    $missingPackageMessage = if ($rPackageOutput.Trim()) {
        'No están disponibles todos los paquetes R requeridos. Detalle: ' + $rPackageOutput.Trim()
    } else {
        'No están disponibles todos los paquetes R requeridos.'
    }
    if ($missingPackageMessage.Length -gt 1200) {
        $missingPackageMessage = $missingPackageMessage.Substring(0, 1200)
    }
    Stop-WrapperRequest -Code 'DEPENDENCY_UNAVAILABLE' -ExitCode 4 -Message $missingPackageMessage
}

try {
    $outputFullPath = [IO.Path]::GetFullPath($OutputDirectory)
    $rootPath = [IO.Path]::GetPathRoot($outputFullPath)
    if ($outputFullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -eq
        $rootPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) {
        Stop-WrapperRequest -Code 'INVALID_METADATA' -ExitCode 2 `
            -Message 'El directorio de salida no puede ser la raíz del sistema.' -Field 'output_directory'
    }
    if (Test-Path -LiteralPath $outputFullPath -PathType Leaf) {
        Stop-WrapperRequest -Code 'INVALID_METADATA' -ExitCode 2 `
            -Message 'La ruta de salida corresponde a un archivo.' -Field 'output_directory'
    }
    if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
        New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null
    }
}
catch {
    Stop-WrapperRequest -Code 'INVALID_METADATA' -ExitCode 2 `
        -Message 'No se pudo preparar el directorio de salida.' -Field 'output_directory'
}

$artifactId = 'artifact_' + [guid]::NewGuid().ToString('N')
$outputPath = Join-Path $outputFullPath ($artifactId + '.docx')
$tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ('iess-docx-request-' + [guid]::NewGuid().ToString('N'))
$engineOutput = ''
$engineError = ''
$response = $null
$exitCode = 0

try {
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $markdownPath = Join-Path $tempDirectory 'documentacion.md'
    $metadataPath = Join-Path $tempDirectory 'metadata.json'
    $engineTempDirectory = Join-Path $tempDirectory 'engine-temp'
    New-Item -ItemType Directory -Path $engineTempDirectory | Out-Null
    [IO.File]::WriteAllText($markdownPath, [string]$request.markdown, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText(
        $metadataPath,
        ($request.metadata | ConvertTo-Json -Depth 20),
        [Text.UTF8Encoding]::new($false)
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwshPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.Environment['TMPDIR'] = $engineTempDirectory
    $startInfo.Environment['TMP'] = $engineTempDirectory
    $startInfo.Environment['TEMP'] = $engineTempDirectory
    foreach ($argument in @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-File', $generatorPath,
        '-InputMarkdown', $markdownPath,
        '-MetadataJson', $metadataPath,
        '-OutputDocx', $outputPath
    )) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'No se pudo iniciar el motor documental.' }
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch { }
        $process.WaitForExit()
        $engineOutput = $outputTask.GetAwaiter().GetResult()
        $engineError = $errorTask.GetAwaiter().GetResult()
        $process.Dispose()
        $stopwatch.Stop()
        $response = [pscustomobject][ordered]@{
            schema_version = $schemaVersion
            request_id     = $requestId
            status         = 'failed'
            valid          = $true
            code           = 'TIMEOUT'
            diagnostics    = [object[]]@(
                New-WrapperDiagnostic -Severity error -Code 'TIMEOUT' `
                    -Message "La generación superó el límite de $TimeoutSeconds segundos."
            )
            artifact       = $null
            duration_ms    = $stopwatch.ElapsedMilliseconds
        }
        $exitCode = 6
    } else {
        $engineOutput = $outputTask.GetAwaiter().GetResult()
        $engineError = $errorTask.GetAwaiter().GetResult()
        $engineExitCode = $process.ExitCode
        $process.Dispose()

        if ($engineExitCode -ne 0) {
            $combinedDetail = ($engineError + "`n" + $engineOutput).Trim()
            if ($combinedDetail.Length -gt 1600) { $combinedDetail = $combinedDetail.Substring(0, 1600) }
            $engineCode = if ($combinedDetail -match '(?i)normalizaci|patch_docx|parche') {
                'DOCX_PATCH_FAILED'
            } else {
                'RENDER_FAILED'
            }
            throw "$engineCode`: $combinedDetail"
        }

        if (-not (Test-GeneratedDocx -Path $outputPath)) {
            throw 'RENDER_FAILED: el motor no produjo un archivo DOCX válido.'
        }

        $artifactFile = Get-Item -LiteralPath $outputPath
        $artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash.ToLowerInvariant()
        $stopwatch.Stop()
        $response = [pscustomobject][ordered]@{
            schema_version = $schemaVersion
            request_id     = $requestId
            status         = 'completed'
            valid          = $true
            code           = $null
            diagnostics    = [object[]]@($validation.diagnostics)
            artifact       = [pscustomobject][ordered]@{
                artifact_id = $artifactId
                path        = $artifactFile.FullName
                filename    = $artifactFile.Name
                media_type  = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                bytes       = $artifactFile.Length
                sha256      = $artifactHash
            }
            duration_ms    = $stopwatch.ElapsedMilliseconds
        }
    }
}
catch {
    $stopwatch.Stop()
    $detail = $_.Exception.Message
    $failureCode = if ($detail -like 'DOCX_PATCH_FAILED:*') { 'DOCX_PATCH_FAILED' } else { 'RENDER_FAILED' }
    if ($detail.Length -gt 1800) { $detail = $detail.Substring(0, 1800) }
    $response = [pscustomobject][ordered]@{
        schema_version = $schemaVersion
        request_id     = $requestId
        status         = 'failed'
        valid          = $true
        code           = $failureCode
        diagnostics    = [object[]]@(
            New-WrapperDiagnostic -Severity error -Code $failureCode -Message $detail
        )
        artifact       = $null
        duration_ms    = $stopwatch.ElapsedMilliseconds
    }
    $exitCode = 5
}
finally {
    if ($null -ne $tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($exitCode -ne 0 -and $null -ne $outputPath -and (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    }
}

Write-WrapperResponse -Response $response -ExitCode $exitCode
