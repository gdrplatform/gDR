# Subset a MultiAssayExperiment to the data selections of the analysis step

Drugs are those of `drugs_of_interest`, of the mechanisms in
`moa_of_interest` and the first drug of each pair in
`drug_pairs_of_interest`; cell lines are those of
`cell_lines_of_interest` and of the tissues in `tissues_of_interest`.
Which drug of a combination is the first one depends on how the screen
was set up, so a combination is kept when either of its drugs is
selected, and when either of them is one of `codrugs_of_interest`. With
`drug_pairs_of_interest`, combinations are restricted to those pairs
instead, matched in either order. Experiments left without data are
dropped.

## Usage

``` r
select_report_data(mae, selection)
```

## Arguments

- mae:

  MultiAssayExperiment.

- selection:

  Named list returned by
  [`resolve_data_selection()`](https://gdrplatform.github.io/gDR/reference/resolve_data_selection.md).

## Value

The subset MultiAssayExperiment.
