#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# generar_referencia_estilo.R
#
# Toma el referencia_estilo_iess.docx base e inyecta la cabecera
# institucional IESS con la tipografía y proporciones exactas de la
# plantilla oficial (4 filas laterales con borde, tamaños jerárquicos de texto,
# logo IESS y campos de paginación automáticos).
#
# Uso:
#   Rscript tools/generar_referencia_estilo.R
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

script_dir <- tryCatch(
  dirname(normalizePath(sub("--file=", "", commandArgs(trailingOnly = FALSE)[
    grep("--file=", commandArgs(trailingOnly = FALSE))
  ]))),
  error = function(e) getwd()
)

repo_root  <- dirname(script_dir)
logo_path  <- file.path(repo_root, "assets", "LOGO_IESS.png")
output     <- file.path(repo_root, "referencia_estilo_iess.docx")

input_docx <- NULL
candidates <- c(
  file.path(repo_root, "DocumentaciónIESS", "referencia_estilo_iess.docx"),
  output
)
for (c in candidates) {
  if (file.exists(c)) { input_docx <- c; break }
}

if (is.null(input_docx) || !file.exists(input_docx)) {
  stop("No se encontró referencia_estilo_iess.docx base.")
}
if (!file.exists(logo_path)) stop("No se encuentra el logo: ", logo_path)

cat("Archivo base:  ", input_docx, "\n")
cat("Logo:          ", logo_path, "\n")
cat("Salida:        ", output, "\n")

work_dir <- file.path(tempdir(), paste0("iess-ref-", format(Sys.time(), "%Y%m%d%H%M%S")))
dir.create(work_dir, showWarnings = FALSE, recursive = TRUE)
utils::unzip(input_docx, exdir = work_dir)

# Copiar logo a media
media_dir <- file.path(work_dir, "word", "media")
dir.create(media_dir, showWarnings = FALSE, recursive = TRUE)
file.copy(logo_path, file.path(media_dir, "logo_iess.png"), overwrite = TRUE)

# -----------------------------------------------------------------------
# Cabecera institucional con 4 filas laterales y tamaños de letra jerárquicos
# -----------------------------------------------------------------------
header_default <- '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:w10="urn:schemas-microsoft-com:office:word"
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
 xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
 xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
 xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
 xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
 mc:Ignorable="w14 wp14">

<w:tbl>
<w:tblPr>
  <w:tblW w:w="5000" w:type="pct"/>
  <w:tblBorders>
    <w:top w:val="single" w:sz="12" w:space="0" w:color="000000"/>
    <w:left w:val="single" w:sz="12" w:space="0" w:color="000000"/>
    <w:bottom w:val="single" w:sz="12" w:space="0" w:color="000000"/>
    <w:right w:val="single" w:sz="12" w:space="0" w:color="000000"/>
    <w:insideH w:val="single" w:sz="6" w:space="0" w:color="000000"/>
    <w:insideV w:val="single" w:sz="6" w:space="0" w:color="000000"/>
  </w:tblBorders>
  <w:tblLayout w:type="fixed"/>
  <w:tblCellMar>
    <w:top w:w="40" w:type="dxa"/>
    <w:left w:w="80" w:type="dxa"/>
    <w:bottom w:w="40" w:type="dxa"/>
    <w:right w:w="80" w:type="dxa"/>
  </w:tblCellMar>
</w:tblPr>
<w:tblGrid>
  <w:gridCol w:w="1600"/>
  <w:gridCol w:w="6150"/>
  <w:gridCol w:w="2250"/>
</w:tblGrid>

