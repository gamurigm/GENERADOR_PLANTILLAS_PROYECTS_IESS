# Analizador de proyectos IESS

Estas herramientas preparan la documentación técnica de un proyecto ubicado en cualquier directorio, sin copiarlo al repositorio del generador.

## 1. Analizar un proyecto

```powershell
powershell -ExecutionPolicy Bypass -File `
"C:\ruta\GENERADOR_PLANTILLAS_PROYECTS_IESS\tools\analizador-proyecto-iess\analizar_proyecto_iess.ps1" `
-ProjectPath "D:\Proyectos\MiSistema" `
-OutputDirectory "D:\Proyectos\MiSistema\documentacion-generada" `
-ProjectName "MiSistema"
```

Se generan:

- `inventario-proyecto.json`: archivos y extensiones detectados.
- `prompt-generar-documentacion.md`: instrucción para una IA.
- `documentacion.md`: esqueleto institucional editable.

Por seguridad, excluye dependencias, artefactos compilados, repositorios Git, archivos `.env`, llaves y certificados.

## 2. Validar el Markdown

```powershell
powershell -ExecutionPolicy Bypass -File `
"C:\ruta\GENERADOR_PLANTILLAS_PROYECTS_IESS\tools\analizador-proyecto-iess\validar_markdown_iess.ps1" `
-InputMarkdown "D:\Proyectos\MiSistema\documentacion-generada\documentacion.md"
```

Usa `-Strict` si los marcadores pendientes o posibles secretos deben causar un error.

## 3. Generar el DOCX

Después de revisar el Markdown, se utiliza `tools/generador-docx-iess/generar_docx_desde_md_iess.ps1` con la ruta externa del Markdown, el JSON de metadatos y la ruta de salida.
