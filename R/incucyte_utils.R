#' Add Treatment Column to a Data Table
#'
#' Creates a formatted treatment label from available drug/concentration columns.
#' It dynamically detects which columns (e.g. `DrugName`, `DrugName_2`) are present
#' using environment identifiers from `gDRutils`.
#'
#' @param dt data.table; The input data.table.
#' @param control_name character; The name to use when all drugs are vehicles. Default is 'DMSO'.
#' @param vehicle_name character; The identifier for a vehicle/control substance. Default is 'vehicle'.
#' @param unit character; The concentration unit to append to the value. Default is 'uM'.
#'
#' @return A copy of the data.table `dt` with a new "treatment" column.
#' @keywords incucyte
#' @export
add_treatment_column <- function(dt,
                                 control_name = "DMSO",
                                 vehicle_name = "vehicle",
                                 unit = "uM") {

  checkmate::assert_data_table(dt)
  checkmate::assert_string(control_name)
  checkmate::assert_string(vehicle_name)
  checkmate::assert_string(unit)

  # Avoid side effects on the original object
  dt <- data.table::copy(dt)

  # Get the column names from the input data.table
  dt_colnames <- names(dt)

  # apply custom metadata tags by convention (drugX_feature)
  dt <- apply_custom_metadata_tags(dt)

  # Get environment identifiers for drugs and concentrations
  # We look for up to 3 drugs/concentrations
  id_keys <- c("drug_name", "drug_name2", "drug_name3",
               "concentration", "concentration2", "concentration3")
  ids <- gDRutils::get_env_identifiers(id_keys, simplify = FALSE)

  # Extract expected identifiers (handling potential missing ones in older gDRutils)
  d_ids <- unlist(ids[grep("^drug_name", names(ids))])
  c_ids <- unlist(ids[grep("^concentration", names(ids))])

  # Dynamically find which drug/concentration columns are present in the data
  # intersect preserves the order of the first argument (our ordered ids)
  drug_cols <- intersect(d_ids, dt_colnames)
  conc_cols <- intersect(c_ids, dt_colnames)

  # Ensure the essential primary columns exist
  primary_drug <- ids[["drug_name"]]
  primary_conc <- ids[["concentration"]]

  if (!all(c(primary_drug, primary_conc) %in% dt_colnames)) {
    stop(sprintf(
      "Error: Input data.table must contain at least '%s' and '%s' columns.",
      primary_drug, primary_conc
    ))
  }

  # Apply the logic for each row using the columns we found
  dt[, treatment := {
    # Get the data for the existing drug/conc columns for the current row
    drugs <- .SD[, drug_cols, with = FALSE]
    concs <- .SD[, conc_cols, with = FALSE]

    valid_treatments <- c()
    # Loop only through the columns that actually exist
    for (j in seq_along(drug_cols)) {
      drug_name <- drugs[[j]]
      concentration <- concs[[j]]

      # Check for valid treatment (not NA and not a vehicle)
      if (!is.na(drug_name) && drug_name != vehicle_name) {
        formatted_str <- paste0(drug_name, " ", round(concentration, 4), unit)
        valid_treatments <- c(valid_treatments, formatted_str)
      }
    }

    # Assemble the final treatment string
    if (length(valid_treatments) == 0) {
      control_name
    } else {
      paste(valid_treatments, collapse = " + ")
    }
  }, by = seq_len(NROW(dt))]

  return(dt)
}

#' Reshape a data.table from long to wide format
#'
#' This function utilizes the powerful dcast function from the data.table package
#' to pivot data. It turns unique values from a specified column into new
#' columns in the output data.table.
#'
#' @param long_data data.table; A data.table in long format.
#' @param id_vars character vector; Column names that uniquely identify each row (e.g. c("CellLineName", "range")).
#' @param col_var character; The column whose unique values will become the new column headers (e.g., "treatment").
#' @param val_var character; The column whose values will fill the cells (e.g., "rate").
#'
#' @return A new data.table in wide format.
#' @keywords incucyte
#' @export
cast_to_wide <- function(long_data,
                         id_vars,
                         col_var,
                         val_var) {

  checkmate::assert_data_table(long_data)
  checkmate::assert_character(id_vars, min.len = 1)
  checkmate::assert_string(col_var)
  checkmate::assert_string(val_var)
  checkmate::assert_subset(c(id_vars, col_var, val_var), names(long_data))

  # Create a copy to avoid side effects and ensure proper reference for dcast
  dt <- data.table::copy(long_data)

  # Construct the formula for dcast dynamically.
  lhs <- paste(id_vars, collapse = " + ")
  formula_str <- paste(lhs, "~", col_var)
  casting_formula <- stats::as.formula(formula_str)

  # Perform the dcast operation.
  wide_dt <- data.table::dcast(dt, casting_formula, value.var = val_var)
  data.table::setDT(wide_dt)

  return(wide_dt)
}

