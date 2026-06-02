# Small data.table with raw combo data used for processing via gDR

A dataset containing the ReadoutValues for combo experiments made up of
3 drugs, 2 co-drugs, and 2 cell lines

## Usage

``` r
data(small_combo_data)
```

## Format

A data frame with 3600 rows and 16 variables:

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

- Gnumber_2:

  co-drug id

- DrugName_2:

  co-drug name

- drug_moa_2:

  co-drug mode of action

- Concentration_2:

  co-drug concentration

- ReadoutValue:

  readout value

- BackgroundValue:

  backgroud value

- Duration:

  duration

## Value

data.table
