context("utils")

test_that("standardize_df", {
  expect_equal(standardize_df(data.frame(a = 2)), data.frame(a = "2"))
})


