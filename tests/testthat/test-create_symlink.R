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

test_that("create_symlink_to_current() keeps an absolute path as given, also through a symlinked parent", {
  skip_on_os("windows")
  root <- .symlink_root()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  # /real/runs/v1 reached through the link /via, as /gne/web is on resdev
  dir.create(file.path(root, "real", "runs", "v1"), recursive = TRUE)
  file.symlink(file.path(root, "real"), file.path(root, "via"))
  via_runs <- file.path(root, "via", "runs")

  create_symlink_to_current(via_runs, file.path(via_runs, "v1"))
  expect_equal(Sys.readlink(file.path(via_runs, "current")), file.path(via_runs, "v1"))
  expect_true(file.exists(file.path(via_runs, "current")))

  # a relative path becomes absolute from the working directory, links in it left alone
  withr::local_dir(file.path(root, "via"))
  create_symlink_to_current("./runs", "./runs/v1", verbose_mode = TRUE)
  expect_true(file.exists(file.path(via_runs, "current_verbose")))
  expect_true(startsWith(Sys.readlink(file.path(via_runs, "current_verbose")), "/"))
})
