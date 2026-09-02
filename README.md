# Generador de documentación y DOCX IESS

Herramienta para analizar proyectos, validar documentación técnica en Markdown y generar documentos DOCX con la plantilla institucional del IESS.

El flujo es controlado y reproducible:

```text
Proyecto → inventario y borrador → Markdown revisado → validación → DOCX IESS
```

El analizador no envía información a servicios de IA. Solo genera un inventario, un prompt y un esqueleto documental para que el equipo decida qué información comparte y revise el contenido antes de publicarlo.

## Capacidades

- Analiza la estructura de un proyecto excluyendo dependencias, artefactos, `.env`, llaves y certificados.
- Valida las 14 secciones institucionales, marcadores pendientes y posibles secretos.
- Genera portada, cabecera, firmas, control de cambios, tabla de contenido, tablas y estilos IESS.
- Puede utilizarse por consola o como módulo embebido dentro del contenedor de otra aplicación.

## Integración como módulo

La opción recomendada es copiar el repositorio en la misma imagen Linux de la aplicación, por ejemplo en `/opt/iess-docs`, e invocar el wrapper como proceso hijo. No se inicia un servidor HTTP adicional.

```text
pwsh -NoLogo -NoProfile -NonInteractive \
  -File /opt/iess-docs/tools/generador-docx-iess/iess-docx-wrapper.ps1 \
  -RequestFile /app/var/iess/jobs/req-123/request.json \
  -OutputDirectory /app/var/iess/jobs/req-123 \
  -TimeoutSeconds 120
```

El contrato está definido en [request.schema.json](tools/generador-docx-iess/request.schema.json) y hay una solicitud funcional en [request.ejemplo.json](tools/generador-docx-iess/request.ejemplo.json).

- `validate` revisa el Markdown y devuelve diagnósticos sin generar archivos.
- `generate` valida y produce el DOCX.
- `standard` permite advertencias; `strict` también las trata como error.
- Toda respuesta se escribe como JSON en `stdout`.
- Una generación correcta devuelve `artifact_id`, ruta, nombre, tamaño, tipo MIME, SHA-256 y duración.

La aplicación consumidora administra autenticación, autorización, descarga y retención del DOCX. La ruta de salida debe proceder de configuración interna y no directamente de una petición de usuario.

## Uso local

Analizar un proyecto:

```powershell
pwsh -File .\tools\analizador-proyecto-iess\analizar_proyecto_iess.ps1 `
  -ProjectPath "D:\Proyectos\MiSistema" `
  -OutputDirectory "D:\Proyectos\MiSistema\documentacion-generada"
```

Validar y generar:

```powershell
pwsh -File .\tools\analizador-proyecto-iess\validar_markdown_iess.ps1 `
  -InputMarkdown ".\MiSistema\documentacion.md" -Strict

pwsh -File .\tools\generador-docx-iess\generar_docx_desde_md_iess.ps1 `
  -InputMarkdown ".\MiSistema\documentacion.md" `
  -MetadataJson ".\MiSistema\datos-documento.json" `
  -OutputDocx ".\MiSistema\salida\documentacion.docx"
```

`MetadataJson` define portada, códigos, versión, nivel de seguridad, responsables, firmas, control de cambios y secciones opcionales. Consulte [datos-documento.ejemplo.json](tools/generador-docx-iess/datos-documento.ejemplo.json).

## Seguridad y límites

- El wrapper acepta Markdown de hasta 5 MiB y aplica un timeout de 120 segundos por defecto.
- Se rechazan bloques ejecutables de knitr como `{r}`, `{bash}` o `{python}`, expresiones R inline, recursos externos y rutas de imagen inseguras.
- Los temporales y documentos parciales se eliminan al fallar o agotar el tiempo.
- Mermaid se conserva como código; para incluir el diagrama gráfico debe convertirse previamente a PNG o SVG.
- La versión inicial recibe Markdown y JSON; el análisis de proyectos continúa como una operación CLI separada.

## Dependencias y pruebas

La imagen o estación de trabajo necesita PowerShell 7, R, Pandoc y los paquetes R `rmarkdown`, `officedown`, `officer` y `flextable`. Las versiones verificadas están en [runtime-versions.json](tools/generador-docx-iess/runtime-versions.json).

```powershell
pwsh -NoLogo -NoProfile -File .\tools\generador-docx-iess\probar_wrapper_iess.ps1
pwsh -NoLogo -NoProfile -File .\tools\generador-docx-iess\probar_wrapper_iess.ps1 -IncludeRender
```

La segunda prueba ejecuta el renderizado completo y verifica el DOCX, checksum, cabecera XML, timeout y limpieza. La documentación detallada del contrato y los códigos de salida está en [tools/generador-docx-iess/README.md](tools/generador-docx-iess/README.md).
