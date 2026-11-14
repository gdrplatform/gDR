.selection_mae <- function() gDRutils::get_synthetic_data("finalMAE_combo_matrix_small.qs2")

.drugs <- function(mae, experiment, col = "DrugName") {
  sort(unique(SummarizedExperiment::rowData(mae[[experiment]])[[col]]))
}

test_that("resolve_data_selection keeps the selections that are set and checks their form", {
  expect_length(resolve_data_selection(list(title = "x")), 0)
  res <- resolve_data_selection(list(drugs_of_interest = "drug_004", tissues_of_interest = NULL))
  expect_equal(res, list(drugs_of_interest = "drug_004"))

  expect_error(resolve_data_selection(list(drugs_of_interest = 4)), "drugs_of_interest")
  expect_error(resolve_data_selection(list(drug_pairs_of_interest = list("drug_004"))), "drug_pairs_of_interest")
  expect_error(resolve_data_selection(list(drug_pairs_of_interest = c("a", "b"))), "drug_pairs_of_interest")
})

test_that("select_report_data subsets drugs and cell lines across experiments", {
  mae <- .selection_mae()
  sel <- suppressMessages(
    select_report_data(mae, list(drugs_of_interest = "drug_004", cell_lines_of_interest = "cellline_GB"))
  )

  expect_equal(.drugs(sel, "single-agent"), "drug_004")
  expect_equal(.drugs(sel, "combination"), "drug_004")
  expect_equal(unique(SummarizedExperiment::colData(sel[["combination"]])$CellLineName), "cellline_GB")
  gDRutils::validate_MAE(sel)
})

test_that("select_report_data resolves mechanisms, tissues, co-drugs and pairs", {
  mae <- .selection_mae()

  by_moa <- suppressMessages(select_report_data(mae, list(moa_of_interest = "moa_D")))
  expect_equal(.drugs(by_moa, "single-agent"), "drug_021")
  # drug_021 is only ever the second drug of a combination
  expect_equal(names(by_moa), "single-agent")

  by_tissue <- suppressMessages(select_report_data(mae, list(tissues_of_interest = "tissue_y")))
  expect_equal(dim(by_tissue[["single-agent"]]), dim(mae[["single-agent"]]))

  by_codrug <- suppressMessages(select_report_data(mae, list(codrugs_of_interest = "drug_026")))
  expect_equal(.drugs(by_codrug, "combination", "DrugName_2"), "drug_026")
  expect_equal(.drugs(by_codrug, "single-agent"), .drugs(mae, "single-agent"))

  by_pair <- suppressMessages(select_report_data(
    mae,
    list(drug_pairs_of_interest = list(c("drug_005", "drug_021")), codrugs_of_interest = "drug_026")
  ))
  # the pairs win over the co-drugs, and their first drugs join the single-agent data
  expect_equal(NROW(by_pair[["combination"]]), 1L)
  expect_equal(.drugs(by_pair, "single-agent"), "drug_005")
})

test_that("select_report_data names what it cannot find and refuses to drop the single-agent data", {
  mae <- .selection_mae()
  expect_error(select_report_data(mae, list(drugs_of_interest = c("drug_004", "nope"))),
               "'drugs_of_interest'.*nope")
  expect_error(select_report_data(mae, list(drug_pairs_of_interest = list(c("drug_004", "drug_005")))),
               "drug_pairs_of_interest.*drug_005")
  combo_only <- suppressWarnings(suppressMessages(mae[, , "combination"]))
  expect_error(suppressMessages(select_report_data(combo_only, list(drugs_of_interest = "drug_004"))),
               "no single-agent data")
})

test_that("the analysis step reads the selected data and its flags follow it", {
  out <- withr::local_tempdir()
  template_dir <- withr::local_tempdir()
  writeLines("file: {{analysis_mae_file}}; combo: {{#has_combo}}yes{{/has_combo}}{{^has_combo}}no{{/has_combo}}",
             file.path(template_dir, "3-analysis.Rmd"))
  file.create(file.path(template_dir, "gdr_logo-01.png"))
  mae <- .selection_mae()

  full <- build_report_rmd(mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3)
  expect_equal(readLines(full[["3-analysis"]]), "file: gDR_mae.qs2; combo: yes")

  selected <- suppressMessages(build_report_rmd(
    mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3,
    extra_render_params = list(moa_of_interest = "moa_D")
  ))
  expect_equal(readLines(selected[["3-analysis"]]), "file: gDR_mae_selection.qs2; combo: no")
  saved <- qs2::qs_read(file.path(dirname(selected[["3-analysis"]]), "gDR_data", "gDR_mae_selection.qs2"))
  expect_equal(.drugs(saved, "single-agent"), "drug_021")
})
