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

test_that("the import and processing templates only read what run_report() wrote", {
  # The data of steps 1 and 2 is run by run_report() (run_report_data_step()), so a run that
  # does not render writes the same files; the templates must not import or process again.
  code1 <- .template_code("1-data_import.Rmd")
  code2 <- .template_code("2-processing_and_QC.Rmd")

  for (call in c("load_long_table(", "import_data(", "convert_LEVEL5_prism_to_gDR_input(",
                 "convert_LEVEL6_prism_to_gDR_input(", "load_data(", "merge_data(")) {
    expect_length(grep(call, code1, fixed = TRUE), 0L)
  }
  expect_true(any(grepl('qs_read(file.path(wd, "gDR_data", "gDR_input.qs2"))', code1, fixed = TRUE)))

  expect_length(grep("runDrugResponseProcessingPipeline(", code2, fixed = TRUE), 0L)
  expect_length(grep("qs_save(", code2, fixed = TRUE), 0L)
  for (stage in c("create_SE", "normalize_SE", "average_SE", "fit_SE", "fit_SE.combinations")) {
    expect_length(grep(paste0("(^|[^_.[:alnum:]])", stage, "\\("), code2), 0L)
  }
  for (step in c("create_SE", "normalize_SE", "average_SE", "fit_SE")) {
    expect_true(any(grepl(sprintf('read_step("%s"', step), code2, fixed = TRUE)), info = step)
  }
})

test_that("the processing template says which processed types get no quality control", {
  code <- .template_code("2-processing_and_QC.Rmd")
  expect_true(any(grepl("!dt_$type %in% report_types", code, fixed = TRUE)))
  expect_true(any(grepl("Processed, no quality control here", code, fixed = TRUE)))
  expect_false(any(grepl("dt_report <- ", code, fixed = TRUE)))
})

test_that("run_report_data_step records the report inputs a caller passes", {
  mae_in <- gDRutils::get_synthetic_data("finalMAE_combo_2dose_nonoise.qs2")
  out <- tempfile("gdr_report_")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  dir.create(file.path(out, "gDR_data"))
  qs2::qs_save(data.table::data.table(x = 1), file.path(out, "gDR_data", "gDR_input.qs2"))
  inputs_file <- file.path(out, "inputs.qs2")
  qs2::qs_save(list(source_id = "AS-1", files = data.frame(path = "manifest.xlsx", md5 = "abc")), inputs_file)

  run_step <- function(extra) {
    testthat::local_mocked_bindings(
      runDrugResponseProcessingPipeline = function(x, data_dir) mae_in, .package = "gDRcore"
    )
    run_report_data_step(list(data_type = "bench", extra_render_params = extra),
                         "2-processing_and_QC.Rmd", out)
    qs2::qs_read(file.path(out, "gDR_data", "gDR_mae.qs2"))
  }

  mae <- run_step(list(report_inputs_file = inputs_file))
  for (experiment in names(mae)) {
    step <- gDRutils::get_SE_provenance(mae[[experiment]])$steps$report
    expect_equal(step$settings$source_id, "AS-1", info = experiment)
    expect_equal(step$settings$files$md5, "abc", info = experiment)
  }
  # without the parameter nothing is recorded
  expect_null(gDRutils::get_SE_provenance(run_step(list())[[1]])$steps$report)
})

test_that("run_report_data_step refuses qcs input without rendering", {
  expect_error(run_report_data_step(list(data_type = "qcs"), "1-data_import.Rmd", tempdir(), render = FALSE),
               "step 1 must be in render_steps")
  expect_null(run_report_data_step(list(data_type = "qcs"), "1-data_import.Rmd", tempdir(), render = TRUE))
})

test_that("run_report writes the data of steps 1 and 2 and only the pages in render_steps", {
  td <- gDRimport::get_test_data()
  out <- tempfile("gdr_report_")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  suppressWarnings(suppressMessages(run_report(
    manifest = gDRimport::manifest_path(td),
    treatment = paste(gDRimport::template_path(td), collapse = ","),
    raw_data = paste(gDRimport::result_path(td), collapse = ","),
    output_dir = out, steps = 1:2, render_steps = integer(0)
  )))
  run <- file.path(out, "current")
  input <- qs2::qs_read(file.path(run, "gDR_data", "gDR_input.qs2"))
  mae <- qs2::qs_read(file.path(run, "gDR_data", "gDR_mae.qs2"))
  expect_false(is.null(attr(input, "gDR_import")))
  expect_identical(names(mae)[1], gDRutils::get_supported_experiments("sa"))
  expect_length(list.files(run, pattern = "[.]html$"), 0L)
  expect_true(file.exists(file.path(run, "data_annotation", "drug_annotation.csv")))
  expect_error(run_report(manifest = gDRimport::manifest_path(td), output_dir = out, steps = 1:3,
                          render_steps = 1:2), "Only steps 1 and 2 can run without rendering")
  expect_error(run_report(manifest = gDRimport::manifest_path(td), output_dir = out, steps = 1:2,
                          render_steps = 3), "render_steps must be among steps")
})
