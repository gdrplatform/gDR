#' Small data.frame with raw data used for processing via gDR
#'
#' A dataset containing the ReadoutValues for single-agent experiments made-up of 10 drugs
#' and 10 cell lines
#'
#' @format A data frame with 3300 rows and 12 variables:
#' \itemize{
#'   \item{Barcode}
#'   \item{clid}{cell line id}
#'   \item{CellLineName}{cell line name}
#'   \item{Tissue}{cell line tissue}
#'   \item{ReferenceDivisionTime}{cell line division time}
#'   \item{Gnumber}{drug id}
#'   \item{DrugName}{drug name}
#'   \item{drug_moa}{drug mode of action}
#'   \item{Concentration}{drug concentration}
#'   \item{ReadoutValue}{readout value}
#'   \item{BackgroundValue}{backgroud value}
#'   \item{Duration}{duration}
#' }
"small_data"

#' Small data.frame with raw combo data used for processing via gDR
#'
#' A dataset containing the ReadoutValues for combo experiments made-up of 3 drugs,
#' 2 co-drugs, and 2 cell lines
#'
#' @format A data frame with 3600 rows and 16 variables:
#' \itemize{
#'   \item{Barcode}
#'   \item{clid}{cell line id}
#'   \item{CellLineName}{cell line name}
#'   \item{Tissue}{cell line tissue}
#'   \item{ReferenceDivisionTime}{cell line division time}
#'   \item{Gnumber}{drug id}
#'   \item{DrugName}{drug name}
#'   \item{drug_moa}{drug mode of action}
#'   \item{Concentration}{drug concentration}
#'   \item{Gnumber_2}{co-drug id}
#'   \item{DrugName_2}{co-drug name}
#'   \item{drug_moa_2}{co-drug mode of action}
#'   \item{Concentration_2}{co-drug concentration}
#'   \item{ReadoutValue}{readout value}
#'   \item{BackgroundValue}{backgroud value}
#'   \item{Duration}{duration}
#' }
"small_combo_data"

