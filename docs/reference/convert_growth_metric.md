# Express normalized growth rates in a chosen growth metric

Express normalized growth rates in a chosen growth metric

## Usage

``` r
convert_growth_metric(ngr, ngr_sd, metric = c("NormalizedGrowthRate", "GR"))
```

## Arguments

- ngr:

  numeric; normalized growth rates, the treated rate divided by the
  control rate.

- ngr_sd:

  numeric; their standard deviations, the same length as `ngr`.

- metric:

  string; `"NormalizedGrowthRate"` returns the input unchanged, `"GR"`
  the GR value `2^ngr - 1` with the standard deviation propagated to
  first order.

## Value

A list with elements `value` and `sd`.

## Examples

``` r
convert_growth_metric(c(1, 0.5, 0), c(0.1, 0.1, 0.1), "GR")
#> $value
#> [1] 1.0000000 0.4142136 0.0000000
#> 
#> $sd
#> [1] 0.13862944 0.09802581 0.06931472
#> 
```
