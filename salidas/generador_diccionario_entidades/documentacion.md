# 1. ANTECEDENTES

El proyecto `generador_diccionario_entidades` es una herramienta de análisis estático orientada a repositorios Java legacy. Su finalidad actual es recuperar evidencia de persistencia desde código fuente y archivos de configuración sin compilar, ejecutar ni modificar los aplicativos inspeccionados.

Esta documentación representa el estado observado el 21 de agosto de 2026. El corte incluye el árbol de trabajo local de la rama `feat/consolidacion-tablas-sql`, basado en el commit `4e60c5257c3dc3d5568c5262a8b060f3030ff8ac`, junto con cambios todavía no confirmados en Git. Por ello describe una versión en desarrollo y no una liberación estable.

# 2. PROPÓSITO

Registrar de forma verificable qué capacidades existen actualmente, cómo se ejecutan, qué artefactos producen y cuáles son sus restricciones. El documento separa las funciones comprobadas de los pendientes y evita presentar datos de prueba como información institucional real.

# 3. OBJETIVO

Disponer de una referencia técnica de la versión 0.1 que permita comprender, ejecutar, probar y revisar el extractor de persistencia y su modelo consolidado.

## 3.1 Objetivos específicos

- Describir la arquitectura y las responsabilidades de los módulos existentes.
- Documentar el flujo desde repositorios fuente hasta JSON y Mermaid.
- Precisar el contrato JSON 1.1 y las reglas de consolidación física.
- Registrar los resultados de pruebas y demostraciones reproducibles.
- Identificar limitaciones observadas y trabajo pendiente sin confundirlo con funcionalidad disponible.

# 4. ALCANCE

## 4.1 Incluye

- Paquete Python `persistence_extractor` y sus extractores JPA, Hibernate XML y SQL.
- Modelo normalizado, resolución de relaciones y consolidación por tabla física.
- Interfaz de línea de comandos y scripts PowerShell existentes.
- Generación de diagramas E/R en Mermaid.
- Pruebas unitarias e integrales presentes en `tests`.
- Estado local del repositorio, incluidos archivos modificados y nuevos visibles durante el corte.

## 4.2 No incluye

- Certificación contra una base de datos en ejecución o catálogo institucional oficial.
- Garantía de cobertura sobre todos los dialectos SQL o construcciones JPA/Hibernate.
- Despliegue como servicio, portal web, API, webhooks o integración productiva con GitLab.
- Diccionarios finales en Excel, CSV o HTML, porque esos productos aún no están implementados.
- Aprobación funcional, de seguridad o de arquitectura por responsables institucionales.

# 5. DEFINICIONES, ABREVIATURAS Y ACRÓNIMOS

| Término | Definición |
|---|---|
| AST | Árbol de sintaxis abstracta utilizado para analizar Java con Tree-sitter. |
| JPA | API de persistencia Java basada en anotaciones como `@Entity` y `@Table`. |
| HBM XML | Formato XML de mapeo de Hibernate, normalmente `*.hbm.xml`. |
| DDL | Lenguaje de definición de datos; en este proyecto se analiza principalmente `CREATE TABLE`. |
| Entidad | Ocurrencia de una clase o mapeo persistente encontrada en un repositorio. |
| Tabla física | Vista consolidada identificada por la combinación normalizada de esquema y nombre de tabla. |
| Referencia SQL | Uso de una tabla detectado en SQL que no prueba por sí solo su estructura. |
| Evidencia | Archivo, rango de líneas, extractor, constructo y fragmento que respaldan un hallazgo. |
| E/R | Diagrama entidad-relación generado a partir de tablas y relaciones estructuradas. |

# 6. RESPONSABLES Y PARTES INTERESADAS

El repositorio no contiene una asignación verificable de responsables personales. Para este borrador se reconocen los siguientes roles funcionales:

- Equipo de desarrollo: mantiene extractores, modelo, consolidación, CLI y pruebas.
- Arquitectura de soluciones: revisa el modelo de salida, criterios de consolidación y uso documental.
- Equipos propietarios de aplicativos: validan que los hallazgos representen sus mapeos y esquemas reales.
- Administradores de datos: contrastan el inventario con el catálogo oficial de base de datos.

# 7. MARCO NORMATIVO Y DOCUMENTAL

