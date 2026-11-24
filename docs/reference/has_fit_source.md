# Whether the single-agent fits of an MAE include a fit source

Whether the single-agent fits of an MAE include a fit source

## Usage

``` r
has_fit_source(mae, fit_source)
```

## Arguments

- mae:

  A MultiAssayExperiment object.

- fit_source:

  Character string, the fit source (e.g. `"PRISM"`).

## Value

`TRUE` if the `Metrics` assay of the single-agent experiment has rows of
`fit_source`.
