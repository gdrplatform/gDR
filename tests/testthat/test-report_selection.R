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
  # drug_021 is only ever the second drug of a combination, and its combinations stay
  expect_equal(.drugs(by_moa, "combination", "DrugName_2"), "drug_021")
  expect_equal(NROW(by_moa[["combination"]]), 3L)

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
  # both drugs are in the data, but were never tested together
  expect_error(select_report_data(mae, list(drug_pairs_of_interest = list(c("drug_004", "drug_005")))),
               "not tested together in the data: drug_004 \\+ drug_005\\. Tested pairs: drug_004 \\+ drug_021",
               class = "report_selection_error")
  expect_error(select_report_data(mae, list(codrugs_of_interest = "nope")), "'codrugs_of_interest'.*nope",
               class = "report_selection_error")
  combo_only <- suppressWarnings(suppressMessages(mae[, , "combination"]))
  expect_error(suppressMessages(select_report_data(combo_only, list(drugs_of_interest = "drug_004"))),
               "no single-agent data")
})

test_that("select_report_data matches a drug and a co-drug in either column of a combination", {
  mae <- .selection_mae()

  # drug_021 is the second drug of every combination it is in
  by_drug <- suppressMessages(select_report_data(mae, list(drugs_of_interest = "drug_021")))
  expect_equal(.drugs(by_drug, "single-agent"), "drug_021")
  expect_equal(.drugs(by_drug, "combination"), c("drug_004", "drug_005", "drug_006"))
  expect_equal(.drugs(by_drug, "combination", "DrugName_2"), "drug_021")

  # drug_004 is only ever the first drug
  by_codrug <- suppressMessages(select_report_data(mae, list(codrugs_of_interest = "drug_004")))
  expect_equal(.drugs(by_codrug, "combination"), "drug_004")
  expect_equal(.drugs(by_codrug, "single-agent"), .drugs(mae, "single-agent"))

  both <- suppressMessages(select_report_data(
    mae, list(drugs_of_interest = "drug_026", codrugs_of_interest = "drug_005")
  ))
  expect_equal(NROW(both[["combination"]]), 1L)
})

test_that("select_report_data turns a reversed pair around, with a message", {
  mae <- .selection_mae()
  expect_message(
    reversed <- select_report_data(mae, list(drug_pairs_of_interest = list(c("drug_021", "drug_005")))),
    "turned around to the order of the data: drug_021 \\+ drug_005 -> drug_005 \\+ drug_021"
  )
  as_stored <- suppressMessages(
    select_report_data(mae, list(drug_pairs_of_interest = list(c("drug_005", "drug_021"))))
  )
  expect_equal(reversed, as_stored)
  expect_equal(.drugs(reversed, "single-agent"), "drug_005")
})

test_that("build_report_rmd writes no step when the selection does not match an MAE input", {
  out <- withr::local_tempdir()
  template_dir <- withr::local_tempdir()
  writeLines("{{analysis_mae_file}}", file.path(template_dir, "3-analysis.Rmd"))
  file.create(file.path(template_dir, "gdr_logo-01.png"))

  expect_error(
    build_report_rmd(
      mae = .selection_mae(), output_dir = out, rmd_template_path = template_dir, steps = 3,
      extra_render_params = list(drugs_of_interest = "nope")
    ),
    "'drugs_of_interest'.*nope",
    class = "report_selection_error"
  )
  expect_length(list.files(out, pattern = "\\.Rmd$", recursive = TRUE), 0)
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

  # drug_004 and drug_005 were never combined, so the selection leaves no combination
  selected <- suppressMessages(build_report_rmd(
    mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3,
    extra_render_params = list(drugs_of_interest = "drug_004", codrugs_of_interest = "drug_005")
  ))
  expect_equal(readLines(selected[["3-analysis"]]), "file: gDR_mae_selection.qs2; combo: no")
  saved <- qs2::qs_read(file.path(dirname(selected[["3-analysis"]]), "gDR_data", "gDR_mae_selection.qs2"))
  expect_equal(.drugs(saved, "single-agent"), "drug_004")
})

test_that("describe_report_selection lists the selections that narrow the report", {
  full <- resolve_analysis_params(list())
  expect_null(describe_report_selection(full, list()))
  expect_length(narrowing_selections(full, list()), 0)

  narrowed <- resolve_analysis_params(list(norm_types = "RV", plots_to_generate = c("sa_heatmap", "combo_drc")))
  selection <- list(drug_pairs_of_interest = list(c("drug_005", "drug_021")), drugs_of_interest = "drug_004")
  expect_equal(
    narrowing_selections(narrowed, selection),
    c("drug_pairs_of_interest", "drugs_of_interest", "norm_types", "plots_to_generate")
  )
  expect_equal(
    describe_report_selection(narrowed, selection),
    paste(
      "* **Drugs:** drug_004",
      "* **Drug pairs:** drug_005 + drug_021",
      "* **Normalization types:** RV",
      "* **Sections:** sa_heatmap, combo_drc",
      sep = "\n"
    )
  )
})

test_that("the analysis step and its add-on step note the selection and draw the selected data", {
  out <- withr::local_tempdir()
  template_dir <- withr::local_tempdir()
  writeLines("{{analysis_mae_file}}{{#has_report_selection}}|{{{report_selection}}}{{/has_report_selection}}",
             file.path(template_dir, "3-analysis.Rmd"))
  writeLines("{{analysis_mae_file}}", file.path(template_dir, "3-1-chemical_genomics_analysis.Rmd"))
  file.create(file.path(template_dir, "gdr_logo-01.png"))
  mae <- .selection_mae()

  full <- build_report_rmd(mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3,
                           special_sections = "chemical_genomics")
  expect_equal(unname(vapply(full, readLines, character(1))), c("gDR_mae.qs2", "gDR_mae.qs2"))

  selected <- suppressMessages(build_report_rmd(
    mae = mae, output_dir = out, rmd_template_path = template_dir, steps = 3,
    special_sections = "chemical_genomics", extra_render_params = list(drugs_of_interest = "drug_004")
  ))
  expect_equal(
    unname(vapply(selected, readLines, character(1))),
    c("gDR_mae_selection.qs2|* **Drugs:** drug_004", "gDR_mae_selection.qs2")
  )
})