#' Filter Treatments from SummarizedExperiment
#'
#' Filters a SummarizedExperiment object to extract normalized cell counts for specific treatments
#' and formats them into a long data.table for plotting.
#'
#' @param se SummarizedExperiment; The object containing the assay data.
#' @param sel_trt character vector; A list of treatment names to filter and extract.
#'
#' @return A data.table containing columns: treatment, CellCount_norm, CellLineName, and Duration.
#' @keywords incucyte
#' @export
filter_treatments <- function(se, sel_trt) {

  checkmate::assert_class(se, "SummarizedExperiment")
  checkmate::assert_character(sel_trt, min.len = 1)

  normalized_cell_counts <- SummarizedExperiment::assay(se, "NormalizedCellCounts")

  # get cell line name from se metadata using env identifier as key
  clid_key <- gDRutils::get_env_identifiers("cellline_name")
  cell_line_name <- S4Vectors::metadata(se)[[clid_key]]

  # DRY: Calculate total rows once
  n_rows <- length(sel_trt) * length(rownames(se))

  merged_cell_counts_norm <- seq(from = 1, to = n_rows)
  merged_treatment_names <- seq(from = 1, to = n_rows)
  merged_cell_line_names <- seq(from = 1, to = n_rows)
  merged_elapsed <- seq(from = 1, to = n_rows)

  i <- 0
  for (treatment_name in sel_trt) {
    if (!treatment_name %in% colnames(normalized_cell_counts)) {
      warning(sprintf("Treatment '%s' not found in assay data. Skipping.", treatment_name))
      next
    }

    col <- normalized_cell_counts[, treatment_name]
    len_rownames <- length(rownames(se))

    for (j in seq(from = 1, to = len_rownames)) {
      idx <- i + j
      merged_cell_counts_norm[idx] <- col[j]
      merged_treatment_names[idx] <- treatment_name

      # use the retrieved cell line name
      merged_cell_line_names[idx] <- cell_line_name

      merged_elapsed[idx] <- rownames(se)[j]
    }
    i <- i + len_rownames
  }

  sel_av_copy <- data.table::data.table(
    treatment = merged_treatment_names,
    CellCount_norm = merged_cell_counts_norm,
    CellLineName = merged_cell_line_names,
    Duration = merged_elapsed
  )

  # Trim if we skipped any treatments due to warning
  if (i < n_rows) {
    sel_av_copy <- sel_av_copy[seq_len(i)]
  }

  return(sel_av_copy)
}

#' Apply Custom Metadata Tags to Drug Names
#'
#' Finds custom metadata columns by convention (e.g., 'drug_time', 'drug3_washout')
#' and appends their values as tags to the corresponding
#' DrugName column.
#'
#' @param dt data.table; The input data.table containing drug names and custom metadata.
#'
#' @return A modified data.table with tags appended to the relevant drug name columns.
#' @keywords incucyte
#' @export
apply_custom_metadata_tags <- function(dt) {
  checkmate::assert_data_table(dt)
  dt <- data.table::copy(dt)

  candidate_cols <- grep("^drug([0-9]*)_(.+)$", colnames(dt), value = TRUE, ignore.case = TRUE)
  all_standard_ids <- unlist(gDRutils::get_env_identifiers())
  custom_feature_cols <- setdiff(candidate_cols, all_standard_ids)

  if (length(custom_feature_cols) > 0) {
    message("INFO: Applying explicit custom metadata tagger for: ", toString(custom_feature_cols))

    ids <- gDRutils::get_env_identifiers()

    for (col in custom_feature_cols) {
      match <- regmatches(col, regexec("^drug([0-9]*)_(.+)$", col, ignore.case = TRUE))[[1]]

      if (length(match) == 3) {
        level <- match[2]
        id_key <- paste0("drug_name", level)
        target_drug_col <- ids[[id_key]]

        if (!is.null(target_drug_col) && target_drug_col %in% colnames(dt)) {
          valid_rows <- !is.na(dt[[col]]) & as.character(dt[[col]]) != ""

          if (any(valid_rows)) {
            dt[valid_rows & !is.na(get(target_drug_col)),
               (target_drug_col) := paste0(get(target_drug_col), " [", get(col), "]")]
          }
        }
      }
    }
  }

  return(dt)
}

