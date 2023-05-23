context("utils")

test_that("import_data", {
  
  # Define path for data stored in gDR package
  dataDir <- system.file("extdata", "data1", package = "gDRimport")
  
  # Extract path for example raw_data
  manifest <- list.files(dataDir, pattern = "manifest", full.names = TRUE)
  template <- list.files(dataDir, pattern = "Template", full.names = TRUE)
  raw_data <- list.files(dataDir, pattern = "^RawData", full.names = TRUE)
  suppressWarnings(
    checkmate::expect_data_table(import_data(manifest, template, raw_data))
  )
})
