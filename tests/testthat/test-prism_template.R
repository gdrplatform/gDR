test_that("the PRISM template plots GR values when plot_GR is on", {
  # ifelse() returns a result as long as its test, so a single TRUE gave only "RV"
  path <- system.file("report_templates", "3-1-PRISM_analysis.Rmd", package = "gDR")
  testthat::skip_if(path == "", "template not installed")
  lines <- readLines(path, warn = FALSE)
  code <- grep("^normalization_type_vec <- ", lines, value = TRUE)
  expect_length(code, 2L)

  norm_types <- function(plot_GR) {
    env <- new.env()
    eval(parse(text = whisker::whisker.render(code[1], list(plot_GR = plot_GR))), envir = env)
    env$normalization_type_vec
  }
  expect_equal(norm_types(TRUE), c("RV", "GR"))
  expect_equal(norm_types(FALSE), "RV")
  expect_identical(code[1], code[2])
})
