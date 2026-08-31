param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$ProjectName,
    [int]$MaxFiles = 5000
)

$ErrorActionPreference = 'Stop'

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputDirectory))
}

if (-not (Test-Path -LiteralPath $project -PathType Container)) {
    throw "El directorio del proyecto no existe: $project"
}
New-Item -ItemType Directory -Path $output -Force | Out-Null

if (-not $ProjectName) { $ProjectName = Split-Path -Leaf $project }

$excludedDirectories = @(
    '.git', '.svn', '.hg', 'node_modules', 'dist', 'build', 'target',
    'bin', 'obj', '.next', '.angular', 'coverage', '.idea', '.vscode',
    'packages', 'vendor', '__pycache__', '.venv', 'venv'
)
$secretNames = @('.env', '.env.local', '.env.development', '.env.production', 'id_rsa', 'id_dsa')
$interestingNames = @(
    'README*', 'package.json', 'pom.xml', 'build.gradle*', 'requirements*.txt',
    'pyproject.toml', 'go.mod', 'Cargo.toml', 'Dockerfile*', 'docker-compose*.yml',
    '*.csproj', '*.sln', 'angular.json', 'vite.config.*', 'tsconfig*.json',
    'application*.yml', 'application*.yaml', 'application*.properties', '*.sql'
)
$extensions = @('.ps1','.psm1','.js','.jsx','.ts','.tsx','.java','.kt','.cs','.py','.go','.rs','.php','.rb','.sql','.yml','.yaml','.json','.xml','.properties','.toml','.md','.r','.R')

function Test-Excluded([IO.FileInfo]$file) {
    $relative = $file.FullName.Substring($project.Length).TrimStart('\','/')
    $parts = $relative -split '[\\/]'
    foreach ($part in $parts) {
        if ($excludedDirectories -contains $part) { return $true }
    }
    if ($secretNames -contains $file.Name -or $file.Name -like '*.pem' -or $file.Name -like '*.key') { return $true }
    return $false
}

function Get-RelativeProjectPath([string]$fullPath) {
    return $fullPath.Substring($project.Length).TrimStart('\','/').Replace('\','/')
}

$scanErrors = @()
$files = Get-ChildItem -LiteralPath $project -Recurse -File -Force `
    -ErrorAction SilentlyContinue -ErrorVariable +scanErrors |
    Where-Object { -not (Test-Excluded $_) } |
    Select-Object -First $MaxFiles

$relativeFiles = @($files | ForEach-Object {
    Get-RelativeProjectPath $_.FullName
})
$extensionCounts = @{}
foreach ($file in $files) {
    $ext = if ($file.Extension) { $file.Extension.ToLowerInvariant() } else { '[sin extensión]' }
    if (-not $extensionCounts.ContainsKey($ext)) { $extensionCounts[$ext] = 0 }
    $extensionCounts[$ext]++
}
$keyFiles = @($files | Where-Object {
    $name = $_.Name
    ($interestingNames | Where-Object { $name -like $_ }).Count -gt 0
} | ForEach-Object { Get-RelativeProjectPath $_.FullName })

$inventory = [ordered]@{
    generated_at = (Get-Date).ToString('s')
    project_name = $ProjectName
    project_path = $project
    scanned_files = $files.Count
    truncated = ($files.Count -ge $MaxFiles)
    excluded_directories = $excludedDirectories
    files_by_extension = $extensionCounts
    key_files = $keyFiles
    files = $relativeFiles
    scan_warnings = @($scanErrors | ForEach-Object { $_.Exception.Message } | Select-Object -Unique)
    review_required = @(
        'Confirmar propósito, alcance y responsables con el equipo del proyecto.',
        'Revisar que no se haya incorporado información sensible.',
        'Validar tecnologías, integraciones, seguridad y despliegue contra la realidad operativa.'
    )
}
$inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'inventario-proyecto.json') -Encoding utf8

$fileList = ($relativeFiles | ForEach-Object { '- ' + $_ }) -join "`r`n"
$keyList = if ($keyFiles.Count) { ($keyFiles | ForEach-Object { '- ' + $_ }) -join "`r`n" } else { '- No se detectaron archivos de configuración conocidos.' }
$prompt = @"
# Prompt para generar documentación del proyecto

Genera un borrador de documentación técnica institucional para el proyecto **$ProjectName**.

Usa exclusivamente la información disponible en el inventario y los archivos que el usuario te proporcione.
No inventes datos. Cuando un dato no pueda confirmarse, escribe:
`[INFORMACIÓN NO ENCONTRADA EN EL PROYECTO: completar manualmente]`

Devuelve únicamente Markdown UTF-8 con estos encabezados exactos:

# 1. ANTECEDENTES
# 2. PROPÓSITO
# 3. OBJETIVO
## 3.1 Objetivos específicos
# 4. ALCANCE
## 4.1 Incluye
## 4.2 No incluye
# 5. DEFINICIONES, ABREVIATURAS Y ACRÓNIMOS
# 6. RESPONSABLES Y PARTES INTERESADAS
# 7. MARCO NORMATIVO Y DOCUMENTAL
# 8. DESARROLLO DEL DOCUMENTO
## 8.1 Descripción general de la solución
## 8.2 Arquitectura
## 8.3 Estructura del proyecto
## 8.4 Componentes principales
## 8.5 Tecnologías utilizadas
## 8.6 Flujos principales
## 8.7 Integraciones
## 8.8 Seguridad
## 8.9 Configuración y despliegue
# 9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS
# 10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO
# 11. CONCLUSIONES
# 12. RECOMENDACIONES
# 13. REFERENCIAS
# 14. ANEXOS

## Archivos relevantes detectados
$keyList

## Archivos del proyecto
$fileList

No incluyas secretos, contraseñas, tokens, llaves privadas ni valores de archivos `.env`.
Marca como "por confirmar" cualquier inferencia.
"@
$prompt | Set-Content -LiteralPath (Join-Path $output 'prompt-generar-documentacion.md') -Encoding utf8

$skeleton = @"
# 1. ANTECEDENTES

[Completar con el contexto del proyecto.]

# 2. PROPÓSITO

[Completar.]

# 3. OBJETIVO

[Completar.]

## 3.1 Objetivos específicos

- [Completar]

# 4. ALCANCE

## 4.1 Incluye

- [Completar]

## 4.2 No incluye

- [Completar]

# 5. DEFINICIONES, ABREVIATURAS Y ACRÓNIMOS

[Completar.]

# 6. RESPONSABLES Y PARTES INTERESADAS

[Completar.]

# 7. MARCO NORMATIVO Y DOCUMENTAL

[Completar.]

# 8. DESARROLLO DEL DOCUMENTO

## 8.1 Descripción general de la solución

[Completar.]

## 8.2 Arquitectura

[Completar.]

## 8.3 Estructura del proyecto

[Completar.]

## 8.4 Componentes principales

[Completar.]

## 8.5 Tecnologías utilizadas

[Completar.]

## 8.6 Flujos principales

[Completar.]

## 8.7 Integraciones

[Completar.]

## 8.8 Seguridad

[Completar.]

## 8.9 Configuración y despliegue

[Completar.]

# 9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS

[Completar.]

# 10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO

[Completar.]

# 11. CONCLUSIONES

[Completar.]

# 12. RECOMENDACIONES

[Completar.]

# 13. REFERENCIAS

[Completar.]

# 14. ANEXOS

[Completar.]
"@
$skeleton | Set-Content -LiteralPath (Join-Path $output 'documentacion.md') -Encoding utf8

Write-Output "Análisis creado en: $output"
