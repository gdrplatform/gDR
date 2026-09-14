test_that("add_treatment_column works as expected", {
  # Data preparation
  dt <- data.table::data.table(
    DrugName = c("DrugA", "DrugB", "Vehicle"),
    Concentration = c(0.5, 1.23456, 0),
    DrugName_2 = c(NA, "DrugC", NA),
    Concentration_2 = c(NA, 5, NA)
  )

  # Run function
  dt_res <- add_treatment_column(dt, control_name = "DMSO_Control", vehicle_name = "Vehicle")


  # Verify formatting (rounding to 4 decimal places + unit)
  expect_equal(dt_res$treatment[1], "DrugA 0.5uM")

  # Verify drug combinations
  expect_equal(dt_res$treatment[2], "DrugB 1.2346uM + DrugC 5uM")

  # Verify control (DrugName == Vehicle -> DMSO_Control)
  expect_equal(dt_res$treatment[3], "DMSO_Control")

  # Error handling - missing required columns
  expect_error(
    add_treatment_column(data.table::data.table(WrongCol = 1)),
    "Input data.table must contain at least"
  )

  # assertions
  expect_true("treatment" %in% names(dt_res))

  # Invalid dt type
  expect_error(add_treatment_column(list(a = 1)), "Assertion on 'dt' failed")

  # Invalid control/vehicle/unit types
  expect_error(add_treatment_column(dt, control_name = 123), "Must be of type 'string'")
  expect_error(add_treatment_column(dt, vehicle_name = NULL), "Must be of type 'string'")
  expect_error(add_treatment_column(dt, unit = 1), "Must be of type 'string'")

  #add_treatment_column handles custom metadata tags (drugX_feature) correctly

  # 1. Prepare mock data.table with a custom feature column "drug3_time"
  # Row 1: no tag (empty string)
  # Row 2: 'late_add' tag
  # Row 3: 'washout' tag (testing NA handling as well)
  mock_dt <- data.table::data.table(
    DrugName = c("DrugA", "DrugA", "DrugA"),
    Concentration = c(0.8, 0.8, 0.8),
    DrugName_3 = c("DrugD", "DrugD", "DrugD"),
    Concentration_3 = c(0.1, 0.5, 0.5),
    drug3_time = c("", "late_add", "washout")
  )

  # We might also want to add NA in the custom column to ensure it doesn't crash
  mock_dt[1, drug3_time := NA_character_]

  # 2. Run the function
  res <- add_treatment_column(mock_dt)

  # 3. Assertions
  expect_true("treatment" %in% colnames(res))

  # Check Row 1: NA/Empty custom metadata should be ignored
  expect_equal(res$DrugName_3[1], "DrugD")
  expect_equal(res$treatment[1], "DrugA 0.8uM + DrugD 0.1uM")

  # Check Row 2: Valid custom metadata should be appended
  expect_equal(res$DrugName_3[2], "DrugD [late_add]")
  expect_equal(res$treatment[2], "DrugA 0.8uM + DrugD [late_add] 0.5uM")

  # Check Row 3: Another valid custom metadata should be appended
  expect_equal(res$DrugName_3[3], "DrugD [washout]")
  expect_equal(res$treatment[3], "DrugA 0.8uM + DrugD [washout] 0.5uM")

  # Check if standard columns (e.g. drug_moa) are correctly ignored by the tagger
  mock_dt_moa <- data.table::data.table(
    DrugName = "DrugA",
    Concentration = 0.8,
    drug_moa = "inhibitor" # This should NOT be picked up as a custom tag
  )
  res_moa <- add_treatment_column(mock_dt_moa)
  expect_equal(res_moa$DrugName[1], "DrugA")
  expect_equal(res_moa$treatment[1], "DrugA 0.8uM")
})

