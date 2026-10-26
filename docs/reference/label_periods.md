# Display labels for the growth-rate periods of the Incucyte analysis

Display labels for the growth-rate periods of the Incucyte analysis

## Usage

``` r
label_periods(periods, period_labels = NULL)
```

## Arguments

- periods:

  character; period names defined in the config, a subset of `"early"`,
  `"mid"` and `"late"`.

- period_labels:

  named list or character vector mapping period names to labels, or
  `NULL`. Periods without a label keep their name.

## Value

A character vector of labels named by period.

## Examples

``` r
label_periods(c("early", "late"), list(early = "24h", late = "48h"))
#> early  late 
#> "24h" "48h" 
```
