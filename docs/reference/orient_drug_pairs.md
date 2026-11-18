# Orient drug pairs as the combination data stores them

A pair given in the other order than the data stores it is turned
around, with a message. A pair that was not tested together stops the
run with the pairs that were.

## Usage

``` r
orient_drug_pairs(pairs, combo_rows, col1, col2)
```

## Arguments

- pairs:

  List of character pairs of `drug_pairs_of_interest`.

- combo_rows:

  List of the row data tables of the combination experiments.

- col1, col2:

  Character strings of the columns of the first and the second drug.

## Value

`pairs`, each in the order of the data.
