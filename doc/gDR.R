## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ---- echo=TRUE, results='asis'-----------------------------------------------
library(gDR)

# Define path for data stored in gDR package
dataDir <- system.file("extdata", "data1", package = "gDRimport")

# Extract path for example raw_data
manifest <- list.files(dataDir, pattern = "manifest", full.names = TRUE)
template <- list.files(dataDir, pattern = "Template", full.names = TRUE)
raw_data <- list.files(dataDir, pattern = "^RawData", full.names = TRUE)

manifest
template
raw_data

## ---- echo=TRUE, results='asis', warning=FALSE, results='hide', message=FALSE----
# Import data
imported_data <- import_data(manifest, template, raw_data)
head(imported_data)

## -----------------------------------------------------------------------------
se <- create_and_normalize_SE(imported_data)
se

## ---- echo=TRUE, results='asis', warning=FALSE, results='hide', message=FALSE----
se <- average_SE(se)
se <- fit_SE(se)

## ---- echo=TRUE---------------------------------------------------------------
se

## ---- echo=TRUE, results='asis', warning=FALSE, results='hide', message=FALSE----
# Run gDR pipeline
pipeline_se <- runDrugResponseProcessingPipeline(imported_data)

## ---- echo=TRUE---------------------------------------------------------------
pipeline_se

## ---- echo=TRUE---------------------------------------------------------------
SummarizedExperiment::assayNames(se)

## ---- echo=TRUE, eval=FALSE---------------------------------------------------
#  convert_se_assay_to_dt(se, "Metrics")

## ---- echo=FALSE--------------------------------------------------------------
remotes::install_cran("kableExtra")
library(kableExtra)
kbl(convert_se_assay_to_dt(se, "Metrics")) |>
  kable_paper() |>
  scroll_box(width = "700px", height = "300px")

