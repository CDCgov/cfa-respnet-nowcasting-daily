#' Get report times from event times using a delay
#' distribution.
#'
#' @param event_times Vector of event times.
#' @param start_date Start date in YYYY-MM-DD format.
#' @param dow_effect This is a "fudge factor" to simulate
#' day-of-week reporting effects. It is a vector of 7, giving
#' multipliers to scale the delay_dist probabilities by depending
#' on their day of week. It should start with Sunday.
#' @param delay_dist Delay distribution to simulate from (cdf).
#' @param max_delay The maximum desired delay.
#' @param ... arguments to the delay distribution.
#'
#' @return A data frame of event and report times.
get_report_times <- function(event_times, start_date, dow_effect = NULL,
                             delay_dist, max_delay, ...) {
  max_delay <- max_delay + 1 # Makes things easier since R is 1-indexed
  pdist <- match.fun(delay_dist)
  # Get discretized pmf (many ways to do this but I'm just saying
  # P(X\leq 1) = P(X=0) )
  delay_cdf <- sapply(seq_len(max_delay + 1) - 1,
                      pdist, ...)
  delay_pmf <- diff(delay_cdf)
  # And normalize
  delay_pmf <- delay_pmf / sum(delay_pmf)
  # Then deal with DOW effects if there are any
  if (is.null(dow_effect)) {
    delay_days <- sample(seq_len(max_delay) - 1, length(event_times),
                         replace = TRUE, prob = delay_pmf)
  } else {
    dow_effect <- rep(dow_effect,
                      times = ceiling((max_delay) / 7))[seq_len(max_delay)]
    # Define a helper function to shift the fudge factor order depending
    # on the weekday of the event
    shift_days <- function(x, wday = 1) {
      wday <- wday - 1
      if (wday == 0) x else c(tail(x, -wday), head(x, wday))
    }
    # Separate reporting pmf for each event day of week
    dow_pmfs <- lapply(1:7, function(wday) {
      rescaled_pmf <- delay_pmf * shift_days(dow_effect, wday)
      return(rescaled_pmf / sum(rescaled_pmf))
    })
    delay_days <- sapply(event_times, function(event_time) {
      # As lubridate, let Sunday be "day 1" of the week.
      # Multiply probabilities by their corresponding fudge factors,
      # then rescale the pmfs.
      wday <- lubridate::wday(as.Date(start_date) + event_time)
      event_day_pmf <- dow_pmfs[[wday]]
      return(sample(seq_len(max_delay) - 1, 1,
                    replace = TRUE, prob = event_day_pmf))
    })
  }
  report_times <- event_times + delay_days
  report_times <- as.Date(report_times, origin = start_date)
  event_times <- as.Date(event_times, origin = start_date)
  rslt <- data.frame(event_times, report_times)
  return(rslt)
}

#' Simulate from an SEIHRD Markov epidemic model using the Gillespie algorithm.
#'
#' @param init_state Vector of S E I H R D to initialize the simulation.
#' @param beta The transmission rate per contact.
#' @param gamma The inverse of the mean latent period duration, 1/gamma.
#' @param nu The inverse of the mean infectious period duration, 1/nu.
#' @param eta The inverse of the mean hospital stay duration, 1/eta.
#' @param kappa The inverse of the mean duration of immunity, 1/kappa.
#' @param tau The infection-hospitalization ratio.
#' @param v The hospitalization-fatality ratio.
#' @param total_time The total number of time steps to run the simulation for.
#'
#' @return A data frame containing the state of the system at each transition.
sim_seihrd <- function(init_state = c(99999, 1, 0, 0, 0, 0), beta, gamma, nu,
                       eta, kappa, tau, v, total_time = 100) {
  # Set up the data frame that will ultimately be returned
  N <- sum(init_state) # nolint
  rslt <- data.frame(matrix(nrow = 1,
                            ncol = length(init_state) + 1))
  colnames(rslt) <- c("Time", "S", "E", "I", "H", "R", "D")

  # Vector to store the current state of the model
  curr <- c(0, init_state) # Starting at time 0
  names(curr) <- colnames(rslt)

  # Store the initial state in rslt
  rslt[1, ] <- curr

  # Start the simulation
  # Looping is inefficient but conceptually helpful
  while (curr["Time"] < total_time) {
    # Simulate time to next event
    # The rate to parameterize the exponential distribution for
    # time to next event is the sum of all the exponential rates
    # of change between compartments.
    # Rates are:
    rates_vec <- c((beta * curr["S"] * curr["I"]) / N, # S to E
                   gamma * curr["E"], # E to I
                   nu * tau * curr["I"], # I to H
                   nu * (1 - tau) * curr["I"], # I to R
                   eta * (1 - v) * curr["H"], # H to R
                   eta * v * curr["H"], # H to D
                   kappa * curr["R"]) # R to S
    rate_sum <- sum(rates_vec)
    if (rate_sum == 0) break # Nothing else can happen
    t <- rexp(1, rate = rate_sum)
    if (curr["Time", ] >= total_time) break # Ran out of time

    # Choose which event occurs: the probability of a certain transition is
    # the rate of the transition of interest divided by the sum of all the rates
    transition_probs <- rates_vec / rate_sum
    possible_events <- matrix(data = c(t, -1, 1, 0, 0, 0, 0, # S to E
                                       t, 0, -1, 1, 0, 0, 0, # E to I
                                       t, 0, 0, -1, 1, 0, 0, # I to H
                                       t, 0, 0, -1, 0, 1, 0, # I to R
                                       t, 0, 0, 0, -1, 1, 0, # H to R
                                       t, 0, 0, 0, -1, 0, 1, # H to D
                                       t, 1, 0, 0, 0, -1, 0), # R to S
                              ncol = length(curr), byrow = TRUE)
    event <- sample(seq_len(length(rates_vec)), size = 1,
                    prob = transition_probs)

    # Change the current state to reflect the event
    curr <- curr + possible_events[event, ]

    # Record the event's occurrence
    rslt <- rbind(rslt, curr)
  }

  return(rslt)
}
