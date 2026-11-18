# Read the data the analysis step of a run draws

Read the data the analysis step of a run draws

## Usage

``` r
read_report_mae(plan, output_dir)
```

## Arguments

- plan:

  List returned by
  [`prepare_report_steps()`](https://gdrplatform.github.io/gDR/reference/prepare_report_steps.md).

- output_dir:

  Character string of the versioned output directory.

## Value

The MultiAssayExperiment given to the run, or the one its processing
step wrote.
