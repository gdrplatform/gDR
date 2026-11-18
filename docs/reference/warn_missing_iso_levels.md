# Warn about requested isobologram levels the data does not have

gDRplots draws the isolines whose level is one of `iso_levels`; a level
the data does not have draws nothing, without a word.

## Usage

``` r
warn_missing_iso_levels(mae, analysis_params)
```

## Arguments

- mae:

  MultiAssayExperiment the analysis step draws.

- analysis_params:

  List returned by
  [`resolve_analysis_params()`](https://gdrplatform.github.io/gDR/reference/resolve_analysis_params.md).

## Value

`NULL`, invisibly.
