# Write the RMarkdown documents of a gDR report without rendering them

Does everything
[`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md)
does up to the render call: it creates the versioned output directory,
stages and validates the inputs, and writes the parameterised `.Rmd` of
each requested step into that directory. The documents are
self-contained, so rendering one with
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html)
gives the same report as
[`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md).
Use it to inspect or edit a report before a long render, or to render it
elsewhere.

## Usage

``` r
build_report_rmd(
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
  rmd_template_path = system.file("report_templates", package = "gDR"),
  steps = seq_len(3),
  mae = NULL,
  special_sections = NULL,
  verbose_mode = FALSE,
  with_decoding = TRUE,
  dpi = 96,
  embed = TRUE,
  configuration_file_path = NULL,
  resume = FALSE,
  extra_render_params = list(),
  on_resolve_inputs = NULL
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

  Character. Directory in which a new versioned run directory is
  created, or with `resume = TRUE` the run directory to write into.

- viz_format:

  Character. Format for visualizations, `"svg"` (the default) or
  `"png"`.

- rmd_template_path:

  Character vector. One or more directories holding the RMarkdown
  templates. Directories are searched in order and the first match wins,
  so a deployment can both override individual templates and supply
  steps that the other directories do not carry (for instance a
  publication step living outside the open-source template set). Default
  is the templates shipped with gDR.

- steps:

  Integer vector. Steps to write, within `1:3`: 1: data import, 2:
  processing and QC, 3: analysis. Default is `1:3`. If `mae` is
  provided, steps 1 and 2 are skipped.

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

- resume:

  Logical. Whether `output_dir` is an existing run directory to write
  into, e.g. `dirname(rmd[[1]])` or the `current` link of a
  [`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md)
  run. Default is `FALSE`.

- extra_render_params:

  Named list. Additional parameters injected into every RMarkdown
  template alongside the ones derived from the arguments above. Use it
  to pass values that are specific to a given deployment (e.g. dataset
  registry metadata) without adding them to the signature of this
  function. Values are also persisted in `args.qs2`. Names colliding
  with parameters computed by this function are dropped with a warning.
  One entry is read by the templates themselves: `report_inputs_file`,
  the path to a qs2 file with a named list of plain data describing the
  inputs of the run, which the processing step records as the `"report"`
  step in the provenance of every experiment. Others select what the
  analysis step draws. Leave one out to keep all its choices; there is
  no `"all"` value:

  - `sa_metrics`: single-agent metrics of the heatmaps and boxplots,
    from `"xc50"`, `"x_max"`, `"x_mean"`, `"x_AOC"`, `"x_AOC_range"`;

  - `combo_score_metrics`: combination scores of the heatmaps and
    boxplots, from `"hsa_score"`, `"bliss_score"`;

  - `iso_levels`: effect levels of the isobolograms, from -1 to 0.8,
    default `"0.5"`; a level the data does not have draws no isoline and
    is warned about;

  - `norm_types`: normalization types, `"RV"` alone leaves out the GR
    sections;

  - `plots_to_generate`: sections of the report, from
    `"sa_drc_by_drug"`, `"sa_drc_by_cl"`, `"sa_heatmap"`,
    `"sa_boxplot_cl"`, `"sa_boxplot_drug"`, `"sa_boxplot_tissue"`,
    `"combo_drc"`, `"combo_metrics_panel"`, `"combo_isoref"`,
    `"combo_heatmap"`, `"combo_boxplot_cl"`, `"combo_boxplot_drug"`,
    `"combo_boxplot_tissue"`;

  - `table_format`: formats of the assay tables, `"xlsx"` (a workbook
    per experiment type, the default) and `"csv"` (a file per experiment
    type and assay); `c("xlsx", "csv")` writes both, `"csv"` alone
    writes no assay workbook. The data of the heatmaps is always a
    workbook, with a CSV of its `matrix` sheet for `"csv"`.

  Others restrict the data the analysis step draws, by name:
  `drugs_of_interest`, `cell_lines_of_interest`, `codrugs_of_interest`,
  `tissues_of_interest`, `moa_of_interest`, and
  `drug_pairs_of_interest`, a list of pairs `c(drug, co-drug)`. A
  combination is kept when either of its drugs is selected, and a pair
  matches in either order. The subset is written to
  `gDR_data/gDR_mae_selection.qs2`, the sections that need data it no
  longer has are left out, and the analysis step lists the selections at
  its top. A run that publishes its results (step 4) takes no selection.
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

## Value

Named character vector of the paths of the written `.Rmd` files, in
render order, named after the steps (e.g. `"3-analysis"`).

## Details

Only steps 1 to 3 are written. The publication step publishes when it is
rendered, and the checks that guard it belong to the caller that runs
it, so it is left to
[`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md).

The parameters of a step are partly read from the data that rendering
the previous step writes, so a step is written only once that data is in
the run directory. Write and render one step at a time, passing the run
directory with `resume = TRUE` for the next one, or use
[`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md).
An `mae` input needs only step 3 and is written in one call.

## Examples

``` r
if (FALSE) { # \dontrun{
rmd <- build_report_rmd(
  mae = "path/to/mae.qs2",
  output_dir = "~/test_report_mae"
)
rmarkdown::render(rmd[["3-analysis"]])

# one step at a time
rmd <- build_report_rmd(long_table = "path/to/long_table.csv", output_dir = "~/test_report",
                        rmd_template_path = "path/to/report_templates", steps = 1)
rmarkdown::render(rmd[["1-data_import"]])
rmd <- build_report_rmd(output_dir = dirname(rmd[[1]]), rmd_template_path = "path/to/report_templates",
                        steps = 2, resume = TRUE)
} # }
```
