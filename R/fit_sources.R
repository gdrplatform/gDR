#' Compare the fits of two fit sources
#'
#' Pairs every fit of \code{other} (e.g. the curves PRISM delivered, added by
#' \code{gDRcore::add_PRISM_metrics()}) with the fit of \code{reference} in the same cell of the
#' \code{Metrics} assay, and summarizes how close they are. A cell can hold several fits of
#' \code{other} (PRISM fits one curve per pool and compound plate); each one is paired with the
#' single \code{reference} fit of the cell.
#'
#' Two sources can describe the same curve with different parameters (gDR fixes \code{x_0} at 1 for
#' relative viability and gives a flat curve \code{ec50 = 0}), so the curves are compared by
#' \code{auc}: computed from the parameters of each fit as PRISM defines AUC, the mean of the curve,
#' clamped to [0, 1], over log10 concentration between the lowest and highest concentration of the
#' cell in \code{averaged_assay}. The parameters of the curve shape (\code{ec50}, \code{x_inf},
#' \code{x_0}, \code{h}) are compared only for pairs where both fits have their \code{ec50} within
#' that range (\code{ec50_in_range}), where the data define them; \code{ec50} is compared on the
#' log10 scale. A pair counts for a parameter only when both values are finite, so failed fits are
#' left out of its summary.
#'
#' @param se \code{SummarizedExperiment} with a \code{Metrics} assay holding both fit sources.
#' @param other Character string, the fit source compared with \code{reference}.
#' @param reference Character string, the fit source it is compared with.
#' @param normalization_type Character string, the normalization type of the fits.
#' @param params Character vector, the parameters compared: \code{"auc"} or columns of the
#'   \code{Metrics} assay.
#' @param metrics_assay Character string, name of the assay with the fits.
#' @param averaged_assay Character string, name of the assay giving the concentration range of
#'   each cell.
#'
#' @return A list with \code{pairs}, a \code{data.table} with one row per fit of \code{other}: the
#'   drug, cell line and Duration, the columns that tell fits of one cell apart, and every
#'   parameter of both sources (\code{<param>_<source>}), and \code{ec50_in_range}; and
#'   \code{summary}, a \code{data.table} with one row per parameter: the number of pairs, the
#'   Spearman correlation, and the median and 95th percentile of the absolute difference.
#'
#' @examples
#' mae <- gDRutils::get_synthetic_data("finalMAE_small")
#' se <- mae[[gDRutils::get_supported_experiments("sa")]]
#' # a copy of the gDR fits under another fit source
#' metrics <- gDRutils::convert_se_assay_to_dt(se, "Metrics", include_metadata = FALSE)
#' metrics$fit_source <- "copy"
#' se <- gDRutils::persist_fit_assay(se, metrics, merge = "merge", assay_name = "Metrics",
#'                                   row = "rId", col = "cId",
#'                                   upsert_key_cols = c("fit_source", "normalization_type"))
#' compare_fit_sources(se, other = "copy")$summary
#'
#' @export
compare_fit_sources <- function(se,
                                other,
                                reference = "gDR",
                                normalization_type = "RV",
                                params = c("auc", "ec50", "x_inf"),
                                metrics_assay = "Metrics",
                                averaged_assay = "Averaged") {
  checkmate::assert_class(se, "SummarizedExperiment")
  checkmate::assert_string(other)
  checkmate::assert_string(reference)
  checkmate::assert_string(normalization_type)
  checkmate::assert_character(params, min.len = 1, any.missing = FALSE, unique = TRUE)
  checkmate::assert_choice(metrics_assay, SummarizedExperiment::assayNames(se))
  checkmate::assert_choice(averaged_assay, SummarizedExperiment::assayNames(se))

  metrics <- gDRutils::convert_se_assay_to_dt(se, metrics_assay, include_metadata = FALSE)
  checkmate::assert_names(names(metrics), must.include = c(
    "fit_source", "normalization_type", "x_0", "x_inf", "ec50", "h", setdiff(params, "auc")
  ))
  # logical vectors built outside [], where the argument names would resolve to the columns
  keep <- metrics$normalization_type == normalization_type
  metrics <- metrics[keep]
  range <- .concentration_range(se, averaged_assay, normalization_type)
  at <- match(paste(metrics$rId, metrics$cId), paste(range$rId, range$cId))
  if ("auc" %in% params) {
    metrics$auc <- .curve_auc(metrics$x_0, metrics$x_inf, metrics$ec50, metrics$h,
                              range$min_conc[at], range$max_conc[at])
  }
  in_range <- metrics$ec50 >= range$min_conc[at] & metrics$ec50 <= range$max_conc[at]
  metrics$in_range <- !is.na(in_range) & in_range
  ref <- metrics[metrics$fit_source %in% reference]
  oth <- metrics[metrics$fit_source %in% other]
  if (anyDuplicated(ref[, c("rId", "cId")])) {
    stop(sprintf("fit source '%s' has more than one fit in a cell", reference))
  }

  # the fit identity within a cell (text columns only the other source fills), kept so the
  # pairs can be traced back to it
  with_values <- function(dt) names(dt)[vapply(dt, function(x) any(!is.na(x)), logical(1))]
  id_cols <- setdiff(with_values(oth), c(with_values(ref), "rId", "cId"))
  id_cols <- id_cols[!vapply(oth[, id_cols, with = FALSE], is.numeric, logical(1))]
  oth <- oth[, c("rId", "cId", id_cols, params, "in_range"), with = FALSE]
  ref <- ref[, c("rId", "cId", params, "in_range"), with = FALSE]
  data.table::setnames(oth, c(params, "in_range"), paste0(c(params, "in_range"), "_", other))
  data.table::setnames(ref, c(params, "in_range"), paste0(c(params, "in_range"), "_", reference))
  pairs <- merge(oth, ref, by = c("rId", "cId"), sort = FALSE)
  pairs$ec50_in_range <- pairs[[paste0("in_range_", other)]] & pairs[[paste0("in_range_", reference)]]
  data.table::set(pairs, j = paste0("in_range_", c(other, reference)), value = NULL)

  # names of the cell, from the row and column metadata
  idfs <- gDRutils::get_SE_identifiers(se, simplify = TRUE)
  rdata <- SummarizedExperiment::rowData(se)
  cdata <- SummarizedExperiment::colData(se)
  row_cols <- intersect(unlist(idfs[c("drug", "drug_name", "duration")]), names(rdata))
  col_cols <- intersect(unlist(idfs[c("cellline", "cellline_name")]), names(cdata))
  cell <- cbind(
    data.table::as.data.table(as.list(rdata[pairs$rId, row_cols, drop = FALSE])),
    data.table::as.data.table(as.list(cdata[pairs$cId, col_cols, drop = FALSE]))
  )
  pairs <- cbind(cell, pairs)

  summary <- data.table::rbindlist(lapply(params, function(p) {
    x <- pairs[[paste0(p, "_", other)]]
    y <- pairs[[paste0(p, "_", reference)]]
    if (p == "ec50") {
      x <- suppressWarnings(log10(x))
      y <- suppressWarnings(log10(y))
    }
    ok <- is.finite(x) & is.finite(y)
    if (p %in% c("ec50", "x_inf", "x_0", "h")) {
      ok <- ok & pairs$ec50_in_range
    }
    d <- abs(x[ok] - y[ok])
    data.table::data.table(
      parameter = if (p == "ec50") "log10(ec50)" else p,
      n_pairs = sum(ok),
      spearman = if (sum(ok) > 2) {
        suppressWarnings(stats::cor(x[ok], y[ok], method = "spearman"))
      } else {
        NA_real_
      },
      median_abs_diff = if (any(ok)) stats::median(d) else NA_real_,
      p95_abs_diff = if (any(ok)) unname(stats::quantile(d, 0.95)) else NA_real_
    )
  }))

  list(pairs = pairs, summary = summary)
}


