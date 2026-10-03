INCUCYTE_TEMPLATES <- c("1-data_import.Rmd", "2-processing_and_QC.Rmd", "3-analysis.Rmd")

.incucyte_template_lines <- function(file) {
  path <- system.file(file.path("report_templates", "incucyte", file), package = "gDR")
  testthat::skip_if(path == "", paste("template not installed:", file))
  readLines(path, warn = FALSE)
}

test_that("the experiment lookup and the fit profile lookup are not interchangeable", {
  # Both are keyed on the string "time-course" and a review suggested swapping one for the
  # other. They resolve different things: the experiment name against SUPPORTED_EXPERIMENTS,
  # the input assay against the fit profile registry.
  experiment <- gDRutils::get_supported_experiments("time-course")
  input_assay <- gDRutils::get_fit_profile("time-course")$input_assay

  expect_false(identical(experiment, input_assay))
  expect_identical(experiment, "time-course")
  expect_true(checkmate::test_string(input_assay, min.chars = 1L))
})

test_that("the analysis template reads its assay from the fit profile", {
  lines <- .incucyte_template_lines("3-analysis.Rmd")

  assay_line <- grep("lfc_assay\\s*<-", lines, value = TRUE)
  expect_length(assay_line, 1L)
  expect_match(assay_line, "get_fit_profile\\(")
  # Swapping in the experiment lookup would ask convert_se_assay_to_dt() for an assay named
  # after the experiment, which no SE carries.
  expect_no_match(assay_line, "get_supported_experiments")
})

test_that("the Incucyte templates say which step numbering they mean", {
  # These templates carry two numberings - the report's own parts and the Incucyte pipeline
  # steps - and used a bare "Step N" for both, which a review flagged three times.
  for (file in INCUCYTE_TEMPLATES) {
    lines <- .incucyte_template_lines(file)
    bare <- grep("(?<!report )(?<!Report )\\bStep [0-9]", lines, value = TRUE, perl = TRUE)
    expect_length(bare, 0L)
  }
})
