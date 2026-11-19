# single-agent SE with a second fit source: a copy of the gDR fits, two per cell, the second shifted
.se_with_copy_fits <- function() {
  mae <- gDRutils::get_synthetic_data("finalMAE_small")
  se <- mae[[gDRutils::get_supported_experiments("sa")]]
  metrics <- gDRutils::convert_se_assay_to_dt(se, "Metrics", include_metadata = FALSE)
  copy1 <- data.table::copy(metrics)
  copy2 <- data.table::copy(metrics)
  copy2$x_inf <- copy2$x_inf + 0.1
  copy1$pool_id <- "P1"
  copy2$pool_id <- "P2"
  copies <- rbind(copy1, copy2)
  copies$fit_source <- "copy"
  se <- gDRutils::persist_fit_assay(se, copies, merge = "merge", assay_name = "Metrics",
                                    row = "rId", col = "cId",
                                    upsert_key_cols = c("fit_source", "normalization_type"))
  list(se = se, metrics = metrics)
}

test_that("compare_fit_sources pairs every fit of the other source with the reference fit of its cell", {
  x <- .se_with_copy_fits()
  res <- compare_fit_sources(x$se, other = "copy")
  n_cells <- sum(x$metrics$normalization_type == "RV")

  expect_equal(NROW(res$pairs), 2 * n_cells)
  expect_true("pool_id" %in% names(res$pairs))
  idfs <- gDRutils::get_SE_identifiers(x$se, simplify = TRUE)
  expect_true(all(c(idfs[["drug"]], idfs[["cellline"]], idfs[["duration"]]) %in% names(res$pairs)))

  p1 <- res$pairs[res$pairs$pool_id == "P1"]
  expect_equal(p1$ec50_copy, p1$ec50_gDR)
  p2 <- res$pairs[res$pairs$pool_id == "P2"]
  expect_equal(p2$x_inf_copy - p2$x_inf_gDR, rep(0.1, NROW(p2)))

  expect_identical(res$summary$parameter, c("auc", "log10(ec50)", "x_inf"))
  # identical fits give the same auc
  expect_equal(p1$auc_copy, p1$auc_gDR)
  expect_true(any(is.finite(p1$auc_gDR)))
  summary <- res$summary[res$summary$parameter == "log10(ec50)"]
  expect_equal(summary$median_abs_diff, 0)
  expect_equal(summary$spearman, 1)
  # half of the x_inf pairs differ by 0.1
  expect_equal(res$summary[res$summary$parameter == "x_inf"]$p95_abs_diff, 0.1)
})

test_that(".curve_auc follows PRISM's definition of AUC", {
  # a flat gDR fit (ec50 = 0) is its x_inf
  expect_equal(.curve_auc(1, 0.8, 0, 1e-4, 0.001, 10), 0.8)
  # the mean over log10 concentration of the curve
  auc <- .curve_auc(1, 0.2, 0.1, 1.5, 0.001, 10, n_points = 1001L)
  f <- function(l) 0.2 + 0.8 / (1 + (10^l / 0.1)^1.5)
  expect_equal(auc, stats::integrate(f, -3, 1)$value / 4, tolerance = 1e-4)
  # clamped to [0, 1]
  expect_equal(.curve_auc(1.5, 1.2, 1, 1, 0.01, 1), 1)
  expect_equal(.curve_auc(1, -0.5, 1e-6, 5, 0.01, 1), 0)
  expect_true(is.na(.curve_auc(NA, 0.5, 1, 1, 0.01, 1)))
  # one value per fit
  expect_equal(.curve_auc(c(1, 1), c(0.8, 0.6), c(0, 0), c(1e-4, 1e-4), c(0.01, 0.01), c(1, 1)), c(0.8, 0.6))
})

