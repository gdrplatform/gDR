# Reshape a data.table from long to wide format

This function utilizes the powerful dcast function from the data.table
package to pivot data. It turns unique values from a specified column
into new columns in the output data.table.

## Usage

``` r
cast_to_wide(long_data, id_vars, col_var, val_var)
```

## Arguments

- long_data:

  data.table; A data.table in long format.

- id_vars:

  character vector; Column names that uniquely identify each row (e.g.
  c("CellLineName", "range")).

- col_var:

  character; The column whose unique values will become the new column
  headers (e.g., "treatment").

- val_var:

  character; The column whose values will fill the cells (e.g., "rate").

## Value

A new data.table in wide format.
