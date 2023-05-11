context("data")

test_that("raw data", {
  data(small_data)
  checkmate::expect_data_table(small_data)
  data(small_combo_data)
  checkmate::expect_data_table(small_combo_data)
})
