# Resolve a Path Specification

Resolves a path specification which can be a single literal path, a
comma-separated list of literal paths, or a regular expression pattern
matching multiple files.

## Usage

``` r
resolve_path_spec(path_spec)
```

## Arguments

- path_spec:

  A single character string specifying the path(s).

## Value

A character vector of validated, existing file paths. Returns `NULL` if
no files are found.
