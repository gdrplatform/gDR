# Get next version directory

This function determines the next version directory name based on
existing version directories. The naming convention depends on whether
the report is verbose.

## Usage

``` r
get_next_version_dir(base_dir, verbose_mode = FALSE)
```

## Arguments

- base_dir:

  Character. The base directory where version directories are stored.

- verbose_mode:

  Logical, indicating if the run is for a verbose report.

## Value

Character. The path to the next version directory (e.g., `v1` or
`v1_verbose`).

## Examples

``` r
# Assuming "/path/to/dir" has subdirectories "v1", "v2"
# get_next_version_dir("/path/to/dir") # Returns "/path/to/dir/v3"
```
