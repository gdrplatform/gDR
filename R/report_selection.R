# Subsets of the data that a caller can draw the analysis step on, passed through
# 'extra_render_params'. Each one left out keeps all the data.
.DATA_SELECTIONS <- c(
  "drugs_of_interest",
  "cell_lines_of_interest",
  "codrugs_of_interest",
  "drug_pairs_of_interest",
  "tissues_of_interest",
  "moa_of_interest"
)

# File the analysis step reads when a data selection is set, next to gDR_mae.qs2.
.SELECTED_MAE_FILE <- "gDR_mae_selection.qs2"

#' Resolve the data selections of the analysis step
#'
#' Checks the form of the data selections in \code{extra_render_params}. The names themselves are
#' checked against the data by \code{select_report_data()}.
#'
#' @param extra_render_params Named list of deployment-specific render parameters.
#'
#' @return Named list of the data selections that are set.
#' @keywords internal
resolve_data_selection <- function(extra_render_params) {
  checkmate::assert_list(extra_render_params, names = "unique")
  selection <- extra_render_params[intersect(.DATA_SELECTIONS, names(extra_render_params))]
  selection <- Filter(Negate(is.null), selection)

  for (nm in setdiff(names(selection), "drug_pairs_of_interest")) {
    checkmate::assert_character(selection[[nm]], min.len = 1, any.missing = FALSE, .var.name = nm)
  }
  if (!is.null(selection$drug_pairs_of_interest)) {
    checkmate::assert_list(selection$drug_pairs_of_interest, types = "character", min.len = 1,
                           .var.name = "drug_pairs_of_interest")
    for (pair in selection$drug_pairs_of_interest) {
      checkmate::assert_character(pair, len = 2, any.missing = FALSE, .var.name = "drug_pairs_of_interest")
    }
  }
  selection
}

#' Subset a MultiAssayExperiment to the data selections of the analysis step
#'
#' Drugs are those of \code{drugs_of_interest}, of the mechanisms in \code{moa_of_interest} and
#' the first drug of each pair in \code{drug_pairs_of_interest}; cell lines are those of
#' \code{cell_lines_of_interest} and of the tissues in \code{tissues_of_interest}. Combinations are
#' further restricted to the pairs of \code{drug_pairs_of_interest} or, without pairs, to the
#' co-drugs of \code{codrugs_of_interest}. Experiments left without data are dropped.
#'
#' @param mae MultiAssayExperiment.
#' @param selection Named list returned by \code{resolve_data_selection()}.
#'
#' @return The subset MultiAssayExperiment.
#' @keywords internal
select_report_data <- function(mae, selection) {
  checkmate::assert_class(mae, "MultiAssayExperiment")
  checkmate::assert_list(selection, names = "unique")

  ids <- gDRutils::get_env_identifiers(
    c("drug_name", "drug_name2", "drug_moa", "cellline_name", "cellline_tissue"),
    simplify = FALSE
  )
  ses <- MultiAssayExperiment::experiments(mae)
  rows <- lapply(ses, function(se) data.table::as.data.table(SummarizedExperiment::rowData(se)))
  cols <- lapply(ses, function(se) data.table::as.data.table(SummarizedExperiment::colData(se)))
  available <- function(tables, col) unique(unlist(lapply(tables, `[[`, col)))

  .check_found <- function(selected, values, nm) {
    missing <- setdiff(selected, values)
    if (length(missing) > 0) {
      stop(sprintf("'%s' has value(s) not found in the data: %s.", nm, toString(missing)), call. = FALSE)
    }
  }

  drugs <- selection$drugs_of_interest
  .check_found(drugs, available(rows, ids$drug_name), "drugs_of_interest")
  if (!is.null(selection$moa_of_interest)) {
    .check_found(selection$moa_of_interest, available(rows, ids$drug_moa), "moa_of_interest")
    drugs <- union(drugs, unique(unlist(lapply(rows, function(r) {
      r[[ids$drug_name]][r[[ids$drug_moa]] %in% selection$moa_of_interest]
    }))))
  }
  pairs <- selection$drug_pairs_of_interest
  if (!is.null(pairs)) {
    .check_found(vapply(pairs, `[[`, character(1), 1), available(rows, ids$drug_name), "drug_pairs_of_interest")
    .check_found(vapply(pairs, `[[`, character(1), 2), available(rows, ids$drug_name2), "drug_pairs_of_interest")
    drugs <- union(drugs, vapply(pairs, `[[`, character(1), 1))
  }
  .check_found(selection$codrugs_of_interest, available(rows, ids$drug_name2), "codrugs_of_interest")

  cell_lines <- selection$cell_lines_of_interest
  .check_found(cell_lines, available(cols, ids$cellline_name), "cell_lines_of_interest")
  if (!is.null(selection$tissues_of_interest)) {
    .check_found(selection$tissues_of_interest, available(cols, ids$cellline_tissue), "tissues_of_interest")
    cell_lines <- union(cell_lines, unique(unlist(lapply(cols, function(cl) {
      cl[[ids$cellline_name]][cl[[ids$cellline_tissue]] %in% selection$tissues_of_interest]
    }))))
  }

  keep_rows <- lapply(rows, function(r) {
    keep <- rep(TRUE, NROW(r))
    if (!is.null(drugs)) {
      keep <- keep & r[[ids$drug_name]] %in% drugs
    }
    if (ids$drug_name2 %in% names(r)) {
      if (!is.null(pairs)) {
        keep <- keep & paste(r[[ids$drug_name]], r[[ids$drug_name2]]) %in%
          vapply(pairs, paste, character(1), collapse = " ")
      } else if (!is.null(selection$codrugs_of_interest)) {
        keep <- keep & r[[ids$drug_name2]] %in% selection$codrugs_of_interest
      }
    }
    keep
  })
  keep_cols <- lapply(cols, function(cl) {
    if (is.null(cell_lines)) rep(TRUE, NROW(cl)) else cl[[ids$cellline_name]] %in% cell_lines
  })

  selected <- MultiAssayExperiment::subsetByColumn(MultiAssayExperiment::subsetByRow(mae, keep_rows), keep_cols)
  non_empty <- names(selected)[vapply(MultiAssayExperiment::experiments(selected), function(se) {
    all(dim(se) > 0)
  }, logical(1))]
  if (!gDRutils::get_supported_experiments("sa") %in% non_empty) {
    stop("The data selection leaves no single-agent data, which the analysis report needs.", call. = FALSE)
  }
  if (length(non_empty) == length(selected)) {
    return(selected)
  }
  # an experiment the selection empties is dropped on purpose
  withCallingHandlers(selected[, , non_empty], warning = function(w) {
    if (grepl("'experiments' dropped", conditionMessage(w), fixed = TRUE)) {
      invokeRestart("muffleWarning")
    }
  })
}

#' Read the data the analysis step of a run draws
#'
#' @param plan List returned by \code{prepare_report_steps()}.
#' @param output_dir Character string of the versioned output directory.
#'
#' @return The MultiAssayExperiment given to the run, or the one its processing step wrote.
#' @keywords internal
read_report_mae <- function(plan, output_dir) {
  if (inherits(plan$mae, "MultiAssayExperiment")) {
    return(plan$mae)
  }
  path <- file.path(output_dir, "gDR_data", "gDR_mae.qs2")
  if (!file.exists(path)) {
    stop(
      "The data selections of the analysis step need 'gDR_data/gDR_mae.qs2', which rendering the ",
      "processing step writes. Write the analysis step after the processing step has been rendered.",
      call. = FALSE
    )
  }
  qs2::qs_read(path)
}