No se identificó dentro del repositorio una norma institucional vinculante específica para este componente. Las fuentes técnicas verificadas para este corte son el código fuente, `README.md`, los documentos de `docs`, los scripts de `scripts`, las pruebas automatizadas y los fixtures. Los documentos de propuestas y pendientes se consideran referencia de planificación, no evidencia de funciones operativas.

# 8. DESARROLLO DEL DOCUMENTO

## 8.1 Estado técnico del corte

| Elemento | Valor observado |
|---|---|
| Versión declarada | 0.1.0 |
| Lenguaje | Python 3.9 o superior |
| Rama | `feat/consolidacion-tablas-sql` |
| Commit base | `4e60c5257c3dc3d5568c5262a8b060f3030ff8ac` |
| Archivos inventariados | 50 |
| Archivos Python del paquete | 11 módulos, aproximadamente 2.010 líneas |
| Dependencias directas | `tree-sitter` y `tree-sitter-java` |
| Pruebas ejecutadas | 29 aprobadas, 0 fallidas |
| Formato de salida | JSON `schema_version` 1.1 y Mermaid E/R |

El árbol de trabajo contiene modificaciones y archivos nuevos relacionados con consolidación y SQL. El inventario omitió `.env`, `.venv`, Git y artefactos generados. También registró una carpeta temporal de pruebas inaccesible; esta incidencia no impidió completar el inventario tolerante a errores.

## 8.2 Arquitectura actual

El flujo implementado es:

1. La CLI valida rutas y determina los repositorios raíz.
2. `Analyzer` recorre archivos y excluye directorios generados o no productivos.
3. Cada extractor decide si acepta el archivo y devuelve entidades o referencias.
4. El motor resuelve relaciones entre clases del mismo repositorio y, cuando existe un único destino, entre repositorios.
5. La consolidación agrupa evidencia estructurada por esquema y tabla.
6. El modelo se serializa como JSON 1.1.
7. El generador Mermaid consume las tablas consolidadas elegibles para producir el E/R.

| Módulo | Responsabilidad actual |
|---|---|
| `__main__.py` | Argumentos, selección de raíces y escritura de resultados por repositorio o consolidados. |
| `engine.py` | Recorrido, coordinación de extractores, advertencias y resolución de relaciones. |
| `java_jpa.py` | Extracción desde anotaciones y estructura Java mediante Tree-sitter. |
| `hibernate_xml.py` | Lectura de mapeos `*.hbm.xml`. |
| `sql.py` | Detección de DDL y referencias SQL estáticas. |
| `consolidation.py` | Construcción de la vista canónica de tablas, atributos y relaciones. |
| `model.py` | Dataclasses de entidades, atributos, relaciones, referencias y evidencia. |
| `mermaid.py` | Conversión del modelo consolidado a sintaxis `erDiagram`. |
| `utils.py` | Lectura tolerante de texto y utilidades de análisis. |
| `base.py` | Protocolo que deben cumplir los extractores. |

## 8.3 Entradas y mecanismos de persistencia

El analizador reconoce actualmente:

- Clases Java con JPA `javax.persistence` o `jakarta.persistence`.
- Anotaciones en campos y getters, incluyendo acceso por propiedad.
- Entidades, mapped superclasses y embeddables.
- Archivos Hibernate `*.hbm.xml`.
- `CREATE TABLE`, claves primarias y foráneas simples en archivos SQL.
- Referencias estáticas a tablas en SQL, XML, propiedades y consultas Java nativas o JDBC.

Las consultas JPQL no se consideran referencias a tablas físicas. El SQL construido dinámicamente se registra como advertencia porque el análisis estático no puede demostrar su tabla destino.

## 8.4 Modelo JSON 1.1

La salida conserva dos niveles de información:

- `entities[]`: ocurrencias originales por clase o definición, útiles como evidencia y trazabilidad.
- `tables[]`: vista física consolidada para diccionario y E/R.

También incluye `table_references[]` y un bloque `analysis` con repositorios, contadores, mecanismos, cobertura, consolidación y advertencias.

Cada atributo puede registrar nombre Java, columna, tipo Java, tipo de base, fuente del tipo, clave primaria o foránea, nulabilidad, unicidad, longitud, precisión, escala, generación, estado y evidencia. Los estados usados son `explicit`, `inferred` y `unresolved`.