#' Generate a Draft YAML Configuration for Incucyte Analysis
#'
#' Automatically creates a boilerplate YAML configuration file based on the
#' processed input data. It provides working example groupings for `treatment_comparisons`
#' and a commented-out dictionary of all available treatment names.
#'
#' @param dt data.table; The preprocessed data.table (e.g., after import).
#' @param out_file character; Path where the draft YAML should be saved.
#' @param early_period numeric vector of length 2; Default c(24, 48).
#' @param late_period numeric vector of length 2; Default c(120, 144).
#'
#' @return Invisible path to the generated file.
#' @keywords incucyte
#' @export
generate_incucyte_yaml_draft <- function(dt,
                                         out_file,
                                         early_period = c(24, 48),
                                         late_period = c(120, 144)) {

  checkmate::assert_data_table(dt)
  checkmate::assert_string(out_file)

  # 1. Get fully formatted treatment names
  dt_with_names <- add_treatment_column(dt = dt)
  trt <- sort(unique(dt_with_names$treatment))

  # Always ensure DMSO/Vehicle is at the very beginning of the list if it exists
  ctrl_idx <- grep("(?i)^(DMSO|Vehicle)$", trt)
  if (length(ctrl_idx) > 0) {
    ctrl_name <- trt[ctrl_idx[1]]
    trt <- c(ctrl_name, setdiff(trt, ctrl_name))
  } else {
    ctrl_name <- "DMSO" # Fallback if no control is found
    warning(
      "No DMSO/Vehicle control detected in treatment names. ",
      "Falling back to 'DMSO'. The generated groupings may be incorrect."
    )
  }

  # 2. Get cell line names dynamically
  clid_key <- gDRutils::get_env_identifiers("cellline_name")
  if (clid_key %in% colnames(dt)) {
    cl <- sort(unique(dt[[clid_key]]))
  } else {
    cl <- "Unknown_Cell_Line"
    warning(
      "Cell line column '", clid_key, "' not found in data. ",
      "Falling back to 'Unknown_Cell_Line'."
    )
  }

  # 3. Build the YAML content line by line
  current_date <- format(Sys.Date(), "%y%m%d")

  lines <- c(
    sprintf('plot_date: "%s"', current_date),
    "",
    "x_axis_text_show: TRUE",
    "x_axis_text_size: 8",
    "",
    "cell_lines:"
  )

  lines <- c(lines, paste0("- \"", cl, "\""))
  lines <- c(lines, "", "early_period:", paste0("- ", early_period))
  lines <- c(lines, "", "late_period:", paste0("- ", late_period))
  lines <- c(lines, "",
             "normalization_map:",
             "  early: \"early\"",
             "  late: \"late\"",
             "",
             "y_axis_scaling: \"free_y\"",
             "",
             "treatment_comparisons:",
             "  # Below are auto-generated example groupings. Modify them as needed.",
             "  # The full dictionary of available treatments is commented out at the bottom."
  )

  # --- AUTO-GROUPING LOGIC ---
  # Remove control from the pool for grouping
  trt_no_ctrl <- setdiff(trt, ctrl_name)

  # Group 1: Up to 4 first treatments
  group1 <- utils::head(trt_no_ctrl, 4)
  if (length(group1) > 0) {
    lines <- c(lines, "  # Example Plot 1")
    lines <- c(lines, paste0("  - [\"", ctrl_name, "\", ", toString(sprintf("\"%s\"", group1)), "]"))
  }

  # Group 2: Next 4 treatments
  if (length(trt_no_ctrl) > 4) {
    group2 <- utils::head(utils::tail(trt_no_ctrl, -4), 4)
    if (length(group2) > 0) {
      lines <- c(lines, "  # Example Plot 2")
      lines <- c(lines, paste0("  - [\"", ctrl_name, "\", ", toString(sprintf("\"%s\"", group2)), "]"))
    }
  }

  # Fallback if there are no treatments other than control
  if (length(trt_no_ctrl) == 0) {
    lines <- c(lines, paste0("  - [\"", ctrl_name, "\", \"INSERT_TREATMENT_1\"]"))
  }
  # ---------------------------

  j_path <- system.file(package = "gDR", "incucyte_settings.json")
  colors <- gDRutils::get_settings_from_json("default_colors", j_path)
  colors_str <- paste0("  ", toString(sprintf("'%s'", colors)))
  lines <- c(lines, "", "all_colors: [", colors_str, "]")

  lines <- c(lines, "",
             "# ==========================================================",
             "# DICTIONARY OF ALL AVAILABLE TREATMENTS",
             "# Copy-paste these exact strings into your groupings above:",
             "# =========================================================="
  )
  lines <- c(lines, paste0("# \"", trt, "\""))

  # 4. Write to file
  writeLines(lines, out_file)
  message("INFO: Draft YAML config saved to: ", out_file)

  invisible(out_file)
}


