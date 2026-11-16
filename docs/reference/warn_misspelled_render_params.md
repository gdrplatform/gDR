# Warn about likely misspelled render parameters

Whisker drops a parameter that no template reads without a word. Most
such entries of `extra_render_params` are read by the hooks of a
deployment, so only a name close to a template parameter is reported, as
the typo it most likely is: one edit away for a name of four to six
characters, two for a longer one, and never for a name of three or
fewer.

## Usage

``` r
warn_misspelled_render_params(extra_render_params, template_paths)
```

## Arguments

- extra_render_params:

  Named list of deployment-specific render parameters.

- template_paths:

  Character vector of the templates of the run.

## Value

`NULL`, invisibly.
