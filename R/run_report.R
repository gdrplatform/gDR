# Arguments controlling how the run itself is executed, as opposed to which inputs it reads.
# The input-resolution hook is not allowed to touch them, for two different reasons:
#
#  * `output_dir`, `verbose_mode`, `resume` and `remove_on_failure` are already consumed by the
#    time the hook runs (the versioned directory exists and the logs are open), so a rewrite
#    would be silently ignored;
#  * `steps` and `rmd_template_path` are, on the contrary, still live - they travel through
#    stage_and_update_paths() and validate_and_prepare_inputs() and are then written back into
#    this frame by list2env(). A hook rewriting `steps` would therefore really change what gets
#    rendered, and could append step 4, bypassing the publication safety lock implemented by the
#    caller (see run_gDR_with_report()). This check is what keeps that lock effective.
#
# Do not drop this guard on the assumption that it protects against a no-op.
.PROTECTED_RUN_ARGS <- c(
  "output_dir",
  "rmd_template_path",
  "steps",
  "verbose_mode",
  "resume",
  "remove_on_failure"
)

#' Run a gDR report pipeline
#'
#' Infrastructure-agnostic driver for the gDR reporting pipeline. It stages all input files into
#' a self-contained, versioned output directory, validates them, and renders the requested
#' RMarkdown steps through \code{whisker} and \code{rmarkdown}. The function can process
#' different types of input data, including QCS ID, PRISM data, and a MultiAssayExperiment (MAE)
#' object or a path to a \code{.qs2} file containing an MAE object.
#'
#' Every integration with external infrastructure (dataset registries, notification systems,
#' authentication, service health checks) is delegated to optional hooks, so that the driver
#' itself only depends on \code{checkmate}, \code{qs2}, \code{whisker}, \code{rmarkdown} and the
#' open-source gDR packages. See \code{run_gDR_with_report()} for a wrapper that supplies
#' these hooks for a specific deployment.
#'
#' The report templates shipped in \code{inst/report_templates} additionally attach
#' \code{gDRplots} when they are rendered. That package is deliberately absent from
#' \code{Suggests}: it is not released on CRAN or Bioconductor yet, and an unresolvable soft
#' dependency breaks dependency resolution for everything that installs this package. Install it
#' from \url{https://github.com/gdrplatform/gDRplots} before rendering the bundled templates, or
#' point \code{rmd_template_path} at templates that do not need it.
#'
#' **By default, if the pipeline fails at any point, it will automatically clean up by removing the output
#' directory it created for the run. This can be disabled for debugging.**
#'
#' @param qcs_id Character vector. One or more QCS IDs. Provide these if you want to process data using QCS IDs.
#' @param long_table Character. Path to a single CSV/TSV file with a tidy 'long table' of drug-response
#'  data (the same shape as the \code{data_imported} object). Provide this to import tabular data
#'  directly, without going through a screening system. The file must contain the
#'  \code{Gnumber}, \code{clid}, \code{Duration},
#'  \code{Concentration}, and \code{ReadoutValue} columns (plus optional \code{Gnumber_2}/\code{Concentration_2}
#'  for combinations). See \code{\link[gDRimport]{load_long_table}}.
#' @param manifest Character. Path to the manifest file(s). Can be a single path, a comma-separated string of paths,
#'  or a regular expression pattern to match files in a directory (e.g., "/path/to/manifests/*.xlsx").
#'  Required if not using \code{qcs_id} or \code{prism_data_path}.
#' @param treatment Character. Path to the treatment file(s). Can be a single path, a comma-separated string of paths,
#'  or a regular expression pattern. Required if not using \code{qcs_id} or \code{prism_data_path}.
#' @param raw_data Character. Path to the raw data file(s). Can be a single path, a comma-separated string of paths,
#'  or a regular expression pattern. Required if not using \code{qcs_id} or \code{prism_data_path}.
#' @param prism_data_path Character. Path to the PRISM data file. Provide this if you want to process PRISM data.
#' @param cell_line_data_path Character. Path to the cell line data file.
#'  Required if using \code{prism_data_path} and processing PRISM level 6 data.
#' @param treatment_data_path Character. Path to the treatment data file.
#'  Required if using \code{prism_data_path} and processing PRISM level 6 data.
#' @param drug_annotation_path Character. Path to the drug annotation CSV file.
#'  This param can be used for using custom annotations for drugs.
#'  Annotation file for drugs should contain \code{Gnumber}, \code{DrugName}, and \code{drug_moa} columns.
#' @param cell_line_annotation_path Character.  Path to the cell line annotation CSV file.
#'  This param can be used for using custom annotations for cell lines.
#'  Annotation file for cell line should contain \code{clid}, \code{CellLineName}, \code{Tissue},
#'  \code{ReferenceDivisionTime}, \code{subtype}, and \code{parental_identifier} columns.
#' @param meta_data_path Character. Path to metadata file describing all cancer models/cell lines
#'  which are referenced by a dataset contained within the DepMap portal. It is usually a file named \code{Model.csv}.
#'  Required if using \code{prism_data_path}
#' @param feat_data_path Character. Path to the directory containing of the molecular feature set files
#' to load from DepMap.
#' @param feature_sets Character. Vector containing the names of the molecular feature sets to load from DepMap.
#'  These names should also correspond to the file names containing the feature data in \code{feat_data_path}
#'  (without the extension, which is assumed to be \code{csv})
#'  Required if using \code{special_sections} equal \code{"PRISM"}
#' @param metadata_columns Character. Metadata names from file pointed by \code{meta_data_path}
#'  Required if using \code{special_sections} equal \code{"PRISM"}
#' @param output_dir Character. Directory to store reports and output data. This is a required parameter.
#' @param viz_format Character. Format for visualizations. Default is \code{"svg"}.
#' @param rmd_template_path Character vector. One or more directories holding the RMarkdown
#'  templates. Directories are searched in order and the first match wins, so a deployment can
#'  both override individual templates and supply steps that the other directories do not carry
#'  (for instance a publication step living outside the open-source template set).
#'  This is a required parameter.
#' @param steps Integer vector. Steps to run in the pipeline:
#'  1: data import, 2: processing and QC, 3: analysis, 4: publish results.
#'  Default is \code{1:3}. Note: If \code{mae} is provided, steps 1 and 2 are automatically skipped.
#' @param mae MultiAssayExperiment or Character. A MultiAssayExperiment object or a path
#'  to a \code{.qs2} file containing a MultiAssayExperiment object.
#' @param special_sections String or NULL. Provide this if you want to process data, type PRISM or
#'  chemical genomics, starting from \code{mae} to see a section specific to them.
#'  One of: "PRISM", "chemical_genomics".
#' @param verbose_mode Logical. Whether to generate a detailed report, including detailed
#'  visualizations by cell line name and drug name. This also affects the output directory naming.
#' @param with_decoding logical whether the feature OmicsArmLevelCNA, OmicsSomaticMutationsMatrixHotspot
#'  and OmicsSomaticMutationsMatrixDamaging should be encoded into a 0-1 scheme
#' @param dpi number defining dpi of all images in report
#' @param embed Logical. Whether to generate a self-contained HTML report.
#' @param configuration_file_path Character. Path to the configuration file.
#'  Currently, required only for Incucyte data
#' @param remove_on_failure Logical. Whether to remove the output directory if the
#'   pipeline fails. Default is \code{TRUE}. If set to \code{FALSE}, incomplete
#'   output will be kept for debugging.
#' @param resume Logical. Whether to resume execution in the existing 'current' output directory
#'   instead of creating a new version. Default is \code{FALSE}.
#' @param extra_render_params Named list. Additional parameters injected into every RMarkdown
#'   template alongside the ones derived from the arguments above. Use it to pass values that are
#'   specific to a given deployment (e.g. dataset registry metadata) without adding them to the
#'   signature of this function. Values are also persisted in \code{args.qs2}. Names colliding
#'   with parameters computed by this function are dropped with a warning. Default is an empty list.
#' @param on_resolve_inputs Function or NULL. Hook called before the data type is determined,
#'   used to resolve input paths from an external source. It receives \code{args} (the list of
#'   input arguments) and \code{extra_render_params}, and must return a list with exactly these
#'   two elements, which then replace the originals. Only the fields describing the inputs
#'   themselves (e.g. \code{manifest}, \code{treatment}, \code{raw_data}) may be rewritten;
#'   rewriting any of the run-control arguments (\code{output_dir}, \code{rmd_template_path},
#'   \code{steps}, \code{verbose_mode}, \code{resume}, \code{remove_on_failure}) raises an error.
#'   This is a hard boundary rather than a convenience check: rewriting \code{steps} would change
#'   what the run actually renders and could append the publication step behind the back of the
#'   caller that decided which steps to run. Default is \code{NULL} (no resolution).
#' @param on_start Function or NULL. Hook called once the output directory exists but before any
#'   rendering starts, e.g. to notify the user that the run began. It receives \code{output_dir}.
#'   Errors raised by this hook abort the run. Default is \code{NULL}.
#' @param on_before_render Function or NULL. Hook called after the data type is determined and
#'   before any file is staged, e.g. to verify connectivity to external services. It receives
#'   \code{data_type}. Errors raised by this hook abort the run. Default is \code{NULL}.
#' @param on_success Function or NULL. Hook called after all steps rendered successfully, e.g. to
#'   publish the results or notify the user. It receives \code{output_dir}. Errors raised by this
#'   hook are caught and reported as a warning, so that a failing notification cannot discard an
#'   otherwise successful run. Default is \code{NULL}.
#' @param on_failure Function or NULL. Hook called when the run fails, before the output directory
#'   is cleaned up, e.g. to notify the user. It receives \code{output_dir} and \code{error_message}.
#'   Errors raised by this hook are caught and reported as a message. Default is \code{NULL}.
#'
#' @return None. The function generates reports and saves them to the specified output directory.
#' @keywords report
#' @export
#' @examples
#'
#' \dontrun{
#' templates <- "path/to/report_templates"
#'
#' # Standard run from bench files (Runs steps 1-3)
#' run_report(
#'   manifest = "path/to/manifest.xlsx",
#'   treatment = "path/to/treatments.xlsx",
#'   raw_data = "path/to/plate1.xlsx,path/to/plate2.xlsx",
#'   output_dir = "~/test_report",
#'   rmd_template_path = templates
#' )
#'
#' # Run from a pre-existing MAE object
#' run_report(
#'   mae = "path/to/mae.qs2",
#'   output_dir = "~/test_report_mae",
#'   rmd_template_path = templates
#' )
#'
#' # Run with a hook notified before rendering starts
#' run_report(
#'   manifest = "path/to/manifest.xlsx",
#'   treatment = "path/to/treatments.xlsx",
#'   raw_data = "path/to/plate1.xlsx",
#'   output_dir = "~/test_report_hooked",
#'   rmd_template_path = templates,
#'   on_before_render = function(data_type) message("About to render ", data_type)
#' )
#'
#' # Assemble the template set from two directories: the first one wins, so it can both
#' # override individual steps and contribute steps the shared set does not carry.
#' run_report(
#'   mae = "path/to/mae.qs2",
#'   output_dir = "~/test_report_layered",
#'   rmd_template_path = c("path/to/deployment_templates", templates),
#'   steps = 3
#' )
#' }
run_report <- function(
    qcs_id = NULL,
    long_table = NULL,
    manifest = NULL,
    treatment = NULL,
    raw_data = NULL,
    prism_data_path = NULL,
    cell_line_data_path = NULL,
    treatment_data_path = NULL,
    drug_annotation_path = NULL,
    cell_line_annotation_path = NULL,
    meta_data_path = NULL,
    feat_data_path = NULL,
    feature_sets = c(
      "CRISPRGeneEffect",
      "OmicsExpressionProteinCodingGenesTPMLogp1",
      "OmicsSomaticMutationsMatrixHotspot",
      "OmicsSomaticMutationsMatrixDamaging",
      "OmicsCNGene"
    ),
    metadata_columns = c(
      "OncotreeLineage",
      "PatientRace"
    ),
    output_dir,
    viz_format = "svg",
    rmd_template_path,
    steps = seq_len(3),
    mae = NULL,
    special_sections = NULL,
    verbose_mode = FALSE,
    with_decoding = TRUE,
    dpi = 96,
    embed = TRUE,
    configuration_file_path = NULL,
    remove_on_failure = TRUE,
    resume = FALSE,
    extra_render_params = list(),
    on_resolve_inputs = NULL,
    on_start = NULL,
    on_before_render = NULL,
    on_success = NULL,
    on_failure = NULL
) {
  # --- 1. Initial Assertions ---
  checkmate::assert_string(output_dir)
  checkmate::assert_character(rmd_template_path, min.len = 1, any.missing = FALSE)
  checkmate::assert_directory_exists(rmd_template_path)
  checkmate::assert_string(viz_format, pattern = "svg|png")
  checkmate::assert_numeric(steps, lower = 1, upper = 4, any.missing = FALSE)
  checkmate::assert_flag(verbose_mode)
  checkmate::assert_flag(with_decoding)
  checkmate::assert_number(dpi)
  checkmate::assert_flag(embed)
  checkmate::assert_flag(resume)
  checkmate::assert_flag(remove_on_failure)
  checkmate::assert_choice(special_sections, choices = c("PRISM", "chemical_genomics"), null.ok = TRUE)
  checkmate::assert_character(qcs_id, null.ok = TRUE)
  checkmate::assert_character(long_table, null.ok = TRUE)
  checkmate::assert_character(manifest, null.ok = TRUE)
  checkmate::assert_character(treatment, null.ok = TRUE)
  checkmate::assert_character(raw_data, null.ok = TRUE)
  checkmate::assert_character(prism_data_path, null.ok = TRUE)
  checkmate::assert_character(cell_line_data_path, null.ok = TRUE)
  checkmate::assert_character(treatment_data_path, null.ok = TRUE)
  checkmate::assert_character(drug_annotation_path, null.ok = TRUE)
  checkmate::assert_character(cell_line_annotation_path, null.ok = TRUE)
  checkmate::assert_character(meta_data_path, null.ok = TRUE)
  checkmate::assert_character(feat_data_path, null.ok = TRUE)
  checkmate::assert_character(configuration_file_path, null.ok = TRUE)
  checkmate::assert_character(feature_sets, null.ok = TRUE)
  checkmate::assert_character(metadata_columns, null.ok = TRUE)
  checkmate::assert_list(extra_render_params, names = "unique")
  checkmate::assert_function(on_resolve_inputs, null.ok = TRUE)
  checkmate::assert_function(on_start, null.ok = TRUE)
  checkmate::assert_function(on_before_render, null.ok = TRUE)
  checkmate::assert_function(on_success, null.ok = TRUE)
  checkmate::assert_function(on_failure, null.ok = TRUE)
  checkmate::assert(
    checkmate::check_class(mae, "MultiAssayExperiment"),
    checkmate::check_string(mae),
    null.ok = TRUE,
    .var.name = "mae"
  )

  # Everything that is not an input argument of the pipeline itself (hooks, deployment-specific
  # render parameters) must not leak into the argument list handed over to the templates.
  args <- as.list(environment())
  args[c(
    "extra_render_params",
    "on_resolve_inputs",
    "on_start",
    "on_before_render",
    "on_success",
    "on_failure"
  )] <- NULL

  # Pass resume flag to setup_run_environment
  env <- setup_run_environment(args$output_dir, args$verbose_mode, args$resume)

  # Set up shared mutable state accessible from closures (error handler, on.exit).
  state <- new.env(parent = emptyenv())
  state$success <- FALSE
  state$error_for_mail <- NULL
  on.exit({
    if (!state$success) {
      # The failure hook runs before any clean-up, so that it can still read the log files
      # from the output directory.
      if (!is.null(on_failure)) {
        tryCatch({
          on_failure(
            output_dir = env$output_dir,
            error_message = if (!is.null(state$error_for_mail)) state$error_for_mail else "Unknown error"
          )
        }, error = function(e_hook) {
          message(sprintf("Failure hook raised an error: %s", e_hook$message))
        })
      }

      # In RESUME mode, we generally do NOT want to delete the directory on failure
      # as it contains valuable data from previous steps.
      if (!resume && !is.null(env$output_dir) && dir.exists(env$output_dir)) {

        if (remove_on_failure) {
          message(sprintf("\nExecution failed. Removing incomplete output directory: '%s'.", env$output_dir))
          unlink(env$output_dir, recursive = TRUE, force = TRUE)
        } else {
          dmsg <- "\nExecution failed. Keeping incomplete output directory for debugging: '%s'."
          message(sprintf(dmsg, env$output_dir))
        }

      } else if (resume) {
        message("\nExecution failed in RESUME mode. Existing output directory preserved.")
      }
    }
  })

  # The start hook lives inside the tryCatch below so that a failing hook still goes through the
  # regular error path and, above all, still closes the log connections in the `finally` block.
  tryCatch({
    if (!is.null(on_start)) {
      on_start(output_dir = env$output_dir)
    }

    # Log arguments to file
    args_for_logging <- c(args, extra_render_params)
    if (inherits(args_for_logging$mae, "MultiAssayExperiment")) {
      mae_obj <- args_for_logging$mae
      mae_summary <-
        sprintf(
          "MultiAssayExperiment with %d experiments: [%s]",
          length(MultiAssayExperiment::experiments(mae_obj)),
          toString(names(MultiAssayExperiment::experiments(mae_obj)))
        )
      args_for_logging$mae <- mae_summary
    }
    writeLines(c("Function Arguments:", utils::capture.output(print(args_for_logging))), con = env$stdout_con)

    # Capture stdout from main execution block to a file
    utils::capture.output({

      if (!is.null(on_resolve_inputs)) {
        resolved <- on_resolve_inputs(args = args, extra_render_params = extra_render_params)
        checkmate::assert_list(resolved)
        checkmate::assert_names(names(resolved), must.include = c("args", "extra_render_params"))
        checkmate::assert_list(resolved$args)
        checkmate::assert_list(resolved$extra_render_params, names = "unique")

        # Resolving inputs must not change how the run is executed - see .PROTECTED_RUN_ARGS.
        tampered <- Filter(
          function(nm) !identical(resolved$args[[nm]], args[[nm]]),
          .PROTECTED_RUN_ARGS
        )
        if (length(tampered) > 0) {
          stop(sprintf(
            "'on_resolve_inputs' must not modify the run-control argument(s): %s.",
            toString(tampered)
          ))
        }

        args <- resolved$args
        extra_render_params <- resolved$extra_render_params
      }

      data_type <- determine_data_type(args, env$output_dir)

      message("Processing data type: ", data_type)

      # The driver has no importer of its own for screening-system sessions: the import step is
      # supplied as a rendered section through 'extra_render_params'. Without it the step would
      # render empty and the run would fail much later, with nothing pointing at the cause.
      if (data_type == "qcs" && 1 %in% args$steps &&
          is_null_or_empty(extra_render_params$extra_sections_import)) {
        stop(
          "Data type 'qcs' requires the import section to be supplied via ",
          "'extra_render_params$extra_sections_import'; this driver cannot import such data on ",
          "its own. Supply that section from a deployment wrapper."
        )
      }

      if (!is.null(on_before_render)) {
        on_before_render(data_type = data_type)
      }

      # Create subdirectories
      subdirs <- c("tables", "gDR_data", "raw_data", "plots", "data_annotation")
      for (subdir in subdirs) {
        dir.create(file.path(env$output_dir, subdir), showWarnings = FALSE, recursive = TRUE)
      }

      # Stage all input files into their respective directories and update args
      staged_args <- stage_and_update_paths(args, env$output_dir, extra = extra_render_params)

      # Validate inputs using the new, staged paths
      processed_args <- validate_and_prepare_inputs(staged_args, data_type)
      list2env(processed_args, envir = environment())

      is_prism_data <- grepl("prism", data_type) || (!is.null(special_sections) && special_sections == "PRISM")
      generate_prism_section <- !is.null(special_sections) && special_sections == "PRISM"
      generate_chem_gen_section <- !is.null(special_sections) && special_sections == "chemical_genomics"

      # Define all available steps
      all_step_files <- c(
        "1-data_import.Rmd",
        "2-processing_and_QC.Rmd",
        "3-analysis.Rmd",
        "4-publish_results.Rmd"
      )

      # Select requested steps
      rmd_files <- all_step_files[steps]

      if (3 %in% steps) {
        idx <- which(rmd_files == "3-analysis.Rmd")
        if (length(idx) > 0) {
          if (generate_prism_section) {
            rmd_files <- append(rmd_files, "3-1-PRISM_analysis.Rmd", after = idx)
          }
          if (generate_chem_gen_section) {
            # re-find index in case vector shifted
            idx <- which(rmd_files == "3-analysis.Rmd")
            offset <- if (generate_prism_section) 1 else 0
            rmd_files <- append(rmd_files, "3-1-chemical_genomics_analysis.Rmd", after = idx + offset)
          }
        }
      }

      template_paths <- find_template(rmd_files, rmd_template_path)
      output_paths <- file.path(env$output_dir, rmd_files)

      # Not every directory carries every step (the publication step, for one, only exists where
      # publishing is supported), so report a missing template up front instead of letting
      # readLines() fail with a bare 'cannot open file' halfway through the run.
      missing_templates <- rmd_files[is.na(template_paths)]
      if (length(missing_templates) > 0) {
        stop(sprintf(
          "Template(s) not found in %s: %s. The requested step(s) are not available in this installation.",
          toString(sprintf("'%s'", rmd_template_path)),
          toString(missing_templates)
        ))
      }

      logo_src <- find_template("gdr_logo-01.png", rmd_template_path)
      if (!is.na(logo_src)) {
        file.copy(logo_src, file.path(env$output_dir, "gdr_logo-01.png"), overwrite = TRUE)
      } else {
        warning("Warning: 'gdr_logo-01.png' not found in the template directories.
                 The logo may be missing from the compiled HTML reports.")
      }

      mae_path <- if (!is.null(mae)) {
        # Only save MAE if we are running from MAE input, or ensuring data persistence
        # If running full pipeline, Step 2 creates the MAE.
        path <- file.path(env$output_dir, "gDR_data", paste0("gDR_mae", if (!all(steps == 3)) "_input" else "", ".qs2"))
        qs2::qs_save(mae, path)
        path
      }

      # Names already reported as shadowed, so that each one is warned about exactly once.
      warned_shadowed <- character(0)

      for (i in seq_along(template_paths)) {
        message(sprintf("Rendering report step: %s", tools::file_path_sans_ext(basename(template_paths[[i]]))))

        # Start with processed arguments
        render_params <- processed_args

        # Set the correct versioned output_dir for the template
        render_params$output_dir <- env$output_dir


        # --- UPDATE: Format massive lists as multi-line vectors ---
        render_params$manifest <- format_vector_for_rmd(processed_args$manifest)
        render_params$treatment <- format_vector_for_rmd(processed_args$treatment)
        render_params$raw_data <- format_vector_for_rmd(processed_args$raw_data)
        render_params$long_table <- format_vector_for_rmd(processed_args$long_table)

        render_params$feature_sets <- paste0("'", processed_args$feature_sets, "'", collapse = ", ")
        render_params$metadata_columns <- paste0("'", processed_args$metadata_columns, "'", collapse = ", ")

        # Add other dynamic and boolean parameters
        render_params <- c(
          render_params,
          list(
            mae_path = mae_path,
            LONG_TABLE = (data_type == "long_table"),
            gDRimport = (data_type == "bench"),
            PRISM_level5 = (data_type == "prism_5"),
            PRISM_level6 = (data_type == "prism_6"),
            PRISM = is_prism_data,
            PRISM_excluded = !is_prism_data,
            MAE = (data_type == "mae")
          ),
          prepare_dynamic_render_params(data_type, mae, env$output_dir, steps)
        )

        # Deployment-specific parameters never override the ones computed above. Dropping them
        # silently would let a deployment believe its value reached the templates, so warn once
        # per name. The set is recomputed every step because prepare_dynamic_render_params()
        # contributes different fields depending on what the previous steps produced.
        dropped <- setdiff(
          intersect(names(extra_render_params), names(render_params)),
          warned_shadowed
        )
        if (length(dropped) > 0) {
          warning(sprintf(
            "Ignoring 'extra_render_params' entries shadowed by parameters computed by run_report(): %s.",
            toString(dropped)
          ))
          warned_shadowed <- c(warned_shadowed, dropped)
        }
        render_params <- c(
          render_params,
          extra_render_params[setdiff(names(extra_render_params), names(render_params))]
        )

        rendered_content <- whisker::whisker.render(readLines(template_paths[[i]]), render_params)
        writeLines(rendered_content, output_paths[[i]])

        rmarkdown::render(input = output_paths[[i]], output_file = gsub(".Rmd$", ".html", output_paths[[i]]))
      }

    }, file = env$stdout_con)

    # Log session info to file
    writeLines(c("\nSession Info:", utils::capture.output(utils::sessionInfo())), con = env$stdout_con)

    create_symlink_to_current(dirname(env$output_dir), env$output_dir, verbose_mode)

    # Signal that the entire process was successful before running the success hook: everything
    # that produces the report is done, so a failing notification must not trigger the clean-up
    # and discard the results.
    state$success <- TRUE

    # The hook is caught rather than allowed to propagate, and that is a deliberate trade-off.
    # A deployment typically does several things here - publishing, notifying, registering
    # outputs elsewhere - and some of them are, from its point of view, part of the run's
    # contract rather than a courtesy. Letting one of those abort the call would still be
    # misleading: the reports are written, the symlink is in place, and nothing downstream can
    # undo that, so a hard failure would report a run that did not happen. Surfacing it as a
    # warning keeps the failure visible and actionable while the results stay usable.
    #
    # A deployment that needs a step to be able to fail the whole run should do that work
    # before calling run_report(), or check the outcome itself afterwards; the driver cannot
    # tell a broken mail server from a failed registration.
    if (!is.null(on_success)) {
      tryCatch({
        on_success(output_dir = env$output_dir)
      }, error = function(e_hook) {
        warning(sprintf("Success hook raised an error: %s", e_hook$message))
      })
    }

  }, error = function(e) {
    # Log the error and then re-throw it. The stop() call will trigger
    # the on.exit() handler for cleanup.
    full_error_msg <- sprintf("Error during report generation: %s", e$message)
    message(full_error_msg)
    # Attempt to write the error to the log file before it's closed.
    if (exists("env") && !is.null(env$stderr_con) && isOpen(env$stderr_con)) {
      writeLines(c(full_error_msg, utils::capture.output(traceback())), env$stderr_con)
    }
    # Store error message for the on.exit failure email
    state$error_for_mail <- full_error_msg
    stop(e)

  }, finally = {
    # This block is always executed, ensuring that log file connections are closed
    # whether the main block succeeds or fails.
    if (exists("env")) {
      close(env$stdout_con)
      close(env$stderr_con)
    }
  })
}

#' Check if an Object is NULL or Empty
#'
#' This function checks whether a given object is either `NULL` or contains any empty strings.
#'
#' @param x An object to be checked. This can be any R object, but it is typically a vector or list.
#'
#' @return A logical value: `TRUE` if the object is `NULL` or contains any empty strings, `FALSE` otherwise.
#' @keywords internal
is_null_or_empty <- function(x) {
  is.null(x) || any(x == "")
}

#' Split a comma-separated string into a character vector.
#'
#' @param x A single character string or an existing character vector.
#' @return A character vector with trimmed whitespace. If input is not a single string,
#'  it is returned as is.
#' @keywords internal
split_comma_separated_string <- function(x) {
  if (is.character(x) && length(x) == 1 && grepl(",", x)) {
    return(trimws(strsplit(x, ",")[[1]]))
  }
  x
}

#' Resolve a Path Specification
#'
#' Resolves a path specification which can be a single literal path, a comma-separated
#' list of literal paths, or a regular expression pattern matching multiple files.
#'
#' @param path_spec A single character string specifying the path(s).
#' @return A character vector of validated, existing file paths. Returns `NULL` if no
#'   files are found.
#' @keywords internal
resolve_path_spec <- function(path_spec) {
  if (is_null_or_empty(path_spec)) {
    return(NULL)
  }

  checkmate::assert_string(path_spec)

  # Case 1: Comma-separated list of paths
  if (grepl(",", path_spec)) {
    paths <- split_comma_separated_string(path_spec)
    checkmate::assert_file_exists(paths, .var.name = "paths from comma-separated string")
    return(paths)
  }

  # Case 2: Regex pattern
  # A simple check for common regex/glob characters.
  if (grepl("[*?]", path_spec)) {
    dir_path <- dirname(path_spec)
    pattern <- gsub("\\*", "\\.\\*", basename(path_spec))
    checkmate::assert_directory_exists(dir_path)

    files <- list.files(dir_path, pattern = pattern, full.names = TRUE, recursive = FALSE)

    if (length(files) == 0) {
      warning(sprintf("Pattern '%s' did not match any files in directory '%s'.", pattern, dir_path))
      return(NULL)
    }
    return(files)
  }

  # Case 3: A single, literal file path
  checkmate::assert_file_exists(path_spec)
  return(path_spec)
}

#' Set up the run environment
#'
#' Creates a versioned output directory and prepares log files for the pipeline run.
#' The directory name depends on whether the run is in verbose mode.
#'
#' @param output_dir Character string of the base output directory.
#' @param verbose_mode Logical, indicating if the run is for a verbose report.
#' @param resume Logical, indicating if the run should resume in the existing 'current' directory.
#'
#' @return A list containing the path to the versioned output directory (`output_dir`)
#'   and file connections for stdout (`stdout_con`) and stderr (`stderr_con`).
#'
#' @keywords internal
setup_run_environment <- function(output_dir,
                                  verbose_mode = FALSE,
                                  resume = FALSE) {

  checkmate::assert_string(output_dir)
  checkmate::assert_flag(verbose_mode)
  checkmate::assert_flag(resume)

  # Sys.umask is used to change permissions for the current R process
  Sys.umask("002")

  suffix <- if (verbose_mode) "_verbose" else ""

  if (resume) {
    # RESUME MODE: Try to find the existing directory pointed to by 'current'
    current_link <- file.path(output_dir, paste0("current", suffix))

    if (dir.exists(current_link)) {
      # Resolve the symlink to the actual path (e.g. .../v1)
      versioned_dir <- normalizePath(current_link)
      message(sprintf("RESUME MODE: Using existing directory '%s' (via '%s')", versioned_dir, current_link))
    } else {
      stop(sprintf("RESUME MODE FAILED: Could not find '%s'. Cannot resume without a previous run.", current_link))
    }

  } else {
    # STANDARD MODE: Create a new versioned directory
    versioned_dir <- get_next_version_dir(output_dir, verbose_mode)
  }

  log_dir <- file.path(versioned_dir, "logs")

  # Check if the directory exists. If not - it's created.
  # Added showWarnings = TRUE to see system warnings in the bash logs
  msg1a <- "CRITICAL ERROR: Failed to create log directory: '%s'. "
  msg1b <- "Please check write permissions on the parent folder."
  msg1 <- paste0(msg1a, msg1b)
  if (!dir.exists(log_dir)) {
    if (!dir.create(log_dir, showWarnings = TRUE, recursive = TRUE)) {
      stop(sprintf(msg1, log_dir))
    }
  }

  # If resuming, append to logs; otherwise overwrite/create new
  log_mode <- if (resume) "at" else "wt"

  list(
    output_dir = versioned_dir,
    stdout_con = file(file.path(log_dir, "stdout.log"), open = log_mode),
    stderr_con = file(file.path(log_dir, "stderr.log"), open = log_mode)
  )
}

#' Stage input files and update paths
#'
#' Copies all specified input data files/directories into their appropriate
#' subdirectories. For feature data, it only copies files specified in `feature_sets`.
#' It updates the argument list to point to these new locations.
#'
#' @param args A list of arguments passed to the main function.
#' @param output_dir The base output directory where subdirectories are located.
#' @param extra A named list of additional values to persist in `args.qs2` next to `args`.
#'  They are only recorded for provenance and are not staged. Default is an empty list.
#' @return A modified list of arguments with updated, local paths.
#' @keywords internal
stage_and_update_paths <- function(args, output_dir, extra = list()) {
  raw_data_dir <- file.path(output_dir, "raw_data")
  data_annotation_dir <- file.path(output_dir, "data_annotation")

  # Handle the special case of feature sets first (as it's a directory)
  if (!is.null(args$feat_data_path)) {
    original_path <- args$feat_data_path
    checkmate::assert_directory_exists(original_path)
    new_feat_dir <- file.path(raw_data_dir, basename(original_path))
    dir.create(new_feat_dir, showWarnings = FALSE)

    args$feature_sets <- split_comma_separated_string(args$feature_sets)

    all_files_in_source <- list.files(original_path, full.names = TRUE, recursive = FALSE)
    available_features <- tools::file_path_sans_ext(basename(all_files_in_source))

    sets_to_stage <- intersect(args$feature_sets, available_features)
    missing_sets <- setdiff(args$feature_sets, sets_to_stage)

    if (length(missing_sets) > 0) {
      warning(sprintf(
        "The following feature sets were not found in '%s' and will be ignored: %s",
        original_path, toString(missing_sets)
      ))
    }

    if (length(sets_to_stage) > 0) {
      files_to_copy <- all_files_in_source[available_features %in% sets_to_stage]
      file.copy(files_to_copy, new_feat_dir, overwrite = TRUE)

      args$feature_sets <- sets_to_stage
      args$feat_data_path <- new_feat_dir
      message(sprintf("Staged %d feature set file(s) to '%s'", length(sets_to_stage), new_feat_dir))
    } else {
      warning("No valid feature source files found. Unsetting 'feature_sets' and 'feat_data_path'.")
      args$feature_sets <- NULL
      args$feat_data_path <- NULL
    }
  }

  # Now, handle all other path arguments which can be file specs
  path_args <- c(
    "manifest", "treatment", "raw_data", "long_table", "prism_data_path",
    "cell_line_data_path", "treatment_data_path", "drug_annotation_path",
    "cell_line_annotation_path", "meta_data_path", "configuration_file_path",
    "mae"
  )

  for (arg_name in path_args) {
    path_spec <- args[[arg_name]]
    # 'mae' may be an in-memory MultiAssayExperiment rather than a file path;
    # only path-like (character) specs are resolved and staged here
    if (!is.character(path_spec)) {
      next
    }
    if (!is_null_or_empty(path_spec)) {
      # NEW: Resolve the path specification to a vector of file paths
      original_paths <- resolve_path_spec(path_spec)

      if (is_null_or_empty(original_paths)) {
        args[[arg_name]] <- NULL # Unset arg if no files were found
        next
      }

      dest_dir <- if (arg_name %in% c(
        "drug_annotation_path",
        "cell_line_annotation_path",
        "cell_line_data_path",
        "treatment_data_path"
      )) {
        data_annotation_dir
      } else {
        raw_data_dir
      }

      # NEW: Copy all resolved files and update argument to a vector of new paths
      new_paths <- file.path(dest_dir, basename(original_paths))
      file.copy(original_paths, new_paths, overwrite = TRUE)

      args[[arg_name]] <- new_paths
      message(sprintf("Staged %d file(s) for '%s' to '%s'", length(new_paths), arg_name, dest_dir))
    }
  }
  # Persist the full provenance (pipeline arguments plus any deployment-specific values),
  # but only return the pipeline arguments themselves.
  qs2::qs_save(c(args, extra[setdiff(names(extra), names(args))]), file.path(raw_data_dir, "args.qs2"))
  return(args)
}

#' Determine the data type from provided arguments
#'
#' Identifies the data source type (e.g., "qcs", "prism", "mae") based on the primary input arguments.
#'
#' @param args A list of all arguments passed to the main function.
#' @param output_dir Character string with the directory holding a previous run's output. Reports
#' write into a versioned `vN` subdirectory, so this must be the versioned directory returned by
#' `setup_run_environment()` rather than the unversioned `args$output_dir`, which never contains
#' `gDR_data/`.
#'
#' @return A character string representing the determined data type.
#'
#' @keywords internal
determine_data_type <- function(args, output_dir = args$output_dir) {
  checkmate::assert_list(args)
  checkmate::assert_string(output_dir, null.ok = TRUE)

  if (!is_null_or_empty(args$qcs_id)) {
    "qcs"
  } else if (!is_null_or_empty(args$long_table)) {
    "long_table"
  } else if (!is_null_or_empty(args$prism_data_path)) {
    if (!is_null_or_empty(args$cell_line_data_path) && !is_null_or_empty(args$treatment_data_path)) {
      "prism_6"
    } else {
      "prism_5"
    }
  } else if (!is.null(args$mae)) {
    "mae"
  } else if (!is_null_or_empty(args$manifest)) {
    if (!is_null_or_empty(args$configuration_file_path)) {
      "incucyte"
    } else {
      "bench"
    }
  } else {

    if (!is.null(output_dir) &&
          (file.exists(file.path(output_dir, "gDR_data", "gDR_input.qs2")) ||
             file.exists(file.path(output_dir, "gDR_data", "gDR_mae.qs2")))) {
      "existing"
    } else {
      stop("No valid input source provided. Please specify 'qcs_id', ",
           "'long_table', 'prism_data_path', 'mae', or 'manifest' files.")
    }
  }
}

#' Validate and prepare script inputs based on data type
#'
#' Performs detailed validation and preprocessing of arguments for the specified data type.
#' This includes checking the contents of annotation files.
#'
#' @param args A list of all arguments passed to the main function (with staged paths).
#' @param data_type A character string of the data type, as determined by `determine_data_type`.
#'
#' @return A list of processed and validated arguments.
#'
#' @keywords internal
validate_and_prepare_inputs <- function(args, data_type) {
  checkmate::assert_list(args)
  checkmate::assert_string(data_type)

  checkmate::assert_numeric(args$steps, lower = 1, upper = 4, any.missing = FALSE)
  if (!all(diff(args$steps) == 1)) {
    # If using resume or just step 4, contiguous check might fail if steps > 1.
    if (length(args$steps) > 1 && !all(diff(args$steps) == 1)) {
       stop("Steps must be a valid contiguous sequence (e.g. 1:3) or a single step.")
    }
  }

  # Type-specific validation and processing
  switch(
    data_type,
    "qcs" = {
      if (!is_null_or_empty(args$manifest) || !is_null_or_empty(args$prism_data_path)) {
        stop("Provide either 'qcs_id' or other files, not both.")
      }
      args$qcs_id <- split_comma_separated_string(args$qcs_id)
      checkmate::assert_character(args$qcs_id, min.len = 1)
    },
    "long_table" = {
      if (!is_null_or_empty(args$manifest) || !is_null_or_empty(args$treatment) ||
            !is_null_or_empty(args$raw_data) || !is_null_or_empty(args$prism_data_path) ||
            !is_null_or_empty(args$qcs_id)) {
        stop("Provide either 'long_table' or other input files, not both.")
      }
      checkmate::assert_character(args$long_table, min.len = 1, max.len = 1)
      checkmate::assert_file_exists(args$long_table)
    },
    "prism_5" = {
      checkmate::assert_character(args$prism_data_path, min.len = 1, max.len = 1)
      checkmate::assert_character(args$meta_data_path, min.len = 1, max.len = 1)
      checkmate::assert_true(is_null_or_empty(args$cell_line_data_path) && is_null_or_empty(args$treatment_data_path))
    },
    "prism_6" = {
      checkmate::assert_character(args$prism_data_path, min.len = 1, max.len = 1)
      checkmate::assert_character(args$meta_data_path, min.len = 1, max.len = 1)
    },
    "mae" = {
      # MAE supports only Analysis (3) and Publishing (4).
      # Import (1) and Processing (2) are irrelevant/impossible.
      # We filter the requested/auto-detected steps to keep only 3 and 4.
      args$steps <- intersect(args$steps, c(3, 4))

      # Safety fallback: if intersection is empty (e.g. user explicitly asked for step 1), default to 3.
      if (length(args$steps) == 0) {
        warning("Invalid steps requested for MAE input. Defaulting to Step 3 (Analysis).")
        args$steps <- 3
      }

      if (is.character(args$mae)) {
        checkmate::assert_file_exists(args$mae)
        tryCatch({
          args$mae <- gDRutils::standardize_mae(qs2::qs_read(args$mae))
        }, error = function(e) {
          stop("Failed to read MAE file: ", e$message)
        })
      }
      checkmate::assert_class(args$mae, "MultiAssayExperiment")
      gDRutils::validate_MAE(args$mae)
    },
    "bench" = {
      checkmate::assert_character(args$manifest, min.len = 1)
      checkmate::assert_character(args$treatment, min.len = 1)
      checkmate::assert_character(args$raw_data, min.len = 1)
    },
    "existing" = {
      # Unreachable: assert_numeric() above rejects a NULL `steps`, so the inference below never
      # runs and `mae_path` is never read. Kept as-is rather than repaired or deleted, because
      # either is a behaviour change beyond the scope of the fix that brought this to light.
      mae_path <- file.path(args$output_dir, "gDR_data", "gDR_mae.qs2")
      if (is.null(args$steps)) {
         # If existing and no steps provided, assume analysis (3)
         # If no mae exists, we probably need step 2
         args$steps <- if (file.exists(mae_path)) 3 else 2:3
      }
    }
  )

  # Process and validate metadata_columns
  if (!is.null(args$meta_data_path)) {
    # It's already staged and validated to exist, so we only expect one file
    checkmate::assert_character(args$meta_data_path, min.len = 1, max.len = 1)
    meta_cols <- names(data.table::fread(args$meta_data_path, nrows = 1))
    args$metadata_columns <- split_comma_separated_string(args$metadata_columns)
    args$metadata_columns <- intersect(args$metadata_columns, meta_cols)
    checkmate::assert_subset(c("ModelID", "CCLEName", "OncotreeLineage", args$metadata_columns), meta_cols)
  }

  # The staging function now handles validation and filtering of feature_sets
  if (!is.null(args$feat_data_path)) {
    checkmate::assert_directory_exists(args$feat_data_path)
  }

  # Validate optional annotation files content
  if (!is.null(args$drug_annotation_path)) {
    checkmate::assert_character(args$drug_annotation_path, min.len = 1, max.len = 1)
    drug_ann <- data.table::fread(args$drug_annotation_path)
    req_cols <- unlist(gDRutils::get_env_identifiers(c("drug", "drug_name", "drug_moa"), simplify = FALSE))
    checkmate::assert_subset(req_cols, names(drug_ann))
  }

  if (!is.null(args$cell_line_annotation_path)) {
    checkmate::assert_character(args$cell_line_annotation_path, min.len = 1, max.len = 1)
    cl_ann <- data.table::fread(args$cell_line_annotation_path)
    req_cols_map <- c(
      cellline = "cellline",
      cellline_name = "cellline_name",
      cellline_tissue = "cellline_tissue",
      cellline_ref_div_time = "cellline_ref_div_time",
      cellline_subtype = "cellline_subtype",
      cellline_parental_identifier = "cellline_parental_identifier"
    )
    req_cols <- unlist(gDRutils::get_env_identifiers(req_cols_map, simplify = FALSE))
    checkmate::assert_subset(req_cols, names(cl_ann))
  }

  # Final check for PRISM special analysis requirements
  if (!is.null(args$special_sections) && args$special_sections == "PRISM") {
    if (is.null(args$feature_sets) && is.null(args$metadata_columns)) {
      stop("For PRISM analysis, provide valid 'feature_sets' or 'metadata_columns'.")
    }
  }

  return(args)
}

#' Prepare dynamic parameters for RMarkdown rendering
#'
#' Calculates parameters that depend on the state of the pipeline (e.g., presence of combo data).
#'
#' @param data_type Character string for the type of data being processed.
#' @param mae A MultiAssayExperiment object, if provided.
#' @param output_dir Character string for the output directory.
#' @param steps A numeric vector of pipeline steps to run.
#'
#' @return A list of dynamic parameters (`has_combo`, `plot_iso`, `plot_GR_values`).
#' @keywords internal
prepare_dynamic_render_params <- function(data_type, mae, output_dir, steps) {
  checkmate::assert_string(data_type)
  checkmate::assert_class(mae, "MultiAssayExperiment", null.ok = TRUE)
  checkmate::assert_string(output_dir)
  checkmate::assert_numeric(steps)

  params <- list()
  input_dt_path <- file.path(output_dir, "gDR_data", "gDR_input.qs2")
  mae_path_final <- file.path(output_dir, "gDR_data", "gDR_mae.qs2")

  if (data_type == "mae" && all(steps == 3)) {
    params$has_combo <-
      gDRutils::get_supported_experiments("combo") %in% names(mae)
    norm_data <-
      gDRutils::convert_se_assay_to_dt(mae[[gDRutils::get_supported_experiments("sa")]], "Normalized")
    params$plot_GR_values <-
      any(!is.na(norm_data[norm_data$normalization_type == "GR", "x"]))
  } else if (file.exists(input_dt_path)) {
    raw_data <- qs2::qs_read(input_dt_path)
    ids <- gDRutils::get_env_identifiers()
    params$has_combo <-
      gDRutils::get_supported_experiments("combo") %in% gDRcore::identify_data_type(raw_data)$type
    params$plot_GR_values <-
      any(raw_data[[ids$duration]] == 0) || any(!is.na(raw_data[[ids$cellline_ref_div_time]]))
  }

  if (file.exists(mae_path_final)) {
    final_mae <- qs2::qs_read(mae_path_final)
    if (gDRutils::get_supported_experiments("combo") %in% names(final_mae)) {
      combo_se <-
        final_mae[[gDRutils::get_supported_experiments("combo")]]
      if ("isobolograms" %in% SummarizedExperiment::assayNames(combo_se)) {
        params$plot_iso <-
          "iso_level" %in% BumpyMatrix::commonColnames(SummarizedExperiment::assay(combo_se, "isobolograms"))
      }
    }
  }
  return(params)
}

#' Get next version directory
#'
#' This function determines the next version directory name based on existing version directories.
#' The naming convention depends on whether the report is verbose.
#'
#' @param base_dir Character. The base directory where version directories are stored.
#' @param verbose_mode Logical, indicating if the run is for a verbose report.
#'
#' @return Character. The path to the next version directory (e.g., `v1` or `v1_verbose`).
#'
#' @examples
#' # Assuming "/path/to/dir" has subdirectories "v1", "v2"
#' # get_next_version_dir("/path/to/dir") # Returns "/path/to/dir/v3"
#'
#' @keywords report
#' @export
get_next_version_dir <- function(base_dir, verbose_mode = FALSE) {
  checkmate::assert_string(base_dir)
  checkmate::assert_flag(verbose_mode)

  suffix <- if (verbose_mode) "_verbose" else ""
  pattern <- paste0("^v[0-9]+", suffix, "$")

  version_dirs <- grep(pattern, list.dirs(base_dir, full.names = FALSE, recursive = FALSE), value = TRUE)

  if (length(version_dirs) == 0) {
    next_version_num <- 1
  } else {
    version_numbers <- as.numeric(sub("^v([0-9]+).*", "\\1", version_dirs))
    next_version_num <- max(c(0, version_numbers), na.rm = TRUE) + 1
  }

  file.path(base_dir, paste0("v", next_version_num, suffix))
}

#' Create symbolic link to current version
#'
#' This function creates a symbolic link (`current` or `current_verbose`)
#' that points to the latest version directory.
#'
#' @param base_dir Character. The base directory where the symbolic link should be created.
#' @param latest_version Character. The path to the latest version directory.
#' @param verbose_mode Logical, indicating if the run is for a verbose report.
#'
#' @return NULL
#'
#' @examples
#' # Assume "/path/to/dir/v3" is the latest version
#' \dontrun{
#' create_symlink_to_current("/path/to/dir", "/path/to/dir/v3")
#' }
#'
#' @keywords report
#' @export
create_symlink_to_current <- function(base_dir, latest_version, verbose_mode = FALSE) {
  checkmate::assert_directory_exists(base_dir)
  checkmate::assert_directory_exists(latest_version)
  checkmate::assert_flag(verbose_mode)

  suffix <- if (verbose_mode) "_verbose" else ""
  current_link <- file.path(base_dir, paste0("current", suffix))

  if (file.exists(current_link)) {
    file.remove(current_link)
  }
  file.symlink(latest_version, current_link)
}

#' Format a Character Vector for RMarkdown Injection
#'
#' Converts a character vector into a single string formatted for injection into
#' an RMarkdown template via `whisker`. Each element is quoted and separated
#' by a comma and a newline to ensure the rendered R code does not exceed
#' the R console line limit (4096 characters).
#'
#' @param vec Character vector. The vector of strings (e.g., file paths) to format.
#' @param indent_spaces Integer. Number of spaces to indent subsequent lines. Default is 2.
#'
#' @return A single character string.
#'   - If `vec` is NULL, returns "NULL".
#'   - If `vec` contains data, returns a string like: `"path1",\n  "path2",\n  "path3"`
#'
#' @keywords report
#' @keywords internal
format_vector_for_rmd <- function(vec, indent_spaces = 2) {
  if (is.null(vec)) {
    return("NULL")
  }
  indentation <- strrep(" ", indent_spaces)
  paste0('"', vec, '"', collapse = paste0(",\n", indentation))
}


#' Locate template files across a search path
#'
#' Resolves each file name against a list of template directories, taking the first directory
#' that carries it. This lets a deployment assemble its template set from several packages -
#' overriding individual files by listing its own directory first, and contributing steps the
#' other directories do not ship at all.
#'
#' @param file_names Character vector of file names to locate.
#' @param template_dirs Character vector of directories, searched in order.
#'
#' @return Character vector of the same length as `file_names`, holding the resolved path for
#'  each file or `NA_character_` when no directory carries it.
#' @keywords internal
find_template <- function(file_names, template_dirs) {
  checkmate::assert_character(file_names, any.missing = FALSE)
  checkmate::assert_character(template_dirs, min.len = 1, any.missing = FALSE)

  vapply(
    file_names,
    function(file_name) {
      candidates <- file.path(template_dirs, file_name)
      hits <- candidates[file.exists(candidates)]
      if (length(hits) == 0) {
        NA_character_
      } else {
        hits[[1]]
      }
    },
    character(1),
    USE.NAMES = FALSE
  )
}