<!-- ==================== FILA 1: COD ==================== -->
<w:tr>
  <w:trPr><w:trHeight w:val="280" w:hRule="atLeast"/></w:trPr>

  <!-- Logo IESS (Inicio merge 4 filas) -->
  <w:tc>
    <w:tcPr>
      <w:tcW w:w="1600" w:type="dxa"/>
      <w:vMerge w:val="restart"/>
      <w:vAlign w:val="center"/>
    </w:tcPr>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:noProof/></w:rPr>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0">
            <wp:extent cx="1050000" cy="700000"/>
            <wp:docPr id="1" name="Logo IESS"/>
            <a:graphic>
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic>
                  <pic:nvPicPr>
                    <pic:cNvPr id="1" name="logo_iess.png"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="rId999"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm><a:off x="0" y="0"/><a:ext cx="1050000" cy="700000"/></a:xfrm>
                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>
  </w:tc>

  <!-- Centro: Institución / Dirección / Subdirección (Inicio merge filas 1 y 2) -->
  <w:tc>
    <w:tcPr>
      <w:tcW w:w="6150" w:type="dxa"/>
      <w:vMerge w:val="restart"/>
      <w:vAlign w:val="center"/>
    </w:tcPr>
    <!-- 1. INSTITUTO ECUATORIANO DE SEGURIDAD SOCIAL: 11pt, Bold -->
    <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
        <w:t>INSTITUTO ECUATORIANO DE SEGURIDAD SOCIAL</w:t>
      </w:r>
    </w:p>
    <!-- 2. DIRECCIÓN NACIONAL DE TECNOLOGÍAS DE LA INFORMACIÓN: 13pt (más grande), Bold -->
    <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="260" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr>
        <w:t>{{DIRECTION}}</w:t>
      </w:r>
    </w:p>
    <!-- 3. SUBDIRECCIÓN NACIONAL DE ARQUITECTURA Y SOLUCIONES: 11.5pt, Bold -->
    <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="23"/><w:szCs w:val="23"/></w:rPr>
        <w:t>{{SUBDIRECTION}}</w:t>
      </w:r>
    </w:p>
  </w:tc>

  <!-- Derecha Fila 1: COD -->
  <w:tc>
    <w:tcPr><w:tcW w:w="2250" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t xml:space="preserve">COD: </w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t>{{FORM_CODE}}</w:t>
      </w:r>
    </w:p>
  </w:tc>
</w:tr>

<!-- ==================== FILA 2: FECHA ==================== -->
<w:tr>
  <w:trPr><w:trHeight w:val="280" w:hRule="atLeast"/></w:trPr>

  <!-- Logo (merge cont) -->
  <w:tc>
    <w:tcPr><w:tcW w:w="1600" w:type="dxa"/><w:vMerge/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
  </w:tc>

  <!-- Centro (merge cont de filas 1 y 2) -->
  <w:tc>
    <w:tcPr><w:tcW w:w="6150" w:type="dxa"/><w:vMerge/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
  </w:tc>

  <!-- Derecha Fila 2: FECHA -->
  <w:tc>
    <w:tcPr><w:tcW w:w="2250" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t xml:space="preserve">FECHA: </w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t>{{DATE}}</w:t>
      </w:r>
    </w:p>
  </w:tc>
</w:tr>

<!-- ==================== FILA 3: VERSIÓN ==================== -->
<w:tr>
  <w:trPr><w:trHeight w:val="320" w:hRule="atLeast"/></w:trPr>

  <!-- Logo (merge cont) -->
  <w:tc>
    <w:tcPr><w:tcW w:w="1600" w:type="dxa"/><w:vMerge/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
  </w:tc>

  <!-- Centro: Tipo de documento (ESTÁNDAR): 14pt, Bold, Centrado (Inicio merge filas 3 y 4) -->
  <w:tc>
    <w:tcPr>
      <w:tcW w:w="6150" w:type="dxa"/>
      <w:vMerge w:val="restart"/>
      <w:vAlign w:val="center"/>
    </w:tcPr>
    <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="260" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
        <w:t>{{DOC_TYPE}}</w:t>
      </w:r>
    </w:p>
  </w:tc>

  <!-- Derecha Fila 3: VERSIÓN -->
  <w:tc>
    <w:tcPr><w:tcW w:w="2250" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t xml:space="preserve">VERSIÓN: </w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t>{{VERSION}}</w:t>
      </w:r>
    </w:p>
  </w:tc>
</w:tr>

<!-- ==================== FILA 4: PÁG ==================== -->
<w:tr>
  <w:trPr><w:trHeight w:val="320" w:hRule="atLeast"/></w:trPr>

  <!-- Logo (merge cont final) -->
  <w:tc>
    <w:tcPr><w:tcW w:w="1600" w:type="dxa"/><w:vMerge/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
  </w:tc>

  <!-- Centro (merge cont de filas 3 y 4) -->
  <w:tc>
    <w:tcPr><w:tcW w:w="6150" w:type="dxa"/><w:vMerge/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
  </w:tc>

  <!-- Derecha Fila 4: PÁG. PAGE / NUMPAGES -->
  <w:tc>
    <w:tcPr><w:tcW w:w="2250" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
    <w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t xml:space="preserve">PÁG.: </w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="begin"/>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:instrText xml:space="preserve"> PAGE </w:instrText>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="separate"/>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t>1</w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="end"/>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t xml:space="preserve">/ </w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="begin"/>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:instrText xml:space="preserve"> NUMPAGES </w:instrText>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="separate"/>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:t>1</w:t>
      </w:r>
      <w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
        <w:fldChar w:fldCharType="end"/>
      </w:r>
    </w:p>
  </w:tc>
