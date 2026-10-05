# Determine the data type from provided arguments

Identifies the data source type (e.g., "qcs", "prism", "mae") based on
the primary input arguments.

## Usage

``` r
determine_data_type(args, output_dir = args$output_dir)
```

## Arguments

- args:

  A list of all arguments passed to the main function.

- output_dir:

  Character string with the directory holding a previous run's output.
  Reports write into a versioned `vN` subdirectory, so this must be the
  versioned directory returned by
  [`setup_run_environment()`](https://gdrplatform.github.io/gDR/reference/setup_run_environment.md)
  rather than the unversioned `args$output_dir`, which never contains
  `gDR_data/`.

## Value

A character string representing the determined data type.
