#' Import raw data
#'
#' The one import of the gDR report and of every other caller: it reads any of the
#' supported inputs, cleans the metadata, and annotates drugs and cell lines, returning
#' the raw data that \code{gDRcore::runDrugResponseProcessingPipeline()} processes.
#' \code{run_report()} calls it for step 1, so a caller who imports with it gets the
#' same table as the report.
#'
#' The input type is decided as in \code{run_report()}: a long table if
#' \code{long_table} is given, PRISM level 6 if \code{prism_data_path},
#' \code{cell_line_data_path} and \code{treatment_data_path} are, PRISM level 5 if only
#' \code{prism_data_path} is, and otherwise bench data from the manifest, templates and
#' raw files.
#' \itemize{
#'   \item bench: \code{gDRimport::load_data()} and \code{gDRcore::merge_data()}, which
#'     annotates from \code{cell_line_annotation} and \code{drug_annotation} when given.
#'   \item long table: \code{gDRimport::load_long_table()}, then
#'     \code{gDRcore::cleanup_metadata()}.
#'   \item PRISM level 5 or 6: \code{gDRimport::convert_LEVEL5_prism_to_gDR_input()} or
#'     \code{convert_LEVEL6_prism_to_gDR_input()}, then \code{gDRcore::cleanup_metadata()}.
#' }
#' Then, with \code{annotate = TRUE}, drugs and cell lines are annotated with
#' \code{gDRcore::annotate_dt_with_drug()} and \code{annotate_dt_with_cell_line()}, from
#' the annotation given or, without it, from the annotation the data already carries.
#'
#' @param manifest_file character, file path(s) to manifest(s)
#' @param template_file character, with datapaths and names of results file(s)
#' or character with file path of templates file(s)
#' @param results_file character, with datapaths and names of results file(s)
#' or character with file path of results file(s)
#' @param instrument string with type of instrument used. \code{NULL} (default) detects
#'   it from the first results file with \code{gDRimport::detect_file_format()}.
#' @param cell_line_annotation optional cell line annotation, a \code{data.table} or the
#'   path of a CSV. If \code{NULL} (default), bench data is annotated from gDRinternal or
#'   gDRtestData, and the annotation pass uses the annotation already in the data.
#' @param drug_annotation optional drug annotation, as \code{cell_line_annotation}.
#' @param long_table character, file path(s) of a long table (\code{load_long_table()}).
#' @param prism_data_path,meta_data_path character, the PRISM data and metadata files.
#' @param cell_line_data_path,treatment_data_path character, the PRISM level 6 cell line
#'   and treatment files.
#' @param annotate logical, whether to run the annotation pass. Default \code{TRUE}.
#' @param annotation_dir optional directory in which to write the annotation used, as
#'   \code{drug_annotation.csv} and \code{cell_line_annotation.csv}.
#'
#' @examples
#' td <- get_test_data()
#' i_df <- import_data(manifest_path(td), template_path(td), result_path(td))
#'
#' @return a \code{data.table}, carrying the import record of gDRimport in its
#'   \code{gDR_import} attribute.
#'
#' @keywords import
#' @export
#'
import_data <- function(manifest_file = NULL,
                        template_file = NULL,
                        results_file = NULL,
                        instrument = NULL,
                        cell_line_annotation = NULL,
                        drug_annotation = NULL,
                        long_table = NULL,
                        prism_data_path = NULL,
                        meta_data_path = NULL,
                        cell_line_data_path = NULL,
                        treatment_data_path = NULL,
                        annotate = TRUE,
                        annotation_dir = NULL) {
  checkmate::assert_string(instrument, null.ok = TRUE)
  checkmate::assert_flag(annotate)
  checkmate::assert_string(annotation_dir, null.ok = TRUE)
  cell_line_annotation <- .read_annotation(cell_line_annotation, "cell_line_annotation")
  drug_annotation <- .read_annotation(drug_annotation, "drug_annotation")

  type <- determine_data_type(list(
    long_table = long_table,
    prism_data_path = prism_data_path,
    cell_line_data_path = cell_line_data_path,
    treatment_data_path = treatment_data_path,
    manifest = manifest_file
  ), output_dir = NULL)

  dt <- switch(
    type,
    bench = {
      if (is.null(instrument)) {
        instrument <- gDRimport::detect_file_format(results_file[1])
      }
      loaded_data <- load_data(manifest_file = manifest_file,
                               df_template_files = template_file,
                               results_file = results_file,
                               instrument = instrument)
      merge_data(manifest = loaded_data$manifest,
                 treatments = loaded_data$treatments,
                 data = loaded_data$data,
                 cell_line_annotation = cell_line_annotation,
                 drug_annotation = drug_annotation)
    },
    long_table = .cleanup_keeping_record(gDRimport::load_long_table(long_table)),
    prism_5 = .cleanup_keeping_record(gDRimport::convert_LEVEL5_prism_to_gDR_input(
      prism_data_path = prism_data_path, meta_data_path = meta_data_path
    )),
    prism_6 = .cleanup_keeping_record(gDRimport::convert_LEVEL6_prism_to_gDR_input(
      prism_data_path = prism_data_path,
      cell_line_data_path = cell_line_data_path,
      treatment_data_path = treatment_data_path,
      meta_data_path = meta_data_path
    )),
    stop(sprintf("import_data() does not import '%s' input.", type), call. = FALSE)
  )

  if (annotate) {
    dt <- .annotate_imported(dt, drug_annotation, cell_line_annotation, annotation_dir)
  }
  dt
}


# An annotation given as the path of a CSV is read; a data.frame is used as it is.
#' @keywords internal
.read_annotation <- function(x, what) {
  if (is.null(x) || data.table::is.data.table(x)) {
    return(x)
  }
  if (is.data.frame(x)) {
    return(data.table::as.data.table(x))
  }
  checkmate::assert_string(x, .var.name = what)
  checkmate::assert_file_exists(x, .var.name = what)
  data.table::fread(x)
}


# cleanup_metadata() returns a new table, which drops the import record.
#' @keywords internal
.cleanup_keeping_record <- function(dt) {
  record <- attr(dt, "gDR_import", exact = TRUE)
  dt <- gDRcore::cleanup_metadata(dt)
  data.table::setattr(dt, "gDR_import", record)
  dt
}


# The annotation pass of the report's import: the annotation given, or the one the data
# already carries, applied to drugs and cell lines, and optionally written out.
#' @keywords internal
.annotate_imported <- function(dt, drug_annotation, cell_line_annotation, annotation_dir) {
  record <- attr(dt, "gDR_import", exact = TRUE)
  if (is.null(drug_annotation)) {
    drug_annotation <- gDRcore::get_drug_annotation_from_dt(dt)
  }
  dt <- gDRcore::annotate_dt_with_drug(dt, drug_annotation)
  if (is.null(cell_line_annotation)) {
    cell_line_annotation <- gDRcore::get_cellline_annotation_from_dt(dt)
  }
  dt <- gDRcore::annotate_dt_with_cell_line(dt, cell_line_annotation)
  if (!is.null(annotation_dir)) {
    dir.create(annotation_dir, recursive = TRUE, showWarnings = FALSE)
    data.table::fwrite(drug_annotation, file.path(annotation_dir, "drug_annotation.csv"))
    data.table::fwrite(cell_line_annotation, file.path(annotation_dir, "cell_line_annotation.csv"))
  }
  # the joins in the annotation return new tables; older gDRcore dropped the record there
  data.table::setattr(dt, "gDR_import", record)
  dt
}
