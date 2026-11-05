# Selections of the analysis step that a caller can pass through 'extra_render_params'. Each
# lists its allowed values in the order the report draws them; leaving one out keeps all of them,
# which is the report as it was before the selections existed.
.ANALYSIS_CHOICES <- list(
  sa_metrics = c("xc50", "x_max", "x_mean", "x_AOC", "x_AOC_range"),
  combo_score_metrics = c("hsa_score", "bliss_score")
)

# Effect level of the isobolograms when none is selected.
.DEFAULT_ISO_LEVELS <- "0.5"

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

  params
}
