# Validate and prepare script inputs based on data type

Performs detailed validation and preprocessing of arguments for the
specified data type. This includes checking the contents of annotation
files.

## Usage

``` r
validate_and_prepare_inputs(args, data_type)
```

## Arguments

- args:

  A list of all arguments passed to the main function (with staged
  paths).

- data_type:

  A character string of the data type, as determined by
  `determine_data_type`.

## Value

A list of processed and validated arguments.
