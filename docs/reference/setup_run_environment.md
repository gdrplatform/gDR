# Set up the run environment

Creates a versioned output directory and prepares log files for the
pipeline run. The directory name depends on whether the run is in
verbose mode.

## Usage

``` r
setup_run_environment(output_dir, verbose_mode = FALSE, resume = FALSE)
```

## Arguments

- output_dir:

  Character string of the base output directory.

- verbose_mode:

  Logical, indicating if the run is for a verbose report.

- resume:

  Logical, indicating if the run should resume in the existing 'current'
  directory.

## Value

A list containing the path to the versioned output directory
(`output_dir`) and file connections for stdout (`stdout_con`) and stderr
(`stderr_con`).
