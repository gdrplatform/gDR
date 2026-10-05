# Run a gDR report pipeline

Infrastructure-agnostic driver for the gDR reporting pipeline. It stages
all input files into a self-contained, versioned output directory,
validates them, and renders the requested RMarkdown steps through
`whisker` and `rmarkdown`. The function can process different types of
input data, including QCS ID, PRISM data, and a MultiAssayExperiment
(MAE) object or a path to a `.qs2` file containing an MAE object.

## Usage

``` r
run_report(
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
  feature_sets = c("CRISPRGeneEffect", "OmicsExpressionProteinCodingGenesTPMLogp1",
    "OmicsSomaticMutationsMatrixHotspot", "OmicsSomaticMutationsMatrixDamaging",
    "OmicsCNGene"),
  metadata_columns = c("OncotreeLineage", "PatientRace"),
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
)
```

## Arguments

- qcs_id:

  Character vector. One or more QCS IDs. Provide these if you want to
  process data using QCS IDs.

- long_table:

  Character. Path to a single CSV/TSV file with a tidy 'long table' of
  drug-response data (the same shape as the `data_imported` object).
  Provide this to import tabular data directly, without going through a
  screening system. The file must contain the `Gnumber`, `clid`,
  `Duration`, `Concentration`, and `ReadoutValue` columns (plus optional
  `Gnumber_2`/`Concentration_2` for combinations). See
  [`load_long_table`](https://gdrplatform.github.io/gDRimport/reference/load_long_table.html).

- manifest:

  Character. Path to the manifest file(s). Can be a single path, a
  comma-separated string of paths, or a regular expression pattern to
  match files in a directory (e.g., "/path/to/manifests/\*.xlsx").
  Required if not using `qcs_id` or `prism_data_path`.

- treatment:

  Character. Path to the treatment file(s). Can be a single path, a
  comma-separated string of paths, or a regular expression pattern.
  Required if not using `qcs_id` or `prism_data_path`.

- raw_data:

  Character. Path to the raw data file(s). Can be a single path, a
  comma-separated string of paths, or a regular expression pattern.
  Required if not using `qcs_id` or `prism_data_path`.

- prism_data_path:

  Character. Path to the PRISM data file. Provide this if you want to
  process PRISM data.

- cell_line_data_path:

  Character. Path to the cell line data file. Required if using
  `prism_data_path` and processing PRISM level 6 data.

- treatment_data_path:

  Character. Path to the treatment data file. Required if using
  `prism_data_path` and processing PRISM level 6 data.

- drug_annotation_path:

  Character. Path to the drug annotation CSV file. This param can be
  used for using custom annotations for drugs. Annotation file for drugs
  should contain `Gnumber`, `DrugName`, and `drug_moa` columns.

- cell_line_annotation_path:

  Character. Path to the cell line annotation CSV file. This param can
  be used for using custom annotations for cell lines. Annotation file
  for cell line should contain `clid`, `CellLineName`, `Tissue`,
  `ReferenceDivisionTime`, `subtype`, and `parental_identifier` columns.

- meta_data_path:

  Character. Path to metadata file describing all cancer models/cell
  lines which are referenced by a dataset contained within the DepMap
  portal. It is usually a file named `Model.csv`. Required if using
  `prism_data_path`

- feat_data_path:

  Character. Path to the directory containing of the molecular feature
  set files to load from DepMap.

- feature_sets:

  Character. Vector containing the names of the molecular feature sets
  to load from DepMap. These names should also correspond to the file
  names containing the feature data in `feat_data_path` (without the
  extension, which is assumed to be `csv`) Required if using
  `special_sections` equal `"PRISM"`

- metadata_columns:

  Character. Metadata names from file pointed by `meta_data_path`
  Required if using `special_sections` equal `"PRISM"`

- output_dir:

  Character. Directory to store reports and output data. This is a
  required parameter.

- viz_format:

  Character. Format for visualizations. Default is `"svg"`.

- rmd_template_path:

  Character vector. One or more directories holding the RMarkdown
  templates. Directories are searched in order and the first match wins,
  so a deployment can both override individual templates and supply
  steps that the other directories do not carry (for instance a
  publication step living outside the open-source template set). This is
  a required parameter.

- steps:

  Integer vector. Steps to run in the pipeline: 1: data import, 2:
  processing and QC, 3: analysis, 4: publish results. Default is `1:3`.
  Note: If `mae` is provided, steps 1 and 2 are automatically skipped.

- mae:

  MultiAssayExperiment or Character. A MultiAssayExperiment object or a
  path to a `.qs2` file containing a MultiAssayExperiment object.

- special_sections:

  String or NULL. Provide this if you want to process data, type PRISM
  or chemical genomics, starting from `mae` to see a section specific to
  them. One of: "PRISM", "chemical_genomics".

- verbose_mode:

  Logical. Whether to generate a detailed report, including detailed
  visualizations by cell line name and drug name. This also affects the
  output directory naming.

- with_decoding:

  logical whether the feature OmicsArmLevelCNA,
  OmicsSomaticMutationsMatrixHotspot and
  OmicsSomaticMutationsMatrixDamaging should be encoded into a 0-1
  scheme

- dpi:

  number defining dpi of all images in report

- embed:

  Logical. Whether to generate a self-contained HTML report.

- configuration_file_path:

  Character. Path to the configuration file. Currently, required only
  for Incucyte data

- remove_on_failure:

  Logical. Whether to remove the output directory if the pipeline fails.
  Default is `TRUE`. If set to `FALSE`, incomplete output will be kept
  for debugging.

- resume:

  Logical. Whether to resume execution in the existing 'current' output
  directory instead of creating a new version. Default is `FALSE`.

- extra_render_params:

  Named list. Additional parameters injected into every RMarkdown
  template alongside the ones derived from the arguments above. Use it
  to pass values that are specific to a given deployment (e.g. dataset
  registry metadata) without adding them to the signature of this
  function. Values are also persisted in `args.qs2`. Names colliding
  with parameters computed by this function are dropped with a warning.
  Default is an empty list.

- on_resolve_inputs:

  Function or NULL. Hook called before the data type is determined, used
  to resolve input paths from an external source. It receives `args`
  (the list of input arguments) and `extra_render_params`, and must
  return a list with exactly these two elements, which then replace the
  originals. Only the fields describing the inputs themselves (e.g.
  `manifest`, `treatment`, `raw_data`) may be rewritten; rewriting any
  of the run-control arguments (`output_dir`, `rmd_template_path`,
  `steps`, `verbose_mode`, `resume`, `remove_on_failure`) raises an
  error. This is a hard boundary rather than a convenience check:
  rewriting `steps` would change what the run actually renders and could
  append the publication step behind the back of the caller that decided
  which steps to run. Default is `NULL` (no resolution).

- on_start:

  Function or NULL. Hook called once the output directory exists but
  before any rendering starts, e.g. to notify the user that the run
  began. It receives `output_dir`. Errors raised by this hook abort the
  run. Default is `NULL`.

- on_before_render:

  Function or NULL. Hook called after the data type is determined and
  before any file is staged, e.g. to verify connectivity to external
  services. It receives `data_type`. Errors raised by this hook abort
  the run. Default is `NULL`.

- on_success:

  Function or NULL. Hook called after all steps rendered successfully,
  e.g. to publish the results or notify the user. It receives
  `output_dir`. Errors raised by this hook are caught and reported as a
  warning, so that a failing notification cannot discard an otherwise
  successful run. Default is `NULL`.

- on_failure:

  Function or NULL. Hook called when the run fails, before the output
  directory is cleaned up, e.g. to notify the user. It receives
  `output_dir` and `error_message`. Errors raised by this hook are
  caught and reported as a message. Default is `NULL`.

## Value

None. The function generates reports and saves them to the specified
output directory.

## Details

Every integration with external infrastructure (dataset registries,
notification systems, authentication, service health checks) is
delegated to optional hooks, so that the driver itself only depends on
`checkmate`, `qs2`, `whisker`, `rmarkdown` and the open-source gDR
packages. See `run_gDR_with_report()` for a wrapper that supplies these
hooks for a specific deployment.

The report templates shipped in `inst/report_templates` additionally
attach `gDRplots` when they are rendered. That package is deliberately
absent from `Suggests`: it is not released on CRAN or Bioconductor yet,
and an unresolvable soft dependency breaks dependency resolution for
everything that installs this package. Install it from
<https://github.com/gdrplatform/gDRplots> before rendering the bundled
templates, or point `rmd_template_path` at templates that do not need
it.

**By default, if the pipeline fails at any point, it will automatically
clean up by removing the output directory it created for the run. This
can be disabled for debugging.**

## Examples

``` r
if (FALSE) { # \dontrun{
templates <- "path/to/report_templates"

# Standard run from bench files (Runs steps 1-3)
run_report(
  manifest = "path/to/manifest.xlsx",
  treatment = "path/to/treatments.xlsx",
  raw_data = "path/to/plate1.xlsx,path/to/plate2.xlsx",
  output_dir = "~/test_report",
  rmd_template_path = templates
)

# Run from a pre-existing MAE object
run_report(
  mae = "path/to/mae.qs2",
  output_dir = "~/test_report_mae",
  rmd_template_path = templates
)

# Run with a hook notified before rendering starts
run_report(
  manifest = "path/to/manifest.xlsx",
  treatment = "path/to/treatments.xlsx",
  raw_data = "path/to/plate1.xlsx",
  output_dir = "~/test_report_hooked",
  rmd_template_path = templates,
  on_before_render = function(data_type) message("About to render ", data_type)
)

# Assemble the template set from two directories: the first one wins, so it can both
# override individual steps and contribute steps the shared set does not carry.
run_report(
  mae = "path/to/mae.qs2",
  output_dir = "~/test_report_layered",
  rmd_template_path = c("path/to/deployment_templates", templates),
  steps = 3
)
} # }
```
