# Name the quantity on the growth-rate axis of the Incucyte analysis

The bar panel plots `plot_value`, which is a normalized rate where
`is_normalized` is `TRUE` and a raw one where it is `FALSE`. Periods are
faceted and `normalization_map` gives each period one target, so the
flag is constant within a facet and the two kinds only meet when a
config mixes `"None"` with a reference period. In every other case the
axis names one quantity, and saying so beats naming both.

## Usage

``` r
rate_axis_label(is_normalized, metric = c("NormalizedGrowthRate", "GR"))
```

## Arguments

- is_normalized:

  logical; one value per plotted row, as the analysis derives it from
  `normalization_map`. Only the distinct values matter.

- metric:

  string; the configured `growth_metric`, which decides how a normalized
  rate is named.

## Value

A string for
[`ggplot2::ylab()`](https://ggplot2.tidyverse.org/reference/labs.html).

## Examples

``` r
rate_axis_label(c(TRUE, TRUE), "GR")
#> [1] "GR value"
rate_axis_label(c(FALSE, FALSE), "GR")
#> [1] "Raw log2 growth rate"
rate_axis_label(c(TRUE, FALSE), "GR")
#> [1] "GR value or raw log2 growth rate"
```
