# Tests for run_report() and its helpers - the infrastructure-agnostic report driver.

# --- Tests for setup_run_environment (Resume Logic) ---

test_that("setup_run_environment handles resume mode correctly", {
  # Setup temporary directory
  root_dir <- tempfile("gdr_root")
  dir.create(root_dir)
  on.exit(unlink(root_dir, recursive = TRUE))

  # 1. Standard run (creates v1)
  # setup_run_environment creates 'v1' directory.
  # Ideally, the main pipeline creates 'current' symlink at the end.
  # We simulate this manually here.
  env1 <- setup_run_environment(root_dir, verbose_mode = FALSE, resume = FALSE)
  expect_true(dir.exists(file.path(root_dir, "v1")))
  file.symlink(file.path(root_dir, "v1"), file.path(root_dir, "current"))

  close(env1$stdout_con)
  close(env1$stderr_con)

  # 2. Subsequent standard run (creates v2)
  env2 <- setup_run_environment(root_dir, verbose_mode = FALSE, resume = FALSE)
  expect_true(dir.exists(file.path(root_dir, "v2")))

  # Update symlink manually to simulate successful v2 run
  unlink(file.path(root_dir, "current"))
  file.symlink(file.path(root_dir, "v2"), file.path(root_dir, "current"))

  close(env2$stdout_con)
  close(env2$stderr_con)

  # 3. Resume Mode (should use existing v2 via 'current')
  env3 <- setup_run_environment(root_dir, verbose_mode = FALSE, resume = TRUE)
  # output_dir should resolve to the v2 path
  expect_equal(normalizePath(env3$output_dir), normalizePath(file.path(root_dir, "v2")))

  close(env3$stdout_con)
  close(env3$stderr_con)

  # 4. Resume fail (missing 'current' symlink)
  unlink(file.path(root_dir, "current"))
  expect_error(
    setup_run_environment(root_dir, resume = TRUE),
    "RESUME MODE FAILED"
  )
})

# --- Tests for validate_and_prepare_inputs (MAE Steps Logic) ---

test_that("validate_and_prepare_inputs filters steps for MAE input", {
  # Create a dummy MAE file
  dummy_mae_path <- tempfile(fileext = ".qs2")
  # A minimal valid MAE object to pass checkmate::assert_class
  mae <- MultiAssayExperiment::MultiAssayExperiment()
  qs2::qs_save(mae, dummy_mae_path)
  on.exit(unlink(dummy_mae_path))

  # Access internal function
  val_func <- gDR:::validate_and_prepare_inputs

  # Stub validate_MAE. We deliberately do not reassign val_func.
  # We only stub validate_MAE because the empty MAE might fail business logic checks,
  # but we are only testing the 'steps' logic here.
  mockery::stub(val_func, "gDRutils::validate_MAE", TRUE)

  # Scenario 1: Default steps (1:3) with MAE input -> Should keep only 3
  args1 <- list(mae = dummy_mae_path, steps = 1:3, output_dir = ".")
  res1 <- val_func(args1, data_type = "mae")
  expect_equal(res1$steps, 3)

  # Scenario 2: Full pipeline (1:4) -> Should keep 3 and 4
  args2 <- list(mae = dummy_mae_path, steps = 1:4, output_dir = ".")
  res2 <- val_func(args2, data_type = "mae")
  expect_equal(res2$steps, c(3, 4))

  # Scenario 3: Only publication (4) -> Should keep 4
  args3 <- list(mae = dummy_mae_path, steps = 4, output_dir = ".")
  res3 <- val_func(args3, data_type = "mae")
  expect_equal(res3$steps, 4)

  # Scenario 4: Invalid steps (1) -> Fallback to 3
  args4 <- list(mae = dummy_mae_path, steps = 1, output_dir = ".")
  expect_warning(
    res4 <- val_func(args4, data_type = "mae"),
    "Invalid steps requested for MAE input"
  )
  expect_equal(res4$steps, 3)
})

