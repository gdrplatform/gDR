# Prepare the steps of a report run

Resolves, stages and validates the inputs of a run in its versioned
output directory, and locates the templates of the requested steps.
Everything
[`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md)
does before the first step is written.

## Usage

``` r
prepare_report_steps(
  args,
  extra_render_params,
  output_dir,
  on_resolve_inputs = NULL,
  on_before_render = NULL
)
```

## Arguments

- args:

  Named list of the input arguments of
  [`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md).

- extra_render_params:

  Named list of deployment-specific render parameters.

- output_dir:

  Character string of the versioned output directory.

- on_resolve_inputs, on_before_render:

  Function or NULL, as in
  [`run_report()`](https://gdrplatform.github.io/gDR/reference/run_report.md).

## Value

A list with the validated arguments (`args`), the resolved
`extra_render_params`, `data_type`, `steps`, `mae`, `mae_path`,
`is_prism_data`, and the step files in render order (`rmd_files`) with
their `template_paths` and `output_paths`.
