# Apply Custom Metadata Tags to Drug Names

Finds custom metadata columns by convention (e.g., 'drug_time',
'drug3_washout') and appends their values as tags to the corresponding
DrugName column.

## Usage

``` r
apply_custom_metadata_tags(dt)
```

## Arguments

- dt:

  data.table; The input data.table containing drug names and custom
  metadata.

## Value

A modified data.table with tags appended to the relevant drug name
columns.
