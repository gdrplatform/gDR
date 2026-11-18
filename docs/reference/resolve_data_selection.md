# Resolve the data selections of the analysis step

Checks the form of the data selections in `extra_render_params`. The
names themselves are checked against the data by
[`select_report_data()`](https://gdrplatform.github.io/gDR/reference/select_report_data.md).

## Usage

``` r
resolve_data_selection(extra_render_params)
```

## Arguments

- extra_render_params:

  Named list of deployment-specific render parameters.

## Value

Named list of the data selections that are set.