test_that("compare_fit_sources leaves non-finite values out of the summary", {
  x <- .se_with_copy_fits()
  res <- compare_fit_sources(x$se, other = "copy", params = "ec50")
  n_finite <- sum(is.finite(log10(res$pairs$ec50_copy)) & is.finite(log10(res$pairs$ec50_gDR)) &
                    res$pairs$ec50_in_range)
  expect_equal(res$summary$n_pairs, n_finite)
  expect_gt(n_finite, 0)

  # an ec50 outside the tested concentrations leaves the pair out of the curve shape
  se <- x$se
  metrics <- gDRutils::convert_se_assay_to_dt(se, "Metrics", include_metadata = FALSE)
  metrics <- metrics[metrics$fit_source == "copy"]
  metrics$ec50 <- 1e6
  se <- gDRutils::persist_fit_assay(se, metrics, merge = "merge", assay_name = "Metrics",
                                    row = "rId", col = "cId",
                                    upsert_key_cols = c("fit_source", "normalization_type"))
  res_out <- compare_fit_sources(se, other = "copy")
  expect_false(any(res_out$pairs$ec50_in_range))
  expect_equal(res_out$summary$n_pairs[res_out$summary$parameter %in% c("log10(ec50)", "x_inf")], c(0L, 0L))
  expect_gt(res_out$summary$n_pairs[res_out$summary$parameter == "auc"], 0)

  # only the fits of the selected normalization type are paired
  res_gr <- compare_fit_sources(x$se, other = "copy", normalization_type = "GR")
  expect_equal(NROW(res_gr$pairs), 2 * sum(x$metrics$normalization_type == "GR"))

  # a source with no fits gives no pairs
  res_none <- compare_fit_sources(x$se, other = "missing")
  expect_equal(NROW(res_none$pairs), 0L)
  expect_true(all(res_none$summary$n_pairs == 0))
})

test_that("has_fit_source finds a fit source in the single-agent Metrics", {
  x <- .se_with_copy_fits()
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = stats::setNames(list(x$se), gDRutils::get_supported_experiments("sa"))
  )
  expect_true(gDR:::has_fit_source(mae, "copy"))
  expect_false(gDR:::has_fit_source(mae, "PRISM"))
  expect_false(gDR:::has_fit_source(MultiAssayExperiment::MultiAssayExperiment(), "PRISM"))

  output_dir <- tempfile()
  dir.create(file.path(output_dir, "gDR_data"), recursive = TRUE)
  on.exit(unlink(output_dir, recursive = TRUE))
  params <- gDR:::prepare_dynamic_render_params("mae", mae, output_dir, 3)
  expect_false(params$has_prism_fits)
})

test_that("validate_and_prepare_inputs accepts a PRISM DRC table only with PRISM data", {
  val_func <- gDR:::validate_and_prepare_inputs
  drc <- system.file("testdata", "prism_drc.csv", package = "gDRimport")
  testthat::skip_if(drc == "", "gDRimport without the PRISM DRC fixture")
  model <- system.file("testdata", "prism_drc_model.csv", package = "gDRimport")

  expect_error(
    val_func(list(long_table = drc, prism_drc_path = drc, steps = 1:3), data_type = "long_table"),
    "only used with PRISM data"
  )
  expect_error(
    val_func(list(prism_data_path = "l5.csv", meta_data_path = model, prism_drc_path = tempfile(),
                  steps = 1:3), data_type = "prism_5")
  )
  res <- val_func(list(prism_data_path = "l5.csv", meta_data_path = model, prism_drc_path = drc,
                       metadata_columns = NULL, steps = 1:3), data_type = "prism_5")
  expect_equal(res$prism_drc_path, drc)
})

# The lines of a template between the opening and closing tag of a whisker section.
.template_section <- function(file, section) {
  path <- system.file("report_templates", file, package = "gDR")
  testthat::skip_if(path == "", paste("template not installed:", file))
  lines <- readLines(path, warn = FALSE)
  start <- which(lines == paste0("{{#", section, "}}"))
  end <- which(lines == paste0("{{/", section, "}}"))
  lapply(seq_along(start), function(i) lines[(start[i] + 1):(end[i] - 1)])
}

