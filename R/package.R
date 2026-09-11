# fix for the NOTE in R CMD CHECK
# (packages defined in  Depends must have records in NAMESPACE)
#' @importFrom gDRimport load_data
#' @importFrom gDRcore merge_data
#' @importFrom gDRutils fit_curves
#' @importFrom data.table :=

#' @keywords internal
#' @return package help page
"_PACKAGE"
NULL

# data.table columns and symbols referenced by non-standard evaluation
utils::globalVariables(
  c(
    ".SD",
    "treatment"
  ),
  utils::packageName())
