# Write one step of a report run

Expands the template of step `i` of `plan` with its render parameters
and writes the resulting `.Rmd` into the output directory.

## Usage

``` r
write_report_step(plan, i, output_dir, warned_shadowed = character(0))
```

## Arguments

- plan:

  List returned by
  [`prepare_report_steps()`](https://gdrplatform.github.io/gDR/reference/prepare_report_steps.md).

- i:

  Integer index of the step in `plan$rmd_files`.

- output_dir:

  Character string of the versioned output directory.

- warned_shadowed:

  Character vector of `extra_render_params` names already warned about.

## Value

`warned_shadowed` with the names warned about in this step added.
