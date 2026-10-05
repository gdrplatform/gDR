# Create symbolic link to current version

This function creates a symbolic link (`current` or `current_verbose`)
that points to the latest version directory.

## Usage

``` r
create_symlink_to_current(base_dir, latest_version, verbose_mode = FALSE)
```

## Arguments

- base_dir:

  Character. The base directory where the symbolic link should be
  created.

- latest_version:

  Character. The path to the latest version directory.

- verbose_mode:

  Logical, indicating if the run is for a verbose report.

## Examples

``` r
# Assume "/path/to/dir/v3" is the latest version
if (FALSE) { # \dontrun{
create_symlink_to_current("/path/to/dir", "/path/to/dir/v3")
} # }
```
