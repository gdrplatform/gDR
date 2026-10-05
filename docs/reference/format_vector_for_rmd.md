# Format a Character Vector for RMarkdown Injection

Converts a character vector into a single string formatted for injection
into an RMarkdown template via `whisker`. Each element is quoted and
separated by a comma and a newline to ensure the rendered R code does
not exceed the R console line limit (4096 characters).

## Usage

``` r
format_vector_for_rmd(vec, indent_spaces = 2)
```

## Arguments

- vec:

  Character vector. The vector of strings (e.g., file paths) to format.

- indent_spaces:

  Integer. Number of spaces to indent subsequent lines. Default is 2.

## Value

A single character string.

- If `vec` is NULL, returns "NULL".

- If `vec` contains data, returns a string like:
  `"path1",\n "path2",\n "path3"`
