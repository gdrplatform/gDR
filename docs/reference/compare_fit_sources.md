# Compare the fits of two fit sources

Pairs every fit of `other` (e.g. the curves PRISM delivered, added by
[`gDRcore::add_PRISM_metrics()`](https://gdrplatform.github.io/gDRcore/reference/add_PRISM_metrics.html))
with the fit of `reference` in the same cell of the `Metrics` assay, and
summarizes how close they are. A cell can hold several fits of `other`
(PRISM fits one curve per pool and compound plate); each one is paired
with the single `reference` fit of the cell.

## Usage

``` r
compare_fit_sources(
  se,
  other,
  reference = "gDR",
  normalization_type = "RV",
  params = c("auc", "ec50", "x_inf"),
  metrics_assay = "Metrics",
  averaged_assay = "Averaged"
)
```

## Arguments

- se:

  `SummarizedExperiment` with a `Metrics` assay holding both fit
  sources.

- other:

  Character string, the fit source compared with `reference`.

- reference:

  Character string, the fit source it is compared with.

- normalization_type:

  Character string, the normalization type of the fits.

- params:

  Character vector, the parameters compared: `"auc"` or columns of the
  `Metrics` assay.

- metrics_assay:

  Character string, name of the assay with the fits.

- averaged_assay:

  Character string, name of the assay giving the concentration range of
  each cell.

## Value

A list with `pairs`, a `data.table` with one row per fit of `other`: the
drug, cell line and Duration, the columns that tell fits of one cell
apart, and every parameter of both sources (`<param>_<source>`), and
`ec50_in_range`; and `summary`, a `data.table` with one row per
parameter: the number of pairs, the Spearman correlation, and the median
and 95th percentile of the absolute difference; and `n_unpaired`, the
number of fits of `other` in a cell with no `reference` fit, which are
not in `pairs`.

## Details

Two sources can describe the same curve with different parameters (gDR
fixes `x_0` at 1 for relative viability and gives a flat curve
`ec50 = 0`), so the curves are compared by `auc`: computed from the
parameters of each fit as PRISM defines AUC, the mean of the curve,
clamped between 0 and 1, over log10 concentration between the lowest and
highest concentration of the cell in `averaged_assay`. The parameters of
the curve shape (`ec50`, `x_inf`, `x_0`, `h`) are compared only for
pairs where both fits have their `ec50` within that range
(`ec50_in_range`), where the data define them; `ec50` is compared on the
log10 scale. A pair counts for a parameter only when both values are
finite, so failed fits are left out of its summary.

## Examples

``` r
mae <- gDRutils::get_synthetic_data("finalMAE_small")
se <- mae[[gDRutils::get_supported_experiments("sa")]]
# a copy of the gDR fits under another fit source
metrics <- gDRutils::convert_se_assay_to_dt(se, "Metrics", include_metadata = FALSE)
#> Loading required namespace: BumpyMatrix
metrics$fit_source <- "copy"
se <- gDRutils::persist_fit_assay(se, metrics, merge = "merge", assay_name = "Metrics",
                                  row = "rId", col = "cId",
                                  upsert_key_cols = c("fit_source", "normalization_type"))
compare_fit_sources(se, other = "copy")$summary
#>      parameter n_pairs spearman median_abs_diff p95_abs_diff
#>         <char>   <int>    <num>           <num>        <num>
#> 1:         auc     100        1               0            0
#> 2: log10(ec50)      98        1               0            0
#> 3:       x_inf      98        1               0            0
```