# --- Tests for run_report (generic driver) ---

# Builds a temporary template directory with renderable stubs for every pipeline step.
.setup_dummy_templates <- function() {
  template_dir <- tempfile("templates")
  dir.create(template_dir)

  rmd_files <- c(
    "1-data_import.Rmd",
    "2-processing_and_QC.Rmd",
    "3-analysis.Rmd",
    "4-publish_results.Rmd"
  )
  for (f in rmd_files) {
    writeLines("# dummy step", file.path(template_dir, f))
  }
  file.create(file.path(template_dir, "gdr_logo-01.png"))

  template_dir
}

# Stubs every side effect of run_report() that would touch the file system or render a report.
.stub_run_report_io <- function(test_fn, output_dir, render_mock) {
  mockery::stub(test_fn, "setup_run_environment", function(...) {
    list(
      output_dir = output_dir,
      stdout_con = file(tempfile(), open = "wt"),
      stderr_con = file(tempfile(), open = "wt")
    )
  })
  mockery::stub(test_fn, "determine_data_type", function(...) "bench")
  mockery::stub(test_fn, "stage_and_update_paths", function(args, ...) args)
  mockery::stub(test_fn, "validate_and_prepare_inputs", function(args, ...) list())
  mockery::stub(test_fn, "rmarkdown::render", render_mock)
  mockery::stub(test_fn, "create_symlink_to_current", NULL)

  test_fn
}

test_that("run_report renders every requested step with all hooks left NULL", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  mock_render <- mockery::mock(TRUE, cycle = TRUE)
  test_fn <- .stub_run_report_io(run_report, dummy_out, mock_render)

  expect_no_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1:3
    )
  )

  expect_length(mockery::mock_args(mock_render), 3)
})

test_that("run_report calls every hook once, in pipeline order", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  calls <- character(0)
  record <- function(name) {
    function(...) {
      calls <<- c(calls, name)
      invisible(NULL)
    }
  }

  test_fn(
    manifest = "manifest.xlsx",
    output_dir = dummy_out,
    rmd_template_path = template_dir,
    steps = 1,
    on_resolve_inputs = function(args, extra_render_params) {
      calls <<- c(calls, "resolve")
      list(args = args, extra_render_params = extra_render_params)
    },
    on_start = record("start"),
    on_before_render = record("before_render"),
    on_success = record("success"),
    on_failure = record("failure")
  )

  expect_equal(calls, c("start", "resolve", "before_render", "success"))
})

test_that("run_report runs on_failure before the output directory is removed", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  mockery::stub(test_fn, "determine_data_type", function(...) stop("boom"))

  seen <- new.env(parent = emptyenv())

  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      on_failure = function(output_dir, error_message) {
        seen$dir_existed <- dir.exists(output_dir)
        seen$message <- error_message
      }
    ),
    "boom"
  )

  # The hook must still be able to read the logs from the output directory.
  expect_true(seen$dir_existed)
  expect_match(seen$message, "boom")
  # ... and the clean-up must still happen afterwards.
  expect_false(dir.exists(dummy_out))
})

test_that("run_report injects extra_render_params into the template data", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  mock_whisker <- mockery::mock("rendered", cycle = TRUE)
  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  mockery::stub(test_fn, "whisker::whisker.render", mock_whisker)

  # 'output_dir' is shadowed by a computed parameter, which is reported to the caller.
  expect_warning(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      extra_render_params = list(
        title = "My dataset",
        testing = FALSE,
        output_dir = "/hijacked"
      )
    ),
    "shadowed by parameters computed by run_report"
  )

  # whisker.render(template, data) -> the second positional argument holds the render params.
  render_data <- mockery::mock_args(mock_whisker)[[1]][[2]]

  # Values that templates such as 4-publish_results.Rmd rely on must reach whisker.
  expect_equal(render_data$title, "My dataset")
  expect_false(render_data$testing)

  # Parameters computed by the driver always win over deployment-specific ones.
  expect_equal(render_data$output_dir, dummy_out)
})

