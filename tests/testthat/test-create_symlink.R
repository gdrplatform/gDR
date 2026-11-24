.symlink_root <- function() {
  root <- tempfile("gdr_symlink_")
  dir.create(root)
  normalizePath(root)
}

test_that("create_symlink_to_current() links to a directory that resolves, also for relative paths", {
  skip_on_os("windows")
  root <- .symlink_root()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  withr::local_dir(root)
  dir.create("runs/v1", recursive = TRUE)

  # relative base_dir and latest_version, as run_report(output_dir = "./runs/v1") hands them over
  create_symlink_to_current("./runs", "./runs/v1")
  expect_true(file.exists("runs/current"))
  expect_equal(normalizePath("runs/current"), normalizePath("runs/v1"))

  # absolute input keeps an absolute target
  create_symlink_to_current(file.path(root, "runs"), file.path(root, "runs", "v1"), verbose_mode = TRUE)
  expect_equal(Sys.readlink("runs/current_verbose"), file.path(root, "runs", "v1"))
  expect_true(file.exists("runs/current_verbose"))
})

test_that("create_symlink_to_current() replaces a dangling link and a link to an older version", {
  skip_on_os("windows")
  root <- .symlink_root()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "v1"))
  dir.create(file.path(root, "v2"))

  # a link left dangling by an earlier run: file.exists() is FALSE for it
  file.symlink("./nowhere/v1", file.path(root, "current"))
  expect_false(file.exists(file.path(root, "current")))
  expect_true(create_symlink_to_current(root, file.path(root, "v1")))
  expect_equal(normalizePath(file.path(root, "current")), file.path(root, "v1"))

  # a later version replaces the link
  create_symlink_to_current(root, file.path(root, "v2"))
  expect_equal(normalizePath(file.path(root, "current")), file.path(root, "v2"))
})

test_that("create_symlink_to_current() still requires both directories", {
  root <- .symlink_root()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_error(create_symlink_to_current(root, file.path(root, "missing")))
  expect_error(create_symlink_to_current(file.path(root, "missing"), root))
})
