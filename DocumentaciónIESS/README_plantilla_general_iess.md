# Plantilla general de documentos IESS

Archivos principales:

- `plantilla_general_iess.Rmd`: fuente editable y reutilizable.
- `plantilla_general_iess.docx`: versión Word generada desde la fuente.

## Uso

1. Abra `plantilla_general_iess.Rmd` en RStudio o en un editor de texto.
2. Cambie primero los campos del bloque YAML al inicio del archivo:
   - título, código, tipo, versión, fecha y nivel de seguridad;
   - dirección y unidad responsable;
   - personas y roles de firmas;
   - historial de cambios;
   - secciones opcionales activadas o desactivadas.
3. Sustituya los textos entre corchetes `[ ... ]` por el contenido del documento.
4. Genere el DOCX ejecutando desde esta carpeta:

```r
rmarkdown::render(
  "plantilla_general_iess.Rmd",
  output_file = "documento_final.docx"
)
```

La forma recomendada es ejecutar el generador, porque trabaja en una carpeta temporal compatible con Windows, conserva las tildes y aplica automáticamente los estilos institucionales:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\generar_docx_iess.ps1" -OutputFile "documento_final.docx"
```

También puede ejecutar R Markdown directamente, pero en algunas instalaciones de R para Windows pueden aparecer problemas de codificación en textos generados desde bloques R. Si ocurre, aplique el corrector:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\patch_docx_iess_styles.ps1" `
  -InputDocx ".\DocumentaciónIESS\documento_final.docx" `
  -OutputDocx ".\DocumentaciónIESS\documento_final_corregido.docx"
```

La plantilla ya utiliza `referencia_estilo_iess.docx`, que mantiene la paleta institucional: azul `#003366` para encabezados de tablas, azul `#2E74B5` para títulos de sección, azul oscuro `#1F4D78` para subtítulos y `#0B2545` para el título principal.

`referencia_estilo_iess.docx` es un archivo técnico interno de estilos. No se edita ni se utiliza como documento final; el archivo que debe abrirse y entregarse es el DOCX generado.

## Generar un DOCX desde un Markdown de otro proyecto

Para documentar un sistema en otra carpeta, escriba el contenido en un `.md` y use el adaptador ubicado en `tools/generador-docx-iess`. El adaptador inserta el Markdown en la plantilla general, ejecuta R Markdown y normaliza el DOCX final:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\generador-docx-iess\generar_docx_desde_md_iess.ps1" `
  -InputMarkdown ".\MiSistema\mapa-arquitectura.md" `
  -MetadataJson ".\MiSistema\datos-documento.json" `
  -OutputDocx ".\MiSistema\salida\mapa-arquitectura.docx"
```

Consulte `tools/generador-docx-iess/README.md` y copie `datos-documento.ejemplo.json` para preparar los metadatos de portada. Esta ruta conserva la plantilla general; la conversión directa con Pandoc y un `reference-doc` solo aplica estilos y no genera toda la estructura institucional.

## Secciones opcionales

Cambie a `true` o `false` estos campos del YAML según el documento:

- `include_background`
- `include_purpose`
- `include_definitions`
- `include_responsibilities`
- `include_legal_framework`
- `include_risks`
- `include_indicators`
- `include_conclusions`
- `include_recommendations`
- `include_references`
- `include_annexes`

La tabla de firmas acepta múltiples personas por rol. Los roles incluidos son `elaborado`, `colaborado`, `revisado` y `aprobado`; el rol de colaboración puede eliminarse si no aplica.

## Dependencias

La conversión requiere los paquetes R `rmarkdown`, `officedown`, `officer` y `flextable`.
