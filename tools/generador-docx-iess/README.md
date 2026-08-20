# Generador DOCX IESS desde Markdown

Convierte un archivo `.md` de cualquier proyecto en un `.docx` basado en la plantilla general IESS.

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

Requiere `Rscript` con los paquetes `rmarkdown`, `officedown`, `officer` y `flextable`. El script reutiliza la plantilla y el normalizador existentes en `DocumentaciónIESS` y `tools`.
