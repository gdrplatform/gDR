# Add Treatment Column to a Data Table

Creates a formatted treatment label from available drug/concentration
columns. It dynamically detects which columns (e.g. `DrugName`,
`DrugName_2`) are present using environment identifiers from `gDRutils`.

## Usage

``` r
add_treatment_column(
  dt,
  control_name = "DMSO",
  vehicle_name = "vehicle",
  unit = "uM"
)
```

## Arguments

- dt:

  data.table; The input data.table.

- control_name:

  character; The name to use when all drugs are vehicles. Default is
  'DMSO'.

- vehicle_name:

  character; The identifier for a vehicle/control substance. Default is
  'vehicle'.

- unit:

  character; The concentration unit to append to the value. Default is
  'uM'.

## Value

A copy of the data.table `dt` with a new "treatment" column.