test_that("run_report lets on_resolve_inputs rewrite inputs and render params", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  mock_stage <- mockery::mock(list(), cycle = TRUE)
  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  mockery::stub(test_fn, "stage_and_update_paths", mock_stage)

  test_fn(
    manifest = "manifest.xlsx",
    output_dir = dummy_out,
    rmd_template_path = template_dir,
    steps = 1,
    extra_render_params = list(dataset_label = "before"),
    on_resolve_inputs = function(args, extra_render_params) {
      args$manifest <- "/resolved/manifest.xlsx"
      extra_render_params$dataset_label <- "after"
      list(args = args, extra_render_params = extra_render_params)
    }
  )

  staged <- mockery::mock_args(mock_stage)[[1]]
  expect_equal(staged[[1]]$manifest, "/resolved/manifest.xlsx")
  expect_equal(staged$extra$dataset_label, "after")
})

test_that("run_report rejects an on_resolve_inputs hook rewriting run-control arguments", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE,
      on_resolve_inputs = function(args, extra_render_params) {
        args$output_dir <- "/somewhere/else"
        list(args = args, extra_render_params = extra_render_params)
      }
    ),
    "must not modify the run-control argument\\(s\\): output_dir"
  )
})

test_that("run_report rejects an on_resolve_inputs hook appending the publication step", {

  # Unlike 'output_dir', 'steps' is still live when the hook runs: it travels through
  # validate_and_prepare_inputs() and is written back by list2env(). Without the guard a hook
  # could therefore append step 4 and publish results the caller never asked to publish, which
  # is exactly what the safety lock in run_gDR_with_report() is meant to prevent.
  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  mock_render <- mockery::mock(TRUE, cycle = TRUE)
  test_fn <- .stub_run_report_io(run_report, dummy_out, mock_render)

  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE,
      on_resolve_inputs = function(args, extra_render_params) {
        args$steps <- 1:4
        list(args = args, extra_render_params = extra_render_params)
      }
    ),
    "must not modify the run-control argument\\(s\\): steps"
  )

  # Nothing may have been rendered - least of all 4-publish_results.Rmd.
  expect_length(mockery::mock_args(mock_render), 0)
})

test_that("run_report warns about extra_render_params shadowed by computed parameters", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  expect_warning(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      extra_render_params = list(output_dir = "/hijacked", title = "kept")
    ),
    "shadowed by parameters computed by run_report\\(\\): output_dir"
  )
})

test_that("run_report keeps the results when the success hook fails", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  failure_seen <- FALSE
  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  # A broken notification must not be reported as a failed run, ...
  expect_warning(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      on_success = function(output_dir) stop("mailhost down"),
      on_failure = function(output_dir, error_message) failure_seen <<- TRUE
    ),
    "Success hook raised an error: mailhost down"
  )

  # ... so neither the failure hook nor the clean-up may run.
  expect_false(failure_seen)
  expect_true(dir.exists(dummy_out))
})

test_that("run_report closes its log connections when the start hook fails", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  open_before <- NROW(showConnections())
  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE,
      on_start = function(output_dir) stop("cannot reach the mail server")
    ),
    "cannot reach the mail server"
  )
  expect_equal(NROW(showConnections()), open_before)
})

# --- Tests for long_table input dispatch ---

test_that("determine_data_type detects long_table input", {
  det <- gDR:::determine_data_type

  expect_equal(det(list(long_table = "some.csv")), "long_table")

  # qcs_id takes precedence over long_table
  expect_equal(det(list(qcs_id = "Q1", long_table = "some.csv")), "qcs")
})

