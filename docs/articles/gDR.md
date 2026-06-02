# gDR suite

## Introduction

Over decades, many departments across gRED and Roche have generated
large amounts of drug response screening data using Genentech’s rich
drug compounds inventory. While extensive labor and time has been
invested to generate these data, they are not analyzed in a standardized
manner for meaningful comparison. On one hand, large screens are
performed across many cell lines and drugs in a semi-automated manner.
On the other hand, small-scale studies, which focused on factors that
contribute to sensitivity and resistance to certain therapies, are
generally performed by each individual scientist with limited
automation. These are complementary approaches but were rarely handled
the same way. Commercial softwares are available for analyzing large
datasets, whereas researchers for small-scale datasets often process
data ad hoc through software like PRISM.

Here, we propose a suite of computational tools that enable the
processing, archiving, and visualization of drug response data from any
experiment, regardless of size or experimental design, thus ensuring
reproducibility and implementation of the Findable, Accessible,
Interoperable, and Reusable (F.A.I.R.) principles, with the goal of
making this accessible to the public community.

For now we share a subset of the gDR suite components for pre-processing
and processing the data.

### R Packages

gDR suite consists of a few packages that power our app and make it a
comprehensive tool. All the packages under the gDR umbrella are stored
in the [gDR platform GitHub
organization](https://github.roche.com/gdrplatform/).

We are happy to share with you our packages for importing, processing
and managing gDR data: - gDRimport - gDRcore - gDRutils - gDRtestData

### Data structures

The gDR data model is based on the SummarizedExperiment and BumpyMatrix.
If readers are unfamiliar with these data models, we recommend first
reading [SummarizedExperiment
vignettes](https://bioconductor.org/packages/release/bioc/vignettes/SummarizedExperiment/inst/doc/SummarizedExperiment.html),
followed by the [BumpyMatrix
vignettes](https://www.bioconductor.org/packages/devel/bioc/vignettes/BumpyMatrix/inst/doc/BumpyMatrix.html).
The SummarizedExperiment data structure enables ease of subsetting
within the SummarizedExperiment object, but also provides ease when
trying to correlate drug response data with genomic data, as these data
may jointly stored in a MultiAssayExperiment. The BumpyMatrix allows for
storage of multi-dimensional data while retaining a matrix abstraction.

This data structure is the core data structure that all downstream
processing functions as well as visualization tools operate off of.

### Overview

The gDR suite was designed in a modular manner, such that a user can
jump into the “standard” end-to-end gDR processing pipeline at several
entry points as is suitable for his or her needs. The full pipeline
involves:

          manifest, template(s), raw data
                            |
                            |  1. Aggregating all raw data and metadata
                            |  into a single long table.
                            |
                            V
                  single, long table
                            |
                            |  2. Transforming the long table into
                            |  a SummarizedExperiment object with BumpyMatrix assays
                            |  by specifying what columns belong on rows,
                            |  columns, and nested.
                            |
                            V
              SummarizedExperiment object
              with raw and treated assays
                            |
                            |  3. Normalizing, averaging, and fitting data.
                            |
                            V
              SummarizedExperiment object
              with raw, treated, normalized,
               averaged, and metric assays,
       ready for use by downstream visualization

A user should be able to enter any part of this pipeline as long as they
are able to create the intermediate object (i.e., the individual
manifest, template, and raw data files, or a single, long table, or a
SummarizedExperiment object with Bumpy assays).

## Quick start

### Aggregating raw data and metadata (1)

The gDR suite ultimately requires a single, long merged table containing
both raw data and metadata.

To support a common use case, we provide a convenience function that
takes three objects: manifest, template(s), and raw data to create this
single, long merged table for the user. The manifest contains metadata
on the experimental design, template files specify the drugs and cell
lines used, and the raw data output files obtained from a plate reader
or a scanner.

Exemplary data can be found here:

``` r
library(gDR)
#> Loading required package: gDRcore
#> Loading required package: gDRimport
#> Loading required package: gDRutils
# get test data from gDRimport package
# i.e. paths to manifest, templates and results files
td <- get_test_data()
manifest_path(td)
```

\[1\]
“/home/runner/work/\_temp/Library/gDRimport/extdata/data1/manifest.xlsx”

``` r
template_path(td)
```

\[1\]
“/home/runner/work/\_temp/Library/gDRimport/extdata/data1/Template_7daytreated.xlsx”
\[2\]
“/home/runner/work/\_temp/Library/gDRimport/extdata/data1/Template_Untreated.xlsx”

``` r
result_path(td)
```

\[1\]
“/home/runner/work/\_temp/Library/gDRimport/extdata/data1/RawData_day0.xlsx”
\[2\]
“/home/runner/work/\_temp/Library/gDRimport/extdata/data1/RawData_day7.xlsx”

Using the convenience function `import_data`, the long table is easily
created:

``` r
# Import data
imported_data <-
  import_data(manifest_path(td), template_path(td), result_path(td))
head(imported_data)
```

This function will expect certain “identifiers” that tell the processing
functions which columns in the long table map to certain expected
fields, so that each column is interpreted correctly. For more details
regarding these identifiers, see the “Details” section of
[`?identifiers`](https://gdrplatform.github.io/gDRstyle/reference/identifiers.html).
Use `set_env_identifier` or `set_SE_identifiers` to set up the correct
mappings between the expected fields and your long table column names.

### Transforming data into a SummarizedExperiment (2)

Next, we can transform the long table into our initial
SummarizedExperiment object. To do so, we need to tell the software: -
What should go on rows and columns versus be nested in the assay. -
Which rows in our table to consider as “control” versus “treated” for
normalization. - Which data type should be converted into SE.

We can do so by setting the `untreated_tag` identifier like
`set_env_identifier("untreated_tag" = c("MY_CONTROL_TERMINOLOGY_HERE"))`.
specifying the `nested_keys` argument within `create_and_normalize_SE`
and specifiying `data_type`.

``` r
inl <- prepare_input(imported_data)
#> Warning in .set_nested_confounders(nested_confounders = nested_confounders, : 'Plate' nested confounder(s) is/are not present in the data.
#>     Switching into 'Barcode' nested confounder(s).
detected_data_types <- names(inl$exps)
detected_data_types
#> [1] "combination"  "single-agent"
se <- create_and_normalize_SE(
  inl$df_list[["single-agent"]],
  data_type = "single-agent",
  nested_confounders = inl$nested_confounders)
se
#> class: SummarizedExperiment 
#> dim: 3 6 
#> metadata(3): identifiers experiment_metadata Keys
#> assays(3): RawTreated Controls Normalized
#> rownames(3): G00002_drug_002_moa_A_168 G00004_drug_004_moa_A_168
#>   G00011_drug_011_moa_B_168
#> rowData names(4): Gnumber DrugName drug_moa Duration
#> colnames(6): CL00011_cellline_BA_breast_cellline_BA_unknown_26
#>   CL00012_cellline_CA_breast_cellline_CA_unknown_30 ...
#>   CL00015_cellline_FA_breast_cellline_FA_unknown_42
#>   CL00018_cellline_IB_breast_cellline_IB_unknown_54
#> colData names(6): clid CellLineName ... subtype ReferenceDivisionTime
```

Note that this has created a SummarizedExperiment object with `rowData`,
`colData`, `metadata` and 3 `assays`.

### Averaging and fitting data (3)

Next, we can average and fit the data of interest.

``` r
se <- average_SE(se, data_type = "single-agent")
se <- fit_SE(se, data_type = "single-agent")
```

``` r
se
#> class: SummarizedExperiment 
#> dim: 3 6 
#> metadata(5): identifiers experiment_metadata Keys fit_parameters
#>   .internal
#> assays(5): RawTreated Controls Normalized Averaged Metrics
#> rownames(3): G00002_drug_002_moa_A_168 G00004_drug_004_moa_A_168
#>   G00011_drug_011_moa_B_168
#> rowData names(4): Gnumber DrugName drug_moa Duration
#> colnames(6): CL00011_cellline_BA_breast_cellline_BA_unknown_26
#>   CL00012_cellline_CA_breast_cellline_CA_unknown_30 ...
#>   CL00015_cellline_FA_breast_cellline_FA_unknown_42
#>   CL00018_cellline_IB_breast_cellline_IB_unknown_54
#> colData names(6): clid CellLineName ... subtype ReferenceDivisionTime
```

### runDrugResponseProcessingPipeline

Steps (2) and (3) can be combined into a single step through a
convenience function: `runDrugResponseProcessingPipeline`. Moreover, the
output is `MultiAssayExperiment` object with one experiment per each
detected data type. Currently four data types are supported:
‘single-agent’, ‘cotreatment’, ‘codilution’ and ‘matrix’. The first
three data types are processed via the ‘single-agent’ model while the
‘matrix’ data is processed via the ‘combination’ model.

``` r
# Run gDR pipeline
mae <- runDrugResponseProcessingPipeline(imported_data)
```

``` r
mae
#> A MultiAssayExperiment object of 2 listed
#>  experiments with user-defined names and respective classes.
#>  Containing an ExperimentList class object of length 2:
#>  [1] combination: SummarizedExperiment with 2 rows and 6 columns
#>  [2] single-agent: SummarizedExperiment with 3 rows and 6 columns
#> Functionality:
#>  experiments() - obtain the ExperimentList instance
#>  colData() - the primary/phenotype DataFrame
#>  sampleMap() - the sample coordination DataFrame
#>  `$`, `[`, `[[` - extract colData columns, subset, or experiment
#>  *Format() - convert into a long or wide DataFrame
#>  assays() - convert ExperimentList to a SimpleList of matrices
#>  exportClass() - save data to flat files
```

Note that our final MultiAssayExperiment object can be made up of
multiple experiments with multiple assays:

``` r
names(mae)
#> [1] "combination"  "single-agent"
SummarizedExperiment::assayNames(mae[[1]])
#> [1] "RawTreated"     "Controls"       "Normalized"     "Averaged"      
#> [5] "excess"         "all_iso_points" "isobolograms"   "scores"        
#> [9] "Metrics"
```

Each assay from each experiment can be easily transformed to
`data.table` format using `convert_se_assay_to_dt` function:

``` r
library(kableExtra)
se <- mae[["single-agent"]]
head(convert_se_assay_to_dt(se, "Metrics"))
#>                          rId                                               cId
#>                       <char>                                            <char>
#> 1: G00002_drug_002_moa_A_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#> 2: G00002_drug_002_moa_A_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#> 3: G00004_drug_004_moa_A_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#> 4: G00004_drug_004_moa_A_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#> 5: G00011_drug_011_moa_B_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#> 6: G00011_drug_011_moa_B_168 CL00011_cellline_BA_breast_cellline_BA_unknown_26
#>       x_mean      x_AOC x_AOC_range      xc50      x_max        ec50
#>        <num>      <num>       <num>     <num>      <num>       <num>
#> 1: 0.9157913 0.08420865  0.05733832 7.4683485  0.4225500   5.7741811
#> 2: 0.7420679 0.25793215  0.25820178 4.1712724  0.3065500 100.0000000
#> 3: 0.6675856 0.33241443  0.32656451 0.4942034  0.0260500   0.4793539
#> 4: 0.5092443 0.49075566  0.48159819 0.3199532 -0.4177500   0.5757493
#> 5: 0.3225188 0.67748125          NA      -Inf  0.3225188          NA
#> 6: 0.2600750 0.73992500          NA      -Inf  0.2600750          NA
#>          x_inf   x_0         h        r2         p_value        rss
#>          <num> <num>     <num>     <num>           <num>      <num>
#> 1:  0.14499197     1 1.3311221 0.9199573 0.0001450862960 0.03159935
#> 2: -0.76364407     1 0.2918356 0.7732475 0.0055517820959 0.06111735
#> 3:  0.04254419     1 2.9149107 0.9751992 0.0000024023028 0.04890734
#> 4: -0.48824612     1 1.1597048 0.9858751 0.0000003349268 0.03576754
#> 5:          NA    NA        NA        NA              NA         NA
#> 6:          NA    NA        NA        NA              NA         NA
#>    maxlog10Concentration N_conc  x_sd_avg               fit_type
#>                    <num>  <int>     <num>                 <char>
#> 1:              1.000000      9 0.8794050 DRC3pHillFitModelFixS0
#> 2:              1.000000      9 0.7276889 DRC3pHillFitModelFixS0
#> 3:              1.000000      9 0.7335509 DRC3pHillFitModelFixS0
#> 4:              1.000000      9 0.5983619 DRC3pHillFitModelFixS0
#> 5:             -0.823909      1 0.2540203   DRCTooFewPointsToFit
#> 6:             -0.823909      1 0.3936048   DRCTooFewPointsToFit
#>    normalization_type fit_source Gnumber DrugName drug_moa Duration    clid
#>                <char>     <char>  <char>   <char>   <char>    <num>  <char>
#> 1:                 RV        gDR  G00002 drug_002    moa_A      168 CL00011
#> 2:                 GR        gDR  G00002 drug_002    moa_A      168 CL00011
#> 3:                 RV        gDR  G00004 drug_004    moa_A      168 CL00011
#> 4:                 GR        gDR  G00004 drug_004    moa_A      168 CL00011
#> 5:                 RV        gDR  G00011 drug_011    moa_B      168 CL00011
#> 6:                 GR        gDR  G00011 drug_011    moa_B      168 CL00011
#>    CellLineName Tissue parental_identifier subtype ReferenceDivisionTime
#>          <char> <char>              <char>  <char>                 <num>
#> 1:  cellline_BA breast         cellline_BA unknown                    26
#> 2:  cellline_BA breast         cellline_BA unknown                    26
#> 3:  cellline_BA breast         cellline_BA unknown                    26
#> 4:  cellline_BA breast         cellline_BA unknown                    26
#> 5:  cellline_BA breast         cellline_BA unknown                    26
#> 6:  cellline_BA breast         cellline_BA unknown                    26
```

## Appendix

Once the data is stored in the database, there are multiple ways to
visualize the data depending on the scientific needs. The primary method
to do is through our RShiny visualization tool ‘gDRviz’. Here, users can
search and select experiments present in the database, and use
downstream visualization modules to look at dose response curves,
heatmaps, etc.

## SessionInfo

``` r
sessionInfo()
#> R version 4.6.0 (2026-04-24)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.4 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] kableExtra_1.4.0 gDR_1.11.2       gDRutils_1.10.0  gDRimport_1.10.0
#> [5] gDRcore_1.10.0   BiocStyle_2.40.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] viridisLite_0.4.3           farver_2.1.2               
#>  [3] fastmap_1.2.0               BumpyMatrix_1.20.0         
#>  [5] TH.data_1.1-5               digest_0.6.39              
#>  [7] lifecycle_1.0.5             survival_3.8-6             
#>  [9] magrittr_2.0.5              compiler_4.6.0             
#> [11] rlang_1.2.0                 sass_0.4.10                
#> [13] drc_3.0-1                   tools_4.6.0                
#> [15] plotrix_3.8-14              yaml_2.3.12                
#> [17] data.table_1.18.4           knitr_1.51                 
#> [19] lambda.r_1.2.4              S4Arrays_1.12.0            
#> [21] htmlwidgets_1.6.4           DelayedArray_0.38.2        
#> [23] xml2_1.5.2                  RColorBrewer_1.1-3         
#> [25] abind_1.4-8                 multcomp_1.4-30            
#> [27] BiocParallel_1.46.0         purrr_1.2.2                
#> [29] BiocGenerics_0.58.1         desc_1.4.3                 
#> [31] grid_4.6.0                  stats4_4.6.0               
#> [33] scales_1.4.0                MASS_7.3-65                
#> [35] gtools_3.9.5                MultiAssayExperiment_1.38.0
#> [37] SummarizedExperiment_1.42.0 cli_3.6.6                  
#> [39] mvtnorm_1.4-0               rmarkdown_2.31             
#> [41] ragg_1.5.2                  generics_0.1.4             
#> [43] otel_0.2.0                  rstudioapi_0.18.0          
#> [45] readxl_1.5.0                cachem_1.1.0               
#> [47] stringr_1.6.0               splines_4.6.0              
#> [49] assertthat_0.2.1            parallel_4.6.0             
#> [51] BiocManager_1.30.27         formatR_1.14               
#> [53] cellranger_1.1.0            XVector_0.52.0             
#> [55] matrixStats_1.5.0           vctrs_0.7.3                
#> [57] Matrix_1.7-5                sandwich_3.1-1             
#> [59] jsonlite_2.0.0              carData_3.0-6              
#> [61] bookdown_0.46               car_3.1-5                  
#> [63] IRanges_2.46.0              S4Vectors_0.50.1           
#> [65] Formula_1.2-5               systemfonts_1.3.2          
#> [67] testthat_3.3.2              jquerylib_0.1.4            
#> [69] rematch_2.0.0               glue_1.8.1                 
#> [71] pkgdown_2.2.0               codetools_0.2-20           
#> [73] stringi_1.8.7               futile.logger_1.4.9        
#> [75] GenomicRanges_1.64.0        tibble_3.3.1               
#> [77] pillar_1.11.1               htmltools_0.5.9            
#> [79] Seqinfo_1.2.0               brio_1.1.5                 
#> [81] R6_2.6.1                    textshaping_1.0.5          
#> [83] evaluate_1.0.5              lattice_0.22-9             
#> [85] Biobase_2.72.0              futile.options_1.0.1       
#> [87] backports_1.5.1             bslib_0.11.0               
#> [89] svglite_2.2.2               SparseArray_1.12.2         
#> [91] checkmate_2.3.4             xfun_0.58                  
#> [93] fs_2.1.0                    MatrixGenerics_1.24.0      
#> [95] zoo_1.8-15                  pkgconfig_2.0.3
```
