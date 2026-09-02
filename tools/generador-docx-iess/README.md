# Generador DOCX IESS desde Markdown

Convierte un archivo `.md` de cualquier proyecto en un `.docx` basado en la plantilla general IESS.

## Contrato para integración embebida

Para consumir el generador desde otra aplicación dentro del mismo contenedor, use `iess-docx-wrapper.ps1`. La aplicación crea un JSON de solicitud, ejecuta el comando como proceso hijo y analiza la única línea JSON devuelta por `stdout`.

```text
pwsh -NoLogo -NoProfile -NonInteractive \
  -File /opt/iess-docs/tools/generador-docx-iess/iess-docx-wrapper.ps1 \
  -RequestFile /app/var/iess/jobs/req-123/request.json \
  -OutputDirectory /app/var/iess/jobs/req-123 \
  -TimeoutSeconds 120
```

El contrato completo está en `request.schema.json` y existe una solicitud funcional en `request.ejemplo.json`.

Una generación correcta responde:

```json
{
  "schema_version": "1.0",
  "request_id": "req-123",
  "status": "completed",
  "valid": true,
  "code": null,
  "diagnostics": [],
  "artifact": {
    "artifact_id": "artifact_...",
    "path": "/app/var/iess/jobs/req-123/artifact_....docx",
    "filename": "artifact_....docx",
    "media_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "bytes": 90000,
    "sha256": "..."
  },
  "duration_ms": 6500
}
```

### Operaciones

- `validate`: valida estructura, contenido inseguro y advertencias; no requiere R ni produce artefacto.
- `generate`: valida primero y luego genera un DOCX. Requiere `metadata` con `title`, `doc_code` y `form_code`.
- `validation_mode=standard`: los marcadores pendientes y posibles secretos son advertencias.
- `validation_mode=strict`: las advertencias también bloquean la operación.

### Códigos de salida

| Código | Significado |
|---:|---|
| 0 | Operación completada |
| 2 | JSON, contrato o metadatos inválidos |
| 3 | Markdown inválido o inseguro |
| 4 | Dependencia no disponible |
| 5 | Fallo de renderizado o normalización DOCX |
| 6 | Tiempo de ejecución agotado |

La aplicación debe pasar los argumentos como una lista al crear el proceso, no construir una línea de shell con datos del usuario. La ruta de salida es configuración confiable de la aplicación y nunca debe recibirse directamente desde una petición HTTP.

El validador rechaza bloques ejecutables de knitr (`{r}`, `{bash}`, `{python}` y equivalentes), R inline y recursos de imagen externos o fuera del directorio de trabajo. Los bloques de código Markdown sin llaves, por ejemplo los identificados como `json`, se conservan como contenido no ejecutable.

## Integración en una imagen Linux

Copie el repositorio completo a una ruta estable como `/opt/iess-docs`. La imagen de la aplicación debe incluir:

- PowerShell 7 (`pwsh`).
- R y `Rscript`.
- Pandoc.
- Paquetes R `rmarkdown`, `officedown`, `officer` y `flextable` con versiones fijadas.
- Fuentes usadas por la plantilla institucional.

Las versiones con las que se verificó el módulo están registradas en `runtime-versions.json`; la imagen final debe fijarlas o utilizar versiones certificadas equivalentes.

Ejecute la aplicación y el wrapper con un usuario sin privilegios. Otorgue escritura únicamente al directorio de trabajos administrado por la aplicación. El wrapper no inicia servicios, no realiza descargas y elimina sus archivos temporales después de cada ejecución.

## Pruebas

Las validaciones rápidas y el renderizado completo se ejecutan con:

```powershell
pwsh -NoLogo -NoProfile -File .\tools\generador-docx-iess\probar_wrapper_iess.ps1
pwsh -NoLogo -NoProfile -File .\tools\generador-docx-iess\probar_wrapper_iess.ps1 -IncludeRender
```

## Estructura recomendada

```text
MiSistema/
├── mapa-arquitectura.md
├── datos-documento.json
└── salida/
```

El Markdown contiene el contenido técnico. El JSON contiene los datos de portada y las secciones opcionales.

## Uso

Desde la raíz de `Documentacion`:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\generador-docx-iess\generar_docx_desde_md_iess.ps1" `
  -InputMarkdown ".\MiSistema\mapa-arquitectura.md" `
  -MetadataJson ".\MiSistema\datos-documento.json" `
  -OutputDocx ".\MiSistema\salida\mapa-arquitectura.docx"
```

`-MetadataJson` es opcional. Si se omite, se conservan los valores de la plantilla general. El Markdown puede incluir front matter YAML; el generador lo retira para evitar duplicarlo dentro del RMarkdown.

Si el JSON no define estos campos, se aplican automáticamente los valores por defecto: tipo `ESTÁNDAR`, versión `1.0` y fecha del día de generación. Los valores explícitos del JSON tienen prioridad.

## Qué conserva

- Portada y metadatos institucionales.
- Tabla de contenido.
- Control de cambios, firmas y secciones generales de la plantilla.
- Referencia visual `referencia_estilo_iess.docx`.
- Tablas y títulos Markdown dentro de la sección de desarrollo.
- Normalización final de colores y estilos mediante `patch_docx_iess_styles.ps1`.

Los bloques Mermaid se conservan como bloques de código en el DOCX. Para diagramas gráficos se deben exportar previamente a PNG/SVG e insertarlos en el Markdown o ampliar el generador con un renderizador Mermaid.

## JSON mínimo

```json
{
  "title": "Mapa de arquitectura tecnológica de MiSistema",
  "doc_code": "ARQ-MIS-001",
  "doc_type": "Documento de arquitectura",
  "form_code": "ARQ-001",
  "version": "1.0",
  "security_level": "Restringido",
  "direction": "Dirección Nacional de Tecnologías de la Información",
  "subdirection": "Subdirección Nacional de Arquitectura y Soluciones",
  "date": "20/08/2026",
  "copyright_year": "2026",
  "include_risks": true,
  "include_indicators": false
}
```

## Dependencias

El uso directo requiere `Rscript` con los paquetes `rmarkdown`, `officedown`, `officer` y `flextable`. El wrapper embebido requiere además PowerShell 7 y Pandoc disponibles en `PATH`. El script reutiliza la plantilla y el normalizador existentes en la raíz del repositorio y en `tools`.