test_that("validate_and_prepare_inputs handles long_table input", {
  val_func <- gDR:::validate_and_prepare_inputs

  lt_path <- tempfile(fileext = ".csv")
  writeLines(
    c("Gnumber,clid,Duration,Concentration,ReadoutValue", "G1,CL1,72,1,1000"),
    lt_path
  )
  on.exit(unlink(lt_path))

  # A valid, single, existing long_table path passes and is preserved
  res <- val_func(list(long_table = lt_path, steps = 1:3, output_dir = "."),
                  data_type = "long_table")
  expect_equal(res$long_table, lt_path)

  # Mixing long_table with other inputs is rejected
  expect_error(
    val_func(list(long_table = lt_path, manifest = "m.xlsx", steps = 1:3, output_dir = "."),
             data_type = "long_table"),
    "not both"
  )
  expect_error(
    val_func(list(long_table = lt_path, raw_data = "raw.csv", steps = 1:3, output_dir = "."),
             data_type = "long_table"),
    "not both"
  )

  # A non-existent file is rejected
  expect_error(
    val_func(list(long_table = tempfile(fileext = ".csv"), steps = 1:3, output_dir = "."),
             data_type = "long_table")
  )
})

test_that("run_report refuses a qcs run without an injected import section", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  mockery::stub(test_fn, "determine_data_type", function(...) "qcs")

  # The driver cannot import screening-system sessions on its own.
  expect_error(
    test_fn(
      qcs_id = "QCS-1",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE
    ),
    "requires the import section to be supplied"
  )

  # Supplying the rendered section is what the internal wrapper does.
  expect_no_error(
    test_fn(
      qcs_id = "QCS-1",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      extra_render_params = list(extra_sections_import = "```{r}\n1 + 1\n```")
    )
  )
})

test_that("run_report reports a missing step template up front", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
  })

  # A deployment without publishing support simply does not ship the step-4 template.
  unlink(file.path(template_dir, "4-publish_results.Rmd"))

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))

  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 4,
      remove_on_failure = FALSE
    ),
    "4-publish_results\\.Rmd.*not available in this installation"
  )
})

test_that("find_template searches the directories in order", {

  first <- tempfile("tpl_first")
  second <- tempfile("tpl_second")
  dir.create(first)
  dir.create(second)
  on.exit({
    unlink(first, recursive = TRUE)
    unlink(second, recursive = TRUE)
  })

  writeLines("override", file.path(first, "shared.Rmd"))
  writeLines("base", file.path(second, "shared.Rmd"))
  writeLines("publish", file.path(second, "only-in-second.Rmd"))

  found <- gDR:::find_template(
    c("shared.Rmd", "only-in-second.Rmd", "nowhere.Rmd"),
    c(first, second)
  )

  # The earlier directory wins, later ones still contribute what they alone carry.
  expect_equal(found[[1]], file.path(first, "shared.Rmd"))
  expect_equal(found[[2]], file.path(second, "only-in-second.Rmd"))
  expect_true(is.na(found[[3]]))
})

test_that("run_report assembles its templates from several directories", {

  dummy_out <- tempfile()
  dir.create(dummy_out)
  template_dir <- .setup_dummy_templates()
  publish_dir <- tempfile("tpl_publish")
  dir.create(publish_dir)
  on.exit({
    unlink(dummy_out, recursive = TRUE)
    unlink(template_dir, recursive = TRUE)
    unlink(publish_dir, recursive = TRUE)
  })

  # Mirrors the post-migration layout: the publication step lives outside the shared set.
  file.rename(
    file.path(template_dir, "4-publish_results.Rmd"),
    file.path(publish_dir, "4-publish_results.Rmd")
  )

  mock_render <- mockery::mock(TRUE, cycle = TRUE)
  test_fn <- .stub_run_report_io(run_report, dummy_out, mock_render)

  expect_no_error(
    test_fn(
      manifest = "manifest.xlsx",
      output_dir = dummy_out,
      rmd_template_path = c(publish_dir, template_dir),
      steps = 4
    )
  )
  expect_length(mockery::mock_args(mock_render), 1)
})

