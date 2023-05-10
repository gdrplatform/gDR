context("data")

test_that("raw data", {
  data(small_data)
  expect_true(is(small_data, "data.table"))
  data(small_combo_data)
  expect_true(is(small_combo_data, "data.table"))
})
