#' Import raw data
#'
#' @param manifest_file character, file path(s) to manifest(s)
#' @param template_file data.frame, with datapaths and names of results file(s)
#' or character with file path of templates file(s)
#' @param results_file data.frame, with datapaths and names of results file(s)
#' or character with file path of results file(s)
#' @param instrument character with type of instrument used
#'
#' @return
#' @export
#'
#' @examples
import_data <- function(manifest_file,
                        template_file,
                        results_file,
                        instrument = "EnVision") {
  loaded_data <- load_data(manifest_file = manifest_file,
                           df_template_files = template_file,
                           results_file = results_file,
                           instrument = instrument)
  merge_data(manifest = loaded_data$manifest,
             treatments = loaded_data$treatments,
             data = loaded_data$data)
}