test_that("the processing template adds the PRISM curves to the single-agent Metrics", {
  testthat::skip_if_not(exists("read_PRISM_drc", asNamespace("gDRimport")), "gDRimport without read_PRISM_drc")
  block <- .template_section("2-processing_and_QC.Rmd", "prism_drc_path")
  code <- block[[which(vapply(block, function(b) any(grepl("add_PRISM_metrics", b)), logical(1)))]]

  run_block <- function(drc_path, env_out = FALSE) {
    env <- new.env()
    env$sa_name <- gDRutils::get_supported_experiments("sa")
    env$mae <- gDRutils::get_synthetic_data("finalMAE_prism")
    params <- list(
      prism_drc_path = drc_path,
      meta_data_path = system.file("testdata", "prism_drc_model.csv", package = "gDRimport")
    )
    eval(parse(text = whisker::whisker.render(paste(code, collapse = "\n"), params)), envir = env)
    if (env_out) env else env$mae
  }

  mae <- suppressWarnings(run_block(system.file("testdata", "prism_drc.csv", package = "gDRimport")))
  expect_true(gDR:::has_fit_source(mae, "PRISM"))

  # the report says how many curves were added
  summary_block <- block[[which(vapply(block, function(b) any(grepl("prism_drc_import, results", b)), logical(1)))]]
  summary_code <- summary_block[!grepl("^```", summary_block)]
  report_text <- function(env) {
    paste(utils::capture.output(eval(parse(text = summary_code), envir = env)), collapse = " ")
  }
  good <- suppressWarnings(run_block(system.file("testdata", "prism_drc.csv", package = "gDRimport"), env_out = TRUE))
  expect_match(report_text(good), "4 of the 4 curves of the DRC table were added; 0 have no matching")

  # a table that cannot be read leaves the gDR fits as they are, and the error is shown
  bad <- run_block(tempfile(fileext = ".csv"), env_out = TRUE)
  expect_false(gDR:::has_fit_source(bad$mae, "PRISM"))
  expect_match(bad$prism_import_error, "exist")
  expect_match(report_text(bad), "the DRC table was not added")
})

test_that("the analysis templates draw only the gDR fits", {
  for (f in c("3-analysis.Rmd", "3-1-PRISM_analysis.Rmd")) {
    path <- system.file("report_templates", f, package = "gDR")
    testthat::skip_if(path == "", paste("template not installed:", f))
    lines <- readLines(path, warn = FALSE)
    extract <- which(lines == 'response_metrics_sa <- assay_list[[sa_name]][["Metrics"]]')
    expect_length(extract, 1L)
    expect_true(any(grepl('fit_source == "gDR"', lines[extract + 1:4], fixed = TRUE)), info = f)
  }
})

test_that("the analysis template compares the PRISM fits with the gDR fits", {
  testthat::skip_if_not_installed("gDRplots")
  testthat::skip_if_not_installed("writexl")
  block <- .template_section("3-analysis.Rmd", "has_prism_fits")[[1]]
  fence <- grepl("^```", block)
  chunk <- cumsum(fence)
  code <- block[chunk %% 2 == 1 & !fence]

  wd <- tempfile()
  dir.create(file.path(wd, "plots"), recursive = TRUE)
  dir.create(file.path(wd, "tables"))
  on.exit(unlink(wd, recursive = TRUE))
  x <- .se_with_copy_fits()
  metrics <- gDRutils::convert_se_assay_to_dt(x$se, "Metrics", include_metadata = FALSE)
  metrics <- metrics[metrics$fit_source == "copy"]
  metrics$fit_source <- "PRISM"
  se <- gDRutils::persist_fit_assay(x$se, metrics, merge = "merge", assay_name = "Metrics",
                                    row = "rId", col = "cId",
                                    upsert_key_cols = c("fit_source", "normalization_type"))
  env <- new.env()
  env$wd <- wd
  env$sa_name <- gDRutils::get_supported_experiments("sa")
  env$mae <- MultiAssayExperiment::MultiAssayExperiment(experiments = stats::setNames(list(se), env$sa_name))
  # the packages the template attaches
  code <- c("library(data.table)", "library(ggplot2)", "library(gDRplots)", "library(writexl)", code)
  rendered <- whisker::whisker.render(paste(code, collapse = "\n"), list(viz_format = "png"))
  suppressWarnings(eval(parse(text = rendered), envir = env))

  expect_true(file.exists(file.path(wd, "tables", "sa_fits_gDR_vs_PRISM.xlsx")))
  expect_true(file.exists(file.path(wd, "plots", "sa_fits_gDR_vs_PRISM.png")))
  expect_s3_class(env$plt_fit_cmp, "ggplot")
  expect_equal(NROW(env$fit_cmp$pairs), 2 * sum(x$metrics$normalization_type == "RV"))
})
