# Selections of the analysis step that a caller can pass through 'extra_render_params'. Each
# lists its allowed values in the order the report draws them; leaving one out keeps all of them,
# which is the report as it was before the selections existed.
.ANALYSIS_CHOICES <- list(
  norm_types = c("GR", "RV"),
  sa_metrics = c("xc50", "x_max", "x_mean", "x_AOC", "x_AOC_range"),
  combo_score_metrics = c("hsa_score", "bliss_score"),
  plots_to_generate = c(
    "sa_drc_by_drug", "sa_drc_by_cl", "sa_heatmap", "sa_boxplot_cl", "sa_boxplot_drug", "sa_boxplot_tissue",
    "combo_drc", "combo_metrics_panel", "combo_isoref", "combo_heatmap", "combo_boxplot_cl",
    "combo_boxplot_drug", "combo_boxplot_tissue"
  )
)

# Effect level of the isobolograms when none is selected.
.DEFAULT_ISO_LEVELS <- "0.5"

# Formats the assay tables can be written in; the workbook alone when none is selected.
.TABLE_FORMATS <- c("xlsx", "csv")
.DEFAULT_TABLE_FORMAT <- "xlsx"

#' Resolve the selections of the analysis step
#'
#' Validates the analysis selections in \code{extra_render_params} and fills in the ones left out.
#'
#' @param extra_render_params Named list of deployment-specific render parameters.
#'
#' @return Named list with one character vector per selection.
#' @keywords internal
resolve_analysis_params <- function(extra_render_params) {
  checkmate::assert_list(extra_render_params, names = "unique")

  params <- lapply(stats::setNames(nm = names(.ANALYSIS_CHOICES)), function(nm) {
    choices <- .ANALYSIS_CHOICES[[nm]]
    value <- extra_render_params[[nm]]
    if (is.null(value)) {
      return(choices)
    }
    checkmate::assert_character(value, min.len = 1, any.missing = FALSE, .var.name = nm)
    checkmate::assert_subset(value, choices, .var.name = nm)
    intersect(choices, value)
  })

  iso_levels <- extra_render_params$iso_levels
  if (is.null(iso_levels)) {
    iso_levels <- .DEFAULT_ISO_LEVELS
  }
  checkmate::assert_atomic_vector(iso_levels, min.len = 1, any.missing = FALSE, .var.name = "iso_levels")
  checkmate::assert_numeric(suppressWarnings(as.numeric(iso_levels)), lower = 0, upper = 1,
                            any.missing = FALSE, .var.name = "iso_levels")
  params$iso_levels <- as.character(iso_levels)

  table_format <- extra_render_params$table_format
  if (is.null(table_format)) {
    table_format <- .DEFAULT_TABLE_FORMAT
  }
  checkmate::assert_character(table_format, min.len = 1, any.missing = FALSE, .var.name = "table_format")
  checkmate::assert_subset(table_format, .TABLE_FORMATS, .var.name = "table_format")
  params$table_format <- intersect(.TABLE_FORMATS, table_format)

  # the GR sections of the template reuse objects that its RV sections create
  if (!"RV" %in% params$norm_types) {
    stop("'norm_types' must include \"RV\"; the report can leave out GR, not RV.", call. = FALSE)
  }

  params
}

#' Section flags of the analysis step
#'
#' @param analysis_params List returned by \code{resolve_analysis_params()}.
#' @param plot_GR_values Logical or NULL; whether the data has GR values.
#'
#' @return Named list of logical flags: \code{show_<section>} for every section of
#'   \code{plots_to_generate}, \code{show_sa_fitted_metrics} and \code{show_combo_fitted_metrics}
#'   for the headings over them, \code{plot_GR}, and \code{table_<format>} for every format of
#'   \code{table_format}.
#' @keywords internal
analysis_section_flags <- function(analysis_params, plot_GR_values) {
  sections <- .ANALYSIS_CHOICES$plots_to_generate
  shown <- sections %in% analysis_params$plots_to_generate
  flags <- as.list(stats::setNames(shown, paste0("show_", sections)))
  flags$show_sa_fitted_metrics <- any(shown[grepl("^sa_(heatmap|boxplot)", sections)])
  flags$show_combo_fitted_metrics <- any(shown[grepl("^combo_(heatmap|boxplot)", sections)])
  flags$plot_GR <- isTRUE(plot_GR_values) && "GR" %in% analysis_params$norm_types
  flags[paste0("table_", .TABLE_FORMATS)] <- as.list(.TABLE_FORMATS %in% analysis_params$table_format)
  flags
}
