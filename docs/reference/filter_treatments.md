# Filter Treatments from SummarizedExperiment

Filters a SummarizedExperiment object to extract normalized cell counts
for specific treatments and formats them into a long data.table for
plotting.

## Usage

``` r
filter_treatments(se, sel_trt)
```

## Arguments

- se:

  SummarizedExperiment; The object containing the assay data.

- sel_trt:

  character vector; A list of treatment names to filter and extract.

## Value

A data.table containing columns: treatment, CellCount_norm,
CellLineName, and Duration.