## 8.5 Consolidación de tablas físicas

La identidad canónica se calcula con `schema + table_name`, normalizados en mayúsculas y sin delimitadores. Dos mapeos de distintos repositorios se consolidan únicamente cuando ambos aportan esa identidad completa. Esta regla evita fusionar tablas homónimas de esquemas diferentes.

Cuando falta el esquema, la tabla permanece separada con identidad no resuelta y se genera `table_schema_unresolved`. Las referencias SQL sin estructura pueden vincularse con una tabla conocida, pero si solo existe la referencia se clasifican como candidatas, sin columnas y sin participación en el E/R.

Los atributos se agrupan por nombre normalizado de columna. Ante valores alternativos se prioriza evidencia explícita sobre inferida; los demás valores observados y los conflictos se conservan para auditoría. La salida incluye medidas de completitud: número de columnas, mapeos, referencias, fuentes de relación, existencia de PK y relaciones resueltas.

Las tablas intermedias de relaciones muchos-a-muchos se materializan cuando `@JoinTable` o el HBM aportan información suficiente.

## 8.6 Resolución de relaciones

El motor intenta resolver primero por clase calificada y nombre simple dentro del repositorio. Si no hay destino local, busca un candidato único global. Cuando existen varios candidatos compatibles, mantiene la relación sin resolver y emite `relation_ambiguous`; cuando no existe ninguno, emite `relation_unresolved`.

Al resolver un destino, enlaza la entidad y tabla objetivo, obtiene la columna primaria cuando está disponible y puede propagar el tipo de la PK a la FK con fuente `relation-target`.

## 8.7 Interfaz de ejecución

Preparación del entorno:

```powershell
.\scripts\environment\setup-venv.ps1
```

Extracción consolidada recomendada:

```powershell
.\.venv\Scripts\python.exe -m persistence_extractor `
  C:\fuentes\repositorios `
  --consolidated `
  --output-dir C:\salidas\modelos `
  --pretty
```

Generación del E/R:

```powershell
.\.venv\Scripts\python.exe -m persistence_extractor.mermaid `
  C:\salidas\modelos\consolidated.json `
  --output C:\salidas\diagrama-er.mmd
```

La opción vigente es `--output-dir`; los ejemplos antiguos con `--output` están desalineados con la CLI actual y deben corregirse antes de considerarlos guía operativa.

## 8.8 Verificación ejecutada

La suite se ejecutó con:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Resultado: 29 pruebas aprobadas en aproximadamente 0,21 segundos. La cobertura funcional observada incluye JPA, Hibernate XML, encodings Latin-1, serialización, relaciones ambiguas o no resueltas, búsqueda entre repositorios, DDL SQL, referencias SQL, consolidación y Mermaid.

Como demostración se analizaron exclusivamente los fixtures. El resultado sintético fue:

| Métrica | Resultado |
|---|---:|
| Repositorios de fixtures | 4 |
| Archivos analizados | 18 |
| Entidades | 18 |
| Referencias de tabla | 4 |
| Tablas físicas | 20 |
| Tablas estructuradas | 19 |
| Tablas candidatas | 1 |
| Grupos de mapeos duplicados | 1 |
| Columnas consolidadas | 51 |
| Advertencias | 16 |

Estos valores sirven para verificar el software; no representan tablas ni aplicativos reales del IESS.

## 8.9 Artefactos producidos en esta documentación

- `inventario/inventario-proyecto.json`: inventario del corte.
- `modelos/consolidated.json`: demostración con fixtures.
- `diagrama-er-demostracion.mmd`: E/R demostrativo editable.
- `documentacion.md`: fuente revisable del documento.
- `documentacion-generador-diccionario.docx`: documento institucional generado.

# 9. RIESGOS, RESTRICCIONES Y DEPENDENCIAS

