test_that("is_null_or_empty function works correctly", {
  expect_true(is_null_or_empty(NULL))
  expect_true(is_null_or_empty(""))
  expect_true(is_null_or_empty(c("", "test")))
  expect_false(is_null_or_empty("test"))
  expect_false(is_null_or_empty(1:5))
})

test_that("run_gDRpipeline_with_report function handles input correctly", {
  expect_error(run_gDRpipeline_with_report(output_dir = "~/test_report",
                                           manifest = "path/to/manifest",
                                           treatment = "path/to/treatment"),
               "Provide either qcs_id or manifest, treatment, and raw_data, or prism_data_path.")
  expect_error(run_gDRpipeline_with_report(output_dir = "~/test_report",
                                           manifest = "path/to/manifest",
                                           treatment = "path/to/treatment",
                                           raw_data = "path/to_raw_data"),
               "'manifest_file' must be a readable path")
})