# --- Tests for the versioned output directory in existing-report detection ---

test_that("determine_data_type finds an existing report in the versioned directory", {
  det <- gDR:::determine_data_type

  base <- tempfile()
  versioned <- file.path(base, "v1")
  dir.create(file.path(versioned, "gDR_data"), recursive = TRUE)
  file.create(file.path(versioned, "gDR_data", "gDR_mae.qs2"))
  on.exit(unlink(base, recursive = TRUE))

  expect_equal(det(list(output_dir = base), versioned), "existing")

  # reports never write gDR_data into the unversioned directory, so looking there finds nothing
  expect_error(det(list(output_dir = base)), "No valid input source provided")

  # an explicit input source still wins over the directory probe
  expect_equal(det(list(output_dir = base, long_table = "some.csv"), versioned), "long_table")
})

test_that("validate_and_prepare_inputs requires steps, which makes its existing-report inference dead", {
  val_func <- gDR:::validate_and_prepare_inputs

  # The "existing" branch infers `steps` when they are absent, but the assertion at the top of the
  # function rejects a NULL `steps` first, so that inference cannot run. Pinned here so a change to
  # either end shows up as a test failure rather than as silently revived code.
  expect_error(
    val_func(list(output_dir = "."), data_type = "existing"),
    "Assertion on 'args\\$steps' failed"
  )
})

test_that("run_report refuses a configuration file that could not be staged", {
  dummy_out <- withr::local_tempdir()
  template_dir <- .setup_dummy_templates()
  withr::defer(unlink(template_dir, recursive = TRUE))

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  # Staging drops a path argument it cannot resolve; the report must not carry on with the
  # configuration the templates generate for themselves.
  mockery::stub(test_fn, "stage_and_update_paths", function(args, ...) {
    args$configuration_file_path <- NULL
    args
  })

  expect_error(
    test_fn(
      manifest = "manifest.xlsx",
      configuration_file_path = "windows.yml",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE
    ),
    "no file could be resolved and staged"
  )
})

test_that("run_report passes a staged configuration file through to the templates", {
  dummy_out <- withr::local_tempdir()
  template_dir <- .setup_dummy_templates()
  withr::defer(unlink(template_dir, recursive = TRUE))

  test_fn <- .stub_run_report_io(run_report, dummy_out, mockery::mock(TRUE, cycle = TRUE))
  staged <- file.path(dummy_out, "raw_data", "my_windows.yml")
  mockery::stub(test_fn, "stage_and_update_paths", function(args, ...) {
    args$configuration_file_path <- staged
    args
  })

  expect_no_error(
    test_fn(
      manifest = "manifest.xlsx",
      configuration_file_path = "windows.yml",
      output_dir = dummy_out,
      rmd_template_path = template_dir,
      steps = 1,
      remove_on_failure = FALSE
    )
  )
})

test_that("stage_and_update_paths reports a path argument it had to drop", {
  out <- withr::local_tempdir()
  for (d in c("raw_data", "data_annotation")) {
    dir.create(file.path(out, d))
  }

  expect_warning(
    res <- stage_and_update_paths(
      list(manifest = file.path(out, "*.nomatch")),
      out
    ),
    "resolved to no file"
  )
  expect_null(res$manifest)
})

test_that("stage_and_update_paths leaves a file that is already staged intact", {
  out <- withr::local_tempdir()
  for (d in c("raw_data", "data_annotation")) {
    dir.create(file.path(out, d))
  }
  staged <- file.path(out, "raw_data", "my_windows.yml")
  writeLines("early_period: [44, 92]", staged)

  # Re-running with the configuration edited in place is the normal way to iterate; file.copy()
  # errors when a file is both source and destination, so an unguarded staging step fails the run.
  res <- stage_and_update_paths(list(configuration_file_path = staged), out)

  expect_equal(res$configuration_file_path, staged)
  expect_equal(readLines(staged), "early_period: [44, 92]")
})
