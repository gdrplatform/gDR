# Names of the selections that narrow the report

Names of the selections that narrow the report

## Usage

``` r
narrowing_selections(analysis_params, data_selection)
```

## Arguments

- analysis_params:

  List returned by
  [`resolve_analysis_params()`](https://gdrplatform.github.io/gDR/reference/resolve_analysis_params.md).

- data_selection:

  List returned by
  [`resolve_data_selection()`](https://gdrplatform.github.io/gDR/reference/resolve_data_selection.md).

## Value

Character vector of the data selections that are set and of the analysis
selections that leave out some of their choices.
