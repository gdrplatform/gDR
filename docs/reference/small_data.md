# Small data.table with raw data used for processing via gDR

A dataset containing the ReadoutValues for single-agent experiments made
up of 10 drugs and 10 cell lines

## Usage

``` r
data(small_data)
```

## Format

A data frame with 3300 rows and 12 variables:

- Barcode:

  barcode

- clid:

  cell line id

- CellLineName:

  cell line name

- Tissue:

  cell line tissue

- ReferenceDivisionTime:

  cell line division time

- Gnumber:

  drug id

- DrugName:

  drug name

- drug_moa:

  drug mode of action

- Concentration:

  drug concentration

- ReadoutValue:

  readout value

- BackgroundValue:

  backgroud value

- Duration:

  duration

## Value

data.table