#' Resolve the configuration file an Incucyte report reads
#'
#' An Incucyte run either carries a configuration file supplied by the caller, staged into
#' \code{raw_data/} under its own name, or none, in which case the first step generates a draft
#' under a fixed name and that becomes the configuration for the run. This resolves both cases to
#' one existing file, so that a report can never quietly analyse generated defaults while the
#' caller believes their own configuration is in force.
#'
#' @param configuration_file_path string; staged path of the configuration file supplied by the
#'   caller, or \code{""} when none was supplied. Inside a rendered template this is the
#'   \code{configuration_file_path} template value, which renders empty for a run without one.
#' @param output_dir string; versioned output directory of the run.
#' @param default_name string; name of the configuration file the first step generates, looked up
#'   in \code{raw_data/} when the caller supplied none.
#'
#' @return Path of an existing configuration file.
#'
#' @examples
#' \dontrun{
#' resolve_incucyte_config_path("/out/v1/raw_data/my_windows.yml", "/out/v1")
#' resolve_incucyte_config_path("", "/out/v1")
#' }
#'
#' @keywords incucyte
#' @export
resolve_incucyte_config_path <- function(configuration_file_path,
                                         output_dir,
                                         default_name = "time_course_plot_params.yml") {
  checkmate::assert_character(configuration_file_path, max.len = 1, null.ok = TRUE)
  checkmate::assert_string(output_dir)
  checkmate::assert_string(default_name)

  raw_data_dir <- file.path(output_dir, "raw_data")

  if (length(configuration_file_path) == 0 || !nzchar(configuration_file_path)) {
    default_path <- file.path(raw_data_dir, default_name)
    if (!file.exists(default_path)) {
      stop(sprintf(
        paste("No configuration file found for the Incucyte analysis. Expected '%s', which the",
              "data import step generates when a run is started without one. Run that step first,",
              "or pass the configuration explicitly ('configuration_file_path', option -C of",
              "generate_report.sh)."),
        default_path
      ))
    }
    default_path
  } else {
    supplied_path <- configuration_file_path
    if (!file.exists(supplied_path)) {
      # Tolerate a bare file name, so that a rendered report stays runnable after its output
      # directory has been moved.
      supplied_path <- file.path(raw_data_dir, basename(configuration_file_path))
    }
    if (!file.exists(supplied_path)) {
      stop(sprintf(
        paste("The configuration file supplied for this run ('%s') cannot be read, and neither",
              "can a file of that name in '%s', where it should have been staged."),
        configuration_file_path, raw_data_dir
      ))
    }
    supplied_path
  }
}
