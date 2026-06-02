# Import raw data

Import raw data

## Usage

``` r
import_data(
  manifest_file,
  template_file,
  results_file,
  instrument = "EnVision"
)
```

## Arguments

- manifest_file:

  character, file path(s) to manifest(s)

- template_file:

  character, with datapaths and names of results file(s) or character
  with file path of templates file(s)

- results_file:

  character, with datapaths and names of results file(s) or character
  with file path of results file(s)

- instrument:

  string with type of instrument used

## Value

a `data.table`

## Examples

``` r
td <- get_test_data()
i_df <- import_data(manifest_path(td), template_path(td), result_path(td))
#> INFO [2026-06-02 11:40:17] Manifest loaded successfully
#> INFO [2026-06-02 11:40:17] Reading Template_7daytreated.xlsx with load_templates_xlsx
#> INFO [2026-06-02 11:40:17] Reading Template_Untreated.xlsx with load_templates_xlsx
#> INFO [2026-06-02 11:40:17] Loading Template_7daytreated.xlsx
#> INFO [2026-06-02 11:40:17] Loading Template_Untreated.xlsx
#> INFO [2026-06-02 11:40:17] Templates loaded successfully!
#> INFO [2026-06-02 11:40:17] Reading file /home/runner/work/_temp/Library/gDRimport/extdata/data1/RawData_day0.xlsx, sheet Readout_0077vs0068_day7
#> New names:
#> • `` -> `...1`
#> • `` -> `...2`
#> • `` -> `...3`
#> • `` -> `...4`
#> • `` -> `...5`
#> • `` -> `...6`
#> • `` -> `...7`
#> • `` -> `...8`
#> • `` -> `...9`
#> • `` -> `...10`
#> • `` -> `...11`
#> • `` -> `...12`
#> • `` -> `...13`
#> • `` -> `...14`
#> • `` -> `...15`
#> • `` -> `...16`
#> • `` -> `...17`
#> • `` -> `...18`
#> • `` -> `...19`
#> • `` -> `...20`
#> • `` -> `...21`
#> • `` -> `...22`
#> • `` -> `...23`
#> • `` -> `...24`
#> • `` -> `...25`
#> INFO [2026-06-02 11:40:17] Plate 201904190a read; 384 wells
#> INFO [2026-06-02 11:40:17] Plate 201904190b read; 384 wells
#> INFO [2026-06-02 11:40:17] Plate 201904190c read; 384 wells
#> INFO [2026-06-02 11:40:17] Plate 201904190d read; 384 wells
#> INFO [2026-06-02 11:40:17] Plate 201904190e read; 384 wells
#> INFO [2026-06-02 11:40:17] Plate 201904190f read; 384 wells
#> INFO [2026-06-02 11:40:17] File done
#> INFO [2026-06-02 11:40:17] Reading file /home/runner/work/_temp/Library/gDRimport/extdata/data1/RawData_day7.xlsx, sheet Readout_0077vs0068_day7
#> New names:
#> • `` -> `...1`
#> • `` -> `...2`
#> • `` -> `...3`
#> • `` -> `...4`
#> • `` -> `...5`
#> • `` -> `...6`
#> • `` -> `...7`
#> • `` -> `...8`
#> • `` -> `...9`
#> • `` -> `...10`
#> • `` -> `...11`
#> • `` -> `...12`
#> • `` -> `...13`
#> • `` -> `...14`
#> • `` -> `...15`
#> • `` -> `...16`
#> • `` -> `...17`
#> • `` -> `...18`
#> • `` -> `...19`
#> • `` -> `...20`
#> • `` -> `...21`
#> • `` -> `...22`
#> • `` -> `...23`
#> • `` -> `...24`
#> • `` -> `...25`
#> INFO [2026-06-02 11:40:18] Plate 201904197a read; 384 wells
#> INFO [2026-06-02 11:40:18] Plate 201904197b read; 384 wells
#> INFO [2026-06-02 11:40:18] Plate 201904197c read; 384 wells
#> INFO [2026-06-02 11:40:18] Plate 201904197d read; 384 wells
#> INFO [2026-06-02 11:40:18] Plate 201904197e read; 384 wells
#> INFO [2026-06-02 11:40:18] Plate 201904197f read; 384 wells
#> INFO [2026-06-02 11:40:18] File done
#> INFO [2026-06-02 11:40:18] Merging data
#> INFO [2026-06-02 11:40:18] Merging the metadata (manifest and treatment files)
#> WARN [2026-06-02 11:40:18] 4608 well loaded, 768 wells discarded for lack of annotation, 
#>     3840 data point selected
```