| Riesgo o restricción | Evidencia actual | Tratamiento recomendado |
|---|---|---|
| Cobertura parcial | El análisis estático no certifica el catálogo real de base de datos. | Contrastar posteriormente con catálogo o Excel oficial. |
| Esquema ausente | Las tablas sin esquema no se fusionan y generan advertencias. | Configurar o recuperar el esquema explícito desde cada fuente. |
| SQL dinámico | No puede resolverse con certeza. | Mantener advertencia y revisar manualmente. |
| Casos avanzados | Claves compuestas, herencia y variantes SQL no están cubiertas exhaustivamente. | Agregar fixtures y soporte incremental. |
| CLI con salida externa | En la demostración el JSON se escribió, pero la CLI terminó con `ValueError` al intentar mostrar una ruta fuera del proyecto mediante `relative_to`. | Imprimir una ruta absoluta o usar un cálculo relativo seguro. |
| Documentación desactualizada | Algunos documentos todavía describen JSON 1.0 y extractores anteriores. | Actualizarlos al integrar la rama de consolidación. |
| Scripts desalineados | El README y mensajes de ayuda conservan ejemplos con `--output`. | Unificar documentación y scripts alrededor de `--output-dir`. |
| Directorio temporal inaccesible | El inventario encontró `tests/tmpbvh2towq` sin permisos. | Excluir temporales de pruebas o asegurar su limpieza controlada. |

# 10. INDICADORES Y CRITERIOS DE CUMPLIMIENTO

| Indicador | Estado del corte | Criterio |
|---|---:|---|
| Pruebas automatizadas aprobadas | 29 de 29 | Todas las pruebas existentes deben finalizar sin errores. |
| Serialización versionada | 1.1 | La salida debe declarar versión y conservar evidencia original y consolidada. |
| Consolidación demostrada | Sí | Al menos un grupo duplicado debe converger en una tabla física. |
| Exclusión de candidatas del E/R | Sí | Las referencias sin estructura no deben dibujarse. |
| Trazabilidad | Implementada parcialmente | Los hallazgos deben conservar archivo y líneas; faltan hashes y evidencia más granular. |
| Cobertura institucional | No certificada | Requiere comparación con catálogo oficial, fuera del alcance actual. |

# 11. CONCLUSIONES

El proyecto dispone de una base funcional comprobada para extraer metadatos de persistencia desde JPA, Hibernate XML y SQL, resolver relaciones, consolidar mapeos por tabla física y generar JSON y Mermaid. La suite actual pasa completamente.

La funcionalidad de consolidación observada es más avanzada que parte de la documentación existente, pero aún está en un árbol de trabajo no confirmado. El producto debe tratarse como versión 0.1 en desarrollo. Su resultado es un inventario técnico respaldado por código, no una certificación del esquema institucional.

# 12. RECOMENDACIONES

- Corregir la impresión de rutas externas en la CLI para que una salida válida no termine con error.
- Unificar ejemplos y scripts alrededor de `--output-dir` y `--consolidated`.
- Actualizar los documentos que todavía describen `schema_version` 1.0.
- Formalizar JSON Schema para la salida 1.1.
- Ampliar pruebas de claves compuestas, namespaces, herencia, SQL dinámico y repositorios vacíos.
- Contrastar el modelo consolidado con el catálogo institucional antes de publicar un diccionario oficial.
- Etiquetar cada futura documentación con rama, commit, fecha y estado del árbol de trabajo.

# 13. REFERENCIAS

1. Repositorio local `generador_diccionario_entidades`, corte del 21/08/2026.
2. Código fuente del paquete `persistence_extractor`.
3. Suite `tests/test_extractors.py` y `tests/test_unit.py`.
4. `README.md` y documentación técnica bajo `docs`.
5. Inventario generado por `analizador-proyecto-iess`.

# 14. ANEXOS

## 14.1 Comandos de reproducción

Inventario documental:

```powershell
.\tools\analizador-proyecto-iess\analizar_proyecto_iess.ps1 `
  -ProjectPath "C:\Users\gamur\Documents\IESS PPP\Proyectos\generador_diccionario_entidades" `
  -OutputDirectory ".\tmp\documentacion-generador-diccionario\inventario" `
  -ProjectName "generador_diccionario_entidades"
```

Validación del Markdown:

```powershell
.\tools\analizador-proyecto-iess\validar_markdown_iess.ps1 `
  -InputMarkdown ".\tmp\documentacion-generador-diccionario\documentacion.md" `
  -Strict
```

## 14.2 Interpretación del E/R demostrativo

El archivo `diagrama-er-demostracion.mmd` contiene tablas y relaciones obtenidas de fixtures Java, Hibernate y SQL. Su función es demostrar que el generador consolida y dibuja el modelo; no debe incorporarse a un diccionario institucional como evidencia de producción.