test_that("cast_to_wide works as expected", {
  # Prepare long format data
  long_dt <- data.table::data.table(
    CellLineName = rep(c("CL1", "CL2"), each = 2),
    range = rep(c("early", "late"), 2),
    treatment = rep("DrugA", 4),
    rate = c(0.1, 0.2, 0.3, 0.4)
  )
  # CL1, early -> 0.1
  # CL1, late  -> 0.2
  # CL2, early -> 0.3
  # CL2, late  -> 0.4

  # Run function - pivoting by CellLineName
  wide_dt <- cast_to_wide(
    long_data = long_dt,
    id_vars = c("treatment", "range"),
    col_var = "CellLineName",
    val_var = "rate"
  )

  # Checks
  expect_s3_class(wide_dt, "data.table")

  # Check if columns are correct (id_vars + unique values of col_var)
  expect_true(all(c("treatment", "range", "CL1", "CL2") %in% names(wide_dt)))

  # Check dimensions (should have 2 rows: early and late for DrugA)
  expect_equal(NROW(wide_dt), 2)

  # Check value correctness
  expect_equal(wide_dt[range == "early", CL1], 0.1)
  expect_equal(wide_dt[range == "late", CL2], 0.4)

  # Invalid data type
  expect_error(cast_to_wide(c(1, 2), "id", "col", "val"), "Must be a data.table")

  # Invalid vars types
  expect_error(cast_to_wide(long_dt, id_vars = 1, "range", "rate"), "Must be of type 'character'")
  expect_error(cast_to_wide(long_dt, c("CellLineName"), col_var = NULL, "rate"), "Must be of type 'string'")

  # Missing columns in data
  expect_error(cast_to_wide(long_dt, "CellLineName", "range", "WRONG_COL"), "Must be a subset of")
})

test_that("filter_treatments works as expected", {
  # Mock SummarizedExperiment object
  # Matrix: 3 time points (rows) x 2 drugs (columns)
  mat <- matrix(1:6, nrow = 3, ncol = 2)
  colnames(mat) <- c("DrugA 1uM", "DrugB 1uM")
  rownames(mat) <- c("0", "24", "48") # Duration

  se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(NormalizedCellCounts = mat)
  )
  # Set metadata required by the function
  S4Vectors::metadata(se)$CellLineName <- "TestLine_1"

  # Select drug to extract
  sel_trt <- c("DrugA 1uM")

  # Run function
  dt_res <- filter_treatments(se, sel_trt)

  # Checks
  expect_s3_class(dt_res, "data.table")

  # Check column names
  expected_cols <- c("treatment", "CellCount_norm", "CellLineName", "Duration")
  expect_equal(names(dt_res), expected_cols)

  # Check if data matches
  expect_equal(NROW(dt_res), 3) # 3 time points
  expect_equal(unique(dt_res$CellLineName), "TestLine_1")
  expect_equal(unique(dt_res$treatment), "DrugA 1uM")

  # Values should correspond to the first column of the matrix (1, 2, 3)
  expect_equal(dt_res$CellCount_norm, c(1, 2, 3))
  expect_equal(dt_res$Duration, c("0", "24", "48"))

  # Test for multiple drugs simultaneously
  sel_trt_multi <- c("DrugA 1uM", "DrugB 1uM")
  dt_res_multi <- filter_treatments(se, sel_trt_multi)
  expect_equal(NROW(dt_res_multi), 6) # 2 drugs * 3 time points
  expect_true(all(sel_trt_multi %in% dt_res_multi$treatment))

  # assertions
  # Invalid SE type
  expect_error(filter_treatments(data.table::data.table(), "TrtA"), "Assertion on 'se' failed")

  # Invalid sel_trt type
  expect_error(filter_treatments(se, 123), "Must be of type 'character'")
})

test_that("apply_custom_metadata_tags handles custom tags correctly", {

  # 1. Create a mock data.table with primary, secondary drugs and custom metadata
  mock_dt <- data.table::data.table(
    DrugName = c("DrugA", "DrugA", "DrugA"),
    DrugName_2 = c("DrugB", "DrugB", "DrugB"),
    drug_time = c("", "early", NA_character_),   # Custom tag for DrugName
    drug2_washout = c("", "yes", "no"),          # Custom tag for DrugName_2
    drug_moa = c("inhibitor", "inhibitor", "inhibitor") # Standard column to be ignored
  )

  # 2. Run the helper function
  res <- apply_custom_metadata_tags(mock_dt)

  # 3. Assertions

  # Row 1: Empty strings should not append any tags
  expect_equal(res$DrugName[1], "DrugA")
  expect_equal(res$DrugName_2[1], "DrugB")

  # Row 2: Valid tags should be appended correctly to their respective drugs
  expect_equal(res$DrugName[2], "DrugA [early]")
  expect_equal(res$DrugName_2[2], "DrugB [yes]")

  # Row 3: NAs should be ignored, valid tags should be appended
  expect_equal(res$DrugName[3], "DrugA")           # NA ignored
  expect_equal(res$DrugName_2[3], "DrugB [no]")    # "no" appended

  # Standard core columns shouldn't trigger tag appending
  # (drug_moa starts with "drug" but is a core identifier)
  expect_equal(res$drug_moa, c("inhibitor", "inhibitor", "inhibitor"))
})
