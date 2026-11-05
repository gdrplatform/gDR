test_that("resolve_analysis_params keeps everything for the selections left out", {
  res <- resolve_analysis_params(list())
  expect_equal(res$sa_metrics, c("xc50", "x_max", "x_mean", "x_AOC", "x_AOC_range"))
  expect_equal(res$combo_score_metrics, c("hsa_score", "bliss_score"))
  expect_equal(res$iso_levels, "0.5")
})

test_that("resolve_analysis_params puts a selection in the order the report draws it", {
  res <- resolve_analysis_params(list(sa_metrics = c("x_AOC", "xc50", "xc50"), iso_levels = c(0.75, 0.5)))
  expect_equal(res$sa_metrics, c("xc50", "x_AOC"))
  expect_equal(res$iso_levels, c("0.75", "0.5"))
})

test_that("resolve_analysis_params rejects unknown or empty selections", {
  expect_error(resolve_analysis_params(list(sa_metrics = "ic50")), "sa_metrics")
  expect_error(resolve_analysis_params(list(combo_score_metrics = character(0))), "combo_score_metrics")
  expect_error(resolve_analysis_params(list(iso_levels = "half")), "iso_levels")
  expect_error(resolve_analysis_params(list(iso_levels = 1.5)), "iso_levels")
})

test_that("the analysis selections reach the templates without a shadowing warning", {
  out <- withr::local_tempdir()
  template_dir <- withr::local_tempdir()
  writeLines("sa <- c({{{sa_metrics}}}); combo <- c({{{combo_score_metrics}}}); iso <- c({{{iso_levels}}})",
             file.path(template_dir, "1-data_import.Rmd"))
  file.create(file.path(template_dir, "gdr_logo-01.png"))
  long_table <- withr::local_tempfile(fileext = ".csv")
  writeLines("Gnumber,clid,Duration,Concentration,ReadoutValue", long_table)

  expect_no_warning(
    rmd <- build_report_rmd(
      long_table = long_table,
      output_dir = out,
      rmd_template_path = template_dir,
      steps = 1,
      extra_render_params = list(sa_metrics = "x_mean", iso_levels = 0.25)
    )
  )
  expect_equal(
    readLines(rmd[["1-data_import"]]),
    c('sa <- c("x_mean"); combo <- c("hsa_score",', '  "bliss_score"); iso <- c("0.25")')
  )
})
