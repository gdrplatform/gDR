# Section flags of the analysis step

Section flags of the analysis step

## Usage

``` r
analysis_section_flags(analysis_params, plot_GR_values)
```

## Arguments

- analysis_params:

  List returned by
  [`resolve_analysis_params()`](https://gdrplatform.github.io/gDR/reference/resolve_analysis_params.md).

- plot_GR_values:

  Logical or NULL; whether the data has GR values.

## Value

Named list of logical flags: `show_<section>` for every section of
`plots_to_generate`, `show_sa_fitted_metrics` and
`show_combo_fitted_metrics` for the headings over them, `plot_GR`, and
`table_<format>` for every format of `table_format`.
