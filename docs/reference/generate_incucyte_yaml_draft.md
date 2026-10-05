# Generate a Draft YAML Configuration for Incucyte Analysis

Automatically creates a boilerplate YAML configuration file based on the
processed input data. It provides working example groupings for
`treatment_comparisons` and a commented-out dictionary of all available
treatment names.

## Usage

``` r
generate_incucyte_yaml_draft(
  dt,
  out_file,
  early_period = c(24, 48),
  late_period = c(120, 144)
)
```

## Arguments

- dt:

  data.table; The preprocessed data.table (e.g., after import).

- out_file:

  character; Path where the draft YAML should be saved.

- early_period:

  numeric vector of length 2; Default c(24, 48).

- late_period:

  numeric vector of length 2; Default c(120, 144).

## Value

Invisible path to the generated file.