</w:tr>

</w:tbl>

<w:p><w:pPr><w:pStyle w:val="Header"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>
</w:hdr>'

header_first_page <- '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:p><w:pPr><w:pStyle w:val="Header"/></w:pPr></w:p>
</w:hdr>'

writeLines(header_default, file.path(work_dir, "word", "header1.xml"), useBytes = TRUE)
writeLines(header_first_page, file.path(work_dir, "word", "header2.xml"), useBytes = TRUE)

# Actualizar [Content_Types].xml
ct_path <- file.path(work_dir, "[Content_Types].xml")
ct <- readLines(ct_path, warn = FALSE, encoding = "UTF-8")
ct <- paste(ct, collapse = "\n")

if (!grepl("header1.xml", ct, fixed = TRUE)) {
  ct <- sub(
    "</Types>",
    paste0(
      '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>',
      '<Override PartName="/word/header2.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>',
      '</Types>'
    ),
    ct, fixed = TRUE
  )
}
if (!grepl('Extension="png"', ct, fixed = TRUE)) {
  ct <- sub(
    "</Types>",
    '<Default Extension="png" ContentType="image/png"/></Types>',
    ct, fixed = TRUE
  )
}
writeLines(ct, ct_path, useBytes = TRUE)

# Actualizar word/_rels/document.xml.rels
rels_path <- file.path(work_dir, "word", "_rels", "document.xml.rels")
rels <- readLines(rels_path, warn = FALSE, encoding = "UTF-8")
rels <- paste(rels, collapse = "\n")

existing_ids <- regmatches(rels, gregexpr("rId[0-9]+", rels))[[1]]
max_id <- max(as.integer(sub("rId", "", existing_ids)), na.rm = TRUE)
rid_h1 <- paste0("rId", max_id + 1)
rid_h2 <- paste0("rId", max_id + 2)

if (!grepl("header1.xml", rels, fixed = TRUE)) {
  rels <- sub(
    "</Relationships>",
    paste0(
      '<Relationship Id="', rid_h1, '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>',
      '<Relationship Id="', rid_h2, '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header2.xml"/>',
      '</Relationships>'
    ),
    rels, fixed = TRUE
  )
}
writeLines(rels, rels_path, useBytes = TRUE)

# Crear word/_rels/header1.xml.rels
header_rels <- '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId999" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo_iess.png"/>
</Relationships>'
writeLines(header_rels, file.path(work_dir, "word", "_rels", "header1.xml.rels"), useBytes = TRUE)

# Actualizar document.xml con headerReference
doc_path <- file.path(work_dir, "word", "document.xml")
doc_xml <- readLines(doc_path, warn = FALSE, encoding = "UTF-8")
doc_xml <- paste(doc_xml, collapse = "\n")

header_refs <- paste0(
  '<w:headerReference w:type="default" r:id="', rid_h1, '"/>',
  '<w:headerReference w:type="first" r:id="', rid_h2, '"/>',
  '<w:titlePg/>'
)

if (grepl("</w:sectPr>", doc_xml, fixed = TRUE) &&
    !grepl("w:headerReference", doc_xml, fixed = TRUE)) {
  doc_xml <- sub("</w:sectPr>", paste0(header_refs, "</w:sectPr>"), doc_xml, fixed = TRUE)
}
writeLines(doc_xml, doc_path, useBytes = TRUE)

# Reempaquetar
if (file.exists(output)) file.remove(output)

all_files <- list.files(work_dir, recursive = TRUE, full.names = TRUE)
rel_files <- sub(
  paste0(normalizePath(work_dir, winslash = "/"), "/"), "",
  normalizePath(all_files, winslash = "/")
)

old_wd <- getwd()
setwd(work_dir)
utils::zip(output, files = rel_files, flags = "-r9Xq")
setwd(old_wd)

unlink(work_dir, recursive = TRUE)

cat("referencia_estilo_iess.docx generado con jerarquía tipográfica exacta en:\n", output, "\n")
