test_that("resolve_analysis_params keeps everything for the selections left out", {
  res <- resolve_analysis_params(list())
  expect_equal(res$sa_metrics, c("xc50", "x_max", "x_mean", "x_AOC", "x_AOC_range"))
  expect_equal(res$combo_score_metrics, c("hsa_score", "bliss_score"))
  expect_equal(res$iso_levels, "0.5")
  expect_equal(res$table_format, "xlsx")
})

test_that("resolve_analysis_params puts a selection in the order the report draws it", {
  res <- resolve_analysis_params(list(sa_metrics = c("x_AOC", "xc50", "xc50"), iso_levels = c(0.75, 0.5),
                                      table_format = c("csv", "xlsx")))
  expect_equal(res$sa_metrics, c("xc50", "x_AOC"))
  expect_equal(res$iso_levels, c("0.75", "0.5"))
  expect_equal(res$table_format, c("xlsx", "csv"))
})

test_that("resolve_analysis_params rejects unknown or empty selections", {
  expect_error(resolve_analysis_params(list(sa_metrics = "ic50")), "sa_metrics")
  expect_error(resolve_analysis_params(list(combo_score_metrics = character(0))), "combo_score_metrics")
  expect_error(resolve_analysis_params(list(iso_levels = "half")), "iso_levels")
  expect_error(resolve_analysis_params(list(iso_levels = 1.5)), "iso_levels")
  expect_error(resolve_analysis_params(list(iso_levels = 0.95)), "iso_levels")
  expect_error(resolve_analysis_params(list(iso_levels = -1.5)), "iso_levels")
  expect_error(resolve_analysis_params(list(table_format = "tsv")), "table_format")
  expect_error(resolve_analysis_params(list(table_format = character(0))), "table_format")
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

test_that("resolve_analysis_params lets the report leave out GR but not RV", {
  expect_equal(resolve_analysis_params(list(norm_types = "RV"))$norm_types, "RV")
  expect_error(resolve_analysis_params(list(norm_types = "GR")), "must include \"RV\"")
})

test_that("analysis_section_flags shows the selected sections and GR only with GR data", {
  all_on <- analysis_section_flags(resolve_analysis_params(list(table_format = c("xlsx", "csv"))),
                                   plot_GR_values = TRUE)
  expect_true(all(unlist(all_on)))
  defaults <- analysis_section_flags(resolve_analysis_params(list()), plot_GR_values = TRUE)
  expect_true(defaults$table_xlsx)
  expect_false(defaults$table_csv)
  expect_false(analysis_section_flags(resolve_analysis_params(list()), plot_GR_values = NULL)$plot_GR)

  flags <- analysis_section_flags(
    resolve_analysis_params(list(plots_to_generate = "combo_boxplot_cl", norm_types = "RV")),
    plot_GR_values = TRUE
  )
  expect_true(flags$show_combo_boxplot_cl)
  expect_true(flags$show_combo_fitted_metrics)
  expect_false(flags$show_sa_fitted_metrics)
  expect_false(flags$show_sa_heatmap)
  expect_false(flags$plot_GR)
})

test_that("each section flag of the analysis template removes its own section", {
  template <- readLines(system.file("report_templates", "3-analysis.Rmd", package = "gDR"))
  tags <- unique(gsub("\\{\\{\\{?[#^/]?|\\}?\\}\\}", "",
                      unlist(regmatches(template, gregexpr("\\{\\{\\{?[#^/]?[A-Za-z_]+\\}?\\}\\}", template)))))
  all_on <- as.list(stats::setNames(rep(TRUE, length(tags)), tags))
  full <- whisker::whisker.render(template, all_on)

  # each section is told apart by its first chunk; SA and combination sections share headings
  section_flags <- paste0("show_", .ANALYSIS_CHOICES$plots_to_generate)
  first_chunks <- vapply(section_flags, function(flag) {
    start <- grep(sprintf("{{#%s}}", flag), template, fixed = TRUE)[1]
    sub(",.*", "", grep("^```\\{r ", template[start:length(template)], value = TRUE)[1])
  }, character(1))
  expect_false(anyDuplicated(first_chunks) > 0)
  has_section <- function(rmd) vapply(first_chunks, function(h) grepl(h, rmd, fixed = TRUE), logical(1))
  expect_true(all(has_section(full)))
  for (flag in section_flags) {
    off <- all_on
    off[[flag]] <- FALSE
    # the flag removes its own section and no other
    expect_equal(unname(has_section(whisker::whisker.render(template, off))), section_flags != flag, info = flag)
  }
  # every section and table flag the code computes is used by the template, and the other way round
  shows <- grep("^(show|table)_", tags, value = TRUE)
  expect_setequal(shows, grep("^(show|table)_", names(analysis_section_flags(resolve_analysis_params(list()), TRUE)),
                              value = TRUE))

  # the text about the tables follows the formats written
  expect_true(grepl("The same tables are written as CSV files", full, fixed = TRUE))
  expect_true(grepl("__matrix.csv", full, fixed = TRUE))
  csv_only <- all_on
  csv_only$table_xlsx <- FALSE
  rmd <- whisker::whisker.render(template, csv_only)
  expect_false(grepl("```{r save_xlsx}", rmd, fixed = TRUE))
  expect_true(grepl("```{r save_csv}", rmd, fixed = TRUE))
  expect_true(grepl("one CSV file per experiment type and assay", rmd, fixed = TRUE))
  expect_false(grepl("one Excel file per experiment type", rmd, fixed = TRUE))
  expect_false(grepl("The same tables are written as CSV files", rmd, fixed = TRUE))
  all_on$table_csv <- FALSE
  xlsx_only <- whisker::whisker.render(template, all_on)
  expect_false(grepl("save_csv", xlsx_only, fixed = TRUE))
  expect_false(grepl("__matrix.csv", xlsx_only, fixed = TRUE))
})

test_that("resolve_analysis_params writes iso_levels as the isobolograms store them", {
  expect_equal(resolve_analysis_params(list(iso_levels = c("0.50", -0.25, 0.5)))$iso_levels, c("0.5", "-0.25"))
})

test_that("warn_missing_iso_levels names the levels the isobolograms of the data do not have", {
  mae <- gDRutils::get_synthetic_data("finalMAE_combo_matrix_small.qs2")
  # the GR levels of this data go down to -0.25, the RV ones start at 0.2
  expect_warning(
    warn_missing_iso_levels(mae, resolve_analysis_params(list(iso_levels = c("0.5", "-0.25")))),
    "no isoline is drawn for them: -0.25 for RV\\.$"
  )
  expect_no_warning(warn_missing_iso_levels(mae, resolve_analysis_params(list(iso_levels = c(0.2, 0.8)))))
  sa_only <- suppressWarnings(mae[, , "single-agent"])
  expect_no_warning(warn_missing_iso_levels(sa_only, resolve_analysis_params(list(iso_levels = 0.1))))
})

test_that("build_report_rmd warns about requested isobologram levels only when an isoline section is drawn", {
  out <- withr::local_tempdir()
  template_dir <- withr::local_tempdir()
  writeLines("{{{iso_levels}}}", file.path(template_dir, "3-analysis.Rmd"))
  file.create(file.path(template_dir, "gdr_logo-01.png"))
  mae <- gDRutils::get_synthetic_data("finalMAE_combo_matrix_small.qs2")
  build <- function(...) {
    build_report_rmd(mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3,
                     extra_render_params = list(...))
  }

  expect_warning(build(iso_levels = 0.1), "no isoline is drawn for them: 0.1 for RV\\.$")
  expect_no_warning(build(iso_levels = 0.1, plots_to_generate = "sa_heatmap"))
})
