# Prepare dynamic parameters for RMarkdown rendering

Calculates parameters that depend on the state of the pipeline (e.g.,
presence of combo data).

## Usage

``` r
prepare_dynamic_render_params(data_type, mae, output_dir, steps)
```

## Arguments

- data_type:

  Character string for the type of data being processed.

- mae:

  A MultiAssayExperiment object, if provided.

- output_dir:

  Character string for the output directory.

- steps:

  A numeric vector of pipeline steps to run.

## Value

A list of dynamic parameters (`has_combo`, `plot_iso`,
`plot_GR_values`).