# The lowest and highest concentration above 0 of each (rId, cId) cell.
#' @keywords internal
.concentration_range <- function(se, averaged_assay, normalization_type) {
  conc <- gDRutils::get_SE_identifiers(se, "concentration", simplify = TRUE)
  avg <- data.table::as.data.table(BumpyMatrix::unsplitAsDataFrame(
    SummarizedExperiment::assay(se, averaged_assay), row.field = "rId", column.field = "cId"
  ))
  keep <- avg[[conc]] > 0 & !is.na(avg[[conc]])
  if ("normalization_type" %in% names(avg)) {
    keep <- keep & avg$normalization_type == normalization_type
  }
  avg <- avg[keep]
  avg[, list(min_conc = min(get(conc)), max_conc = max(get(conc))), by = c("rId", "cId")]
}


# AUC as PRISM defines it: the mean of the curve x_inf + (x_0 - x_inf) / (1 + (c / ec50)^h),
# clamped to [0, 1], over log10 concentration from lo to hi. A flat gDR fit (ec50 = 0) gives x_inf.
#' @keywords internal
.curve_auc <- function(x_0, x_inf, ec50, h, lo, hi, n_points = 201L) {
  steps <- seq(0, 1, length.out = n_points)
  log_conc <- log10(lo) + outer(log10(hi) - log10(lo), steps)
  # rows are the fits; the vectors recycle down the columns
  curve <- x_inf + (x_0 - x_inf) / (1 + (10^log_conc / ec50)^h)
  rowMeans(pmin(pmax(curve, 0), 1))
}
