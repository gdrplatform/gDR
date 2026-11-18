# Describe the selections a report is drawn on

Describe the selections a report is drawn on

## Usage

``` r
describe_report_selection(analysis_params, data_selection)
```

## Arguments

- analysis_params:

  List returned by
  [`resolve_analysis_params()`](https://gdrplatform.github.io/gDR/reference/resolve_analysis_params.md).

- data_selection:

  List returned by
  [`resolve_data_selection()`](https://gdrplatform.github.io/gDR/reference/resolve_data_selection.md).

## Value

Character string of one Markdown bullet per narrowing selection, or
`NULL` when the report covers the whole dataset.
