.template_code <- function(file) {
  path <- system.file(file.path("report_templates", file), package = "gDR")
  testthat::skip_if(path == "", paste("template not installed:", file))
  lines <- readLines(path, warn = FALSE)
  # an R chunk opens on ```{r and closes on the next bare fence; other chunks (css) are skipped
  fence <- grepl("^```", lines)
  chunk <- cumsum(fence)
  r_chunks <- chunk[fence & grepl("^```\\{r", lines)]
  code <- lines[chunk %in% r_chunks & !fence]
  code[!grepl("^\\s*#", code)]
}

test_that("the processing template leaves the orchestration to the pipeline", {
  # The template used to call the four stages itself, so its results matched the pipeline
  # only while both happened to use the same defaults.
  code <- .template_code("2-processing_and_QC.Rmd")

  expect_length(grep("runDrugResponseProcessingPipeline(", code, fixed = TRUE), 1L)
  for (stage in c("create_SE", "normalize_SE", "average_SE", "fit_SE", "fit_SE.combinations")) {
    expect_length(grep(paste0("(^|[^_.[:alnum:]])", stage, "\\("), code), 0L)
  }
  for (step in c("create_SE", "normalize_SE", "average_SE", "fit_SE")) {
    expect_true(any(grepl(sprintf('read_step("%s"', step), code, fixed = TRUE)), info = step)
  }
})

test_that("the processing template keeps the import record when it narrows the input", {
  # Subsetting a data.table drops its attributes, and with them the import step of the provenance.
  code <- .template_code("2-processing_and_QC.Rmd")

  expect_true(any(grepl('setattr(dt_report, "gDR_import"', code, fixed = TRUE)))
})
