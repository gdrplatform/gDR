# Stage input files and update paths

Copies all specified input data files/directories into their appropriate
subdirectories. For feature data, it only copies files specified in
`feature_sets`. It updates the argument list to point to these new
locations.

## Usage

``` r
stage_and_update_paths(args, output_dir, extra = list())
```

## Arguments

- args:

  A list of arguments passed to the main function.

- output_dir:

  The base output directory where subdirectories are located.

- extra:

  A named list of additional values to persist in `args.qs2` next to
  `args`. They are only recorded for provenance and are not staged.
  Default is an empty list.

## Value

A modified list of arguments with updated, local paths.
