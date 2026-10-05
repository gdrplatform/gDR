# Locate template files across a search path

Resolves each file name against a list of template directories, taking
the first directory that carries it. This lets a deployment assemble its
template set from several packages - overriding individual files by
listing its own directory first, and contributing steps the other
directories do not ship at all.

## Usage

``` r
find_template(file_names, template_dirs)
```

## Arguments

- file_names:

  Character vector of file names to locate.

- template_dirs:

  Character vector of directories, searched in order.

## Value

Character vector of the same length as `file_names`, holding the
resolved path for each file or `NA_character_` when no directory carries
it.
