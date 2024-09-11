# Partially define the epinowcast model that will be
# reused across the "flavors" of model we test

library(purrr)
library(epinowcast)

expectation_module <- partial(
  enw_expectation,
  r = ~ 1 + rw(day),
  observation = ~ (1 | day_of_week)
)

reference_module <- partial(
  enw_reference,
  parametric = ~ 1,
  distribution = "gamma"
)

obs_module <- partial(
  enw_obs,
  family = "negbin"
)

fit <- enw_fit_opts(
  init_method = "pathfinder",
  save_warmup = FALSE, pp = TRUE,
  chains = 2, threads_per_chain = 1,
  parallel_chains = 2,
  iter_warmup = 1000, iter_sampling = 2000,
  adapt_delta = 0.98, max_treedepth = 12
)