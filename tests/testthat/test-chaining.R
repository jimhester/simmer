context("method chaining")

test_that("trajectory's method chaining works", {
  t0 <- create_trajectory() %>%
    seize("one", 1) %>%
    release("one", 1) %>%
    timeout(function() 1) %>%
    branch(function() 1, T, create_trajectory() %>% timeout(function() 1)) %>%
    rollback(1) %>%
    seize("one", 1)

  expect_is(t0, "simmer.trajectory")
})

test_that("simmer's method chaining works", {
  t0 <- create_trajectory() %>%
    timeout(function() 1)

  env <- simmer() %>%
    add_resource("server") %>%
    add_generator("customer", t0, function() 1) %>%
    onestep() %>%
    run(10) %>%
    reset()

  expect_is(env, "simmer")
})
