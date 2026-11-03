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

test_that("the processing template records the report inputs a caller passes", {
  path <- system.file("report_templates", "2-processing_and_QC.Rmd", package = "gDR")
  testthat::skip_if(path == "", "template not installed")
  lines <- readLines(path, warn = FALSE)
  start <- grep("^report_inputs_file <- ", lines)
  end <- start - 1L + which(grepl("^\\}", lines[start:length(lines)]))[1]
  block <- paste(lines[start:end], collapse = "\n")

  run_block <- function(params) {
    env <- new.env()
    env$mae <- gDRutils::get_synthetic_data("finalMAE_combo_2dose_nonoise.qs2")
    env$qs_read <- qs2::qs_read
    env$record_processing_step <- gDRutils::record_processing_step
    eval(parse(text = whisker::whisker.render(block, params)), envir = env)
    env$mae
  }

  inputs_file <- tempfile(fileext = ".qs2")
  on.exit(unlink(inputs_file))
  qs2::qs_save(list(source_id = "AS-1", files = data.frame(path = "manifest.xlsx", md5 = "abc")), inputs_file)

  mae <- run_block(list(report_inputs_file = inputs_file))
  for (experiment in names(mae)) {
    step <- gDRutils::get_SE_provenance(mae[[experiment]])$steps$report
    expect_equal(step$settings$source_id, "AS-1", info = experiment)
    expect_equal(step$settings$files$md5, "abc", info = experiment)
  }

  # without the parameter the template records nothing
  untouched <- run_block(list())
  expect_null(gDRutils::get_SE_provenance(untouched[[1]])$steps$report)
})

test_that("the processing template says which data types it leaves out", {
  # co-dilution and time-course rows used to be dropped before the pipeline without a word
  code <- .template_code("2-processing_and_QC.Rmd")

  defined <- grep("report_types <- ", code, fixed = TRUE)
  left_out <- grep("!dt_$type %in% report_types", code, fixed = TRUE)
  narrowed <- grep("dt_report <- dt_[dt_$type %in% report_types]", code, fixed = TRUE)
  expect_length(defined, 1L)
  expect_length(left_out, 1L)
  expect_true(defined < left_out && left_out < narrowed)
  expect_true(any(grepl("Not in this report", code, fixed = TRUE)))
})
