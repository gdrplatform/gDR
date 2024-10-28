#' Run gDR pipeline with an accompanying report
#'
#' This function runs the gDR pipeline and generates an accompanying report. The function can process different types of input data, including QCS ID, PRISM data, and a MultiAssayExperiment (MAE) object or a path to a `.qs` file containing an MAE object.
#'
#' @param qcs_id Character. The QCS ID. Provide this if you want to process data using a QCS ID.
#' @param output_dir Character. Directory to store reports and output data. This is a required parameter.
#' @param manifest Character. Path to the manifest file. Required if not using `qcs_id` or `prism_data_path`.
#' @param treatment Character. Path to the treatment file. Required if not using `qcs_id` or `prism_data_path`.
#' @param raw_data Character. Path to the raw data file. Required if not using `qcs_id` or `prism_data_path`.
#' @param push_to_DSDB Logical. Whether to push results to DSDB. Default is `FALSE`.
#' @param rmd_template_path Character. Path to the RMarkdown template. Default is the directory of the current R script.
#' @param steps Integer vector. Steps to run in the pipeline (1: data import, 2: processing and QC, 3: analysis). Default is `1:3`. If `mae` is provided, only step 3 will be run.
#' @param prism_data_path Character. Path to the PRISM data file. Provide this if you want to process PRISM data.
#' @param cell_line_data_path Character. Path to the cell line data file. Required if using `prism_data_path` and processing PRISM level 6 data.
#' @param treatment_data_path Character. Path to the treatment data file. Required if using `prism_data_path` and processing PRISM level 6 data.
#' @param viz_format Character. Format for visualizations. Default is `"svg"`.
#' @param mae MultiAssayExperiment or Character. A MultiAssayExperiment object or a path to a `.qs` file containing a MultiAssayExperiment object. If provided, only step 3 will be run and the MAE object will be saved to the `gDR_data` directory.
#' @param special_sections String or NULL. Provide this if you want to process data, type PRISM or chemical genomics, starting from `mae` to see a section specific to them. One of: "PRISM", "chemical_genomics".
#'
#' @return None. The function generates reports and saves them to the specified output directory.
#' @export
#'
#' @examples
#' 
#' \dontrun{
#' run_gDR_with_report("AS-42656", "~/test_report")
#' run_gDR_with_report(mae = "path/to/mae.qs", output_dir = "~/test_report")
#' }
run_gDR_with_report <- function(qcs_id = NULL,
                                manifest = NULL,
                                treatment = NULL,
                                raw_data = NULL,
                                prism_data_path = NULL,
                                cell_line_data_path = NULL,
                                treatment_data_path = NULL,
                                output_dir = getwd(),
                                viz_format = "svg",
                                push_to_DSDB = FALSE,
                                rmd_template_path = system.file("report_templates", package = "gDR"),
                                steps = seq_len(3),
                                mae = NULL,
                                special_sections = NULL) {
  
  dir.create(output_dir, showWarnings = FALSE)
  
  # Validate input & check type of data
  if (!is_null_or_empty(qcs_id)) {
    checkmate::assert_string(qcs_id)
    if (!is_null_or_empty(manifest) || !is_null_or_empty(treatment) || !is_null_or_empty(raw_data) || 
        !is_null_or_empty(prism_data_path) || !is_null_or_empty(cell_line_data_path) || !is_null_or_empty(treatment_data_path)) {
      stop("Provide either qcs_id or other files, but not both.")
    }
    data_type <- "qcs"
  } else if (!is_null_or_empty(prism_data_path)) {
    checkmate::assert_character(prism_data_path)
    if (!is_null_or_empty(manifest) || !is_null_or_empty(treatment) || !is_null_or_empty(raw_data)) {
      stop("Provide either prism_data_path or manifest, treatment, and raw_data.")
    }
    if (!is_null_or_empty(cell_line_data_path) && !is_null_or_empty(treatment_data_path)) {
      checkmate::assert_character(cell_line_data_path)
      checkmate::assert_character(treatment_data_path)
      data_type <- "prism_6"
    } else {
      if (!is_null_or_empty(cell_line_data_path) || !is_null_or_empty(treatment_data_path)) {
        stop("Provide either prism_data_path or the set of prism_data_path, cell_line_data_path, and treatment_data_path.")
      }
      data_type <- "prism_5"
    }
  } else if (!is.null(mae)) {
    if (is.character(mae) && file.exists(mae)) {
      # Attempt to read the file with qs::qread
      tryCatch({
        mae <- qs::qread(mae)
      }, error = function(e) {
        # Stop the function and return an error message if qread fails
        stop("Failed to read the file. Ensure it is a 'qs' formatted file: ", e$message)
      })
    }
    if (!inherits(mae, "MultiAssayExperiment")) {
      stop("The provided mae object is not a valid MultiAssayExperiment.")
    }
    gDRutils::validate_MAE(mae)
    data_type <- "mae"
    steps <- 3  # Only run step 3 for mae object
  } else {
    if (is_null_or_empty(manifest) || is_null_or_empty(treatment) || is_null_or_empty(raw_data)) {
      stop("Provide either qcs_id or manifest, treatment, and raw_data, or prism_data_path.")
    }
    checkmate::assert_character(manifest)
    checkmate::assert_character(treatment)
    checkmate::assert_character(raw_data)
    if (!is_null_or_empty(prism_data_path) || !is_null_or_empty(cell_line_data_path) || !is_null_or_empty(treatment_data_path)) {
      stop("Provide either manifest, treatment, and raw_data or the set of prism_data_path, cell_line_data_path, and treatment_data_path.")
    }
    data_type <- "bench"
  }
  
  message("Processing data type: ", data_type)
  
  # Set const value
  GCSI <- data_type == "qcs"
  gDRimport <- data_type == "bench"
  PRISM_level6 <- data_type == "prism_6"
  PRISM_level5 <- data_type == "prism_5"
  PRISM <- any(PRISM_level6, PRISM_level5) || (!is.null(mae) && special_sections == "PRISM")
  PRISM_excluded <- !PRISM
  
  checkmate::assert_access(output_dir, access = "w")
  checkmate::assert_integerish(steps, lower = 1, upper = 3)
  checkmate::assert_string(special_sections, null.ok = TRUE)
  if (!is.null(special_sections)) checkmate::assert_choice(special_sections, choices = c("PRISM", "chemical_genomics"))
  
  message(paste("Processing data and creating report into: ", output_dir))
  
  dir.create(file.path(output_dir, "xlsx"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "gDR_data"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "raw_data"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "plots"), showWarnings = FALSE)
  
  # Define the parameters
  params <- list(qcs_id = qcs_id,
                 output_dir = output_dir,
                 viz_format = viz_format,
                 push_to_DSDB = push_to_DSDB,
                 manifest = manifest,
                 treatment = treatment,
                 raw_data = raw_data,
                 prism_data_path = prism_data_path,
                 cell_line_data_path = cell_line_data_path,
                 treatment_data_path = treatment_data_path,
                 GCSI = GCSI,
                 gDRimport = gDRimport,
                 PRISM_level5 = PRISM_level5,
                 PRISM_level6 = PRISM_level6,
                 PRISM = PRISM,
                 PRISM_excluded = PRISM_excluded)
  
  file_names <- c("1-data_import.Rmd",
                  "2-processing_and_QC.Rmd",
                  "3-analysis.Rmd")[steps]
  
  template_files <- file.path(rmd_template_path,
                              file_names)
  
  output_files <- file.path(output_dir, file_names)
  
  # If mae object is provided, save it to gDR_data directory
  if (!is.null(mae)) {
    mae_path <- file.path(output_dir, "gDR_data", "gDR_mae.qs")
    qs::qsave(mae, mae_path)
  }
  
  for (file in seq_along(template_files)) {
    
    input_dt_path <- file.path(output_dir, "gDR_data", "gDR_input.qs")
    mae_path <- file.path(output_dir, "gDR_data", "gDR_mae.qs")
    
    has_combo <- NULL
    plot_iso <- NULL
    plot_GR_values <- NULL
    if (file.exists(input_dt_path)) {
      raw_data <- qs::qread(input_dt_path)
      has_combo <- gDRutils::get_supported_experiments("combo") %in% gDRcore::identify_data_type(raw_data)$type
      plot_GR_values <- any(raw_data[[gDRutils::get_env_identifiers("duration")]] == 0) ||
        any(!is.na(raw_data[[gDRutils::get_env_identifiers("cellline_ref_div_time")]]))
    }
    
    if (data_type == "mae") {
      has_combo <- gDRutils::get_supported_experiments("combo") %in% names(mae)
      norm_data <- gDRutils::convert_se_assay_to_dt(mae[[gDRutils::get_supported_experiments("sa")]], "Normalized")
      plot_GR_values <- any(!is.na(norm_data[normalization_type == "GR", "x"]))
    }
    
    plot_iso <- if (file.exists(mae_path) &&
                    gDRutils::get_supported_experiments("combo") %in% names(qs::qread(mae_path))) {
      "iso_level" %in% BumpyMatrix::commonColnames(SummarizedExperiment::assay(qs::qread(mae_path)[[gDRutils::get_supported_experiments("combo")]], "isobolograms"))
    } else {
      NULL
    }
    
    params$has_combo <- has_combo
    params$plot_iso <- plot_iso
    params$plot_GR_values <- plot_GR_values
    
    message(paste(gsub(".Rmd", "", basename(template_files[[file]])), "generation..."))
    
    # Read the template file
    template <- readLines(template_files[[file]])
    
    # Render the template with the parameters
    rendered_content <- whisker::whisker.render(template, params)
    
    # Define the output file name
    output_file <- output_files[[file]]
    
    # Write the rendered content to the new RMarkdown file
    writeLines(rendered_content, output_file)
    
    message(paste("Rendering ", basename(output_file), "..."))
    
    # Run the Rmarkdown and generate HTML report
    rmarkdown::render(input = output_file,
                      output_file = gsub(".Rmd", ".html", output_file))
  }
}


#' Check if an Object is NULL or Empty
#'
#' This function checks whether a given object is either `NULL` or contains any empty strings.
#'
#' @param x An object to be checked. This can be any R object, but it is typically a vector or list.
#'
#' @return A logical value: `TRUE` if the object is `NULL` or contains any empty strings, `FALSE` otherwise.
#'
#' @examples
#' is_null_or_empty(NULL)          # Returns TRUE
#' is_null_or_empty("")            # Returns TRUE
#' is_null_or_empty(c("", "test")) # Returns TRUE
#' is_null_or_empty("test")        # Returns FALSE
#' is_null_or_empty(1:5)           # Returns FALSE
#'
#' @export
is_null_or_empty <- function(x) {
  is.null(x) || any(x == "")
}