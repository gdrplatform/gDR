# Resolve the configuration file an Incucyte report reads

An Incucyte run either carries a configuration file supplied by the
caller, staged into `raw_data/` under its own name, or none, in which
case the first step generates a draft under a fixed name and that
becomes the configuration for the run. This resolves both cases to one
existing file, so that a report can never quietly analyse generated
defaults while the caller believes their own configuration is in force.

## Usage

``` r
resolve_incucyte_config_path(
  configuration_file_path,
  output_dir,
  default_name = "time_course_plot_params.yml"
)
```

## Arguments

- configuration_file_path:

  string; staged path of the configuration file supplied by the caller,
  or `""` when none was supplied.

- output_dir:

  string; versioned output directory of the run.

- default_name:

  string; name of the configuration file the first step generates,
  looked up in `raw_data/` when the caller supplied none.

## Value

Path of an existing configuration file.

## Examples

``` r
if (FALSE) { # \dontrun{
resolve_incucyte_config_path("/out/v1/raw_data/my_windows.yml", "/out/v1")
resolve_incucyte_config_path("", "/out/v1")
} # }
```
