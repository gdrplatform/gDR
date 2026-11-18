# Resolve the selections of the analysis step

Validates the analysis selections in `extra_render_params` and fills in
the ones left out.

## Usage

``` r
resolve_analysis_params(extra_render_params)
```

## Arguments

- extra_render_params:

  Named list of deployment-specific render parameters.

## Value

Named list with one character vector per selection.
