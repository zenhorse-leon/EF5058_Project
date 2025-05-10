library(tidyverse)
library(PerformanceAnalytics)
library(quantmod)

# Load the data (assuming it's in a CSV file)
data <- read_csv("returns_compare.csv") %>%
  mutate(date = as.Date(date))

# Calculate drawdowns
calculate_drawdowns <- function(returns) {
  cum_ret <- cumprod(1 + returns)
  max_cum_ret <- cummax(cum_ret)
  drawdown <- (cum_ret - max_cum_ret) / max_cum_ret
  return(drawdown)
}

# Calculate for both strategy and benchmark
data <- data %>%
  mutate(
    strategy_drawdown = calculate_drawdowns(strategy_return),
    benchmark_drawdown = calculate_drawdowns(ret_benchmark)
  )

# 1. Historical Drawdown Analysis
max_drawdown_strategy <- min(data$strategy_drawdown)
max_drawdown_benchmark <- min(data$benchmark_drawdown)

cat("Maximum Strategy Drawdown:", round(max_drawdown_strategy*100, 2), "%\n")
cat("Maximum Benchmark Drawdown:", round(max_drawdown_benchmark*100, 2), "%\n")

# 2. Drawdown Control (Stop-loss simulation)
stop_loss_level <- -0.10  # 10% stop-loss
controlled_returns <- ifelse(data$strategy_return < stop_loss_level, 
                             stop_loss_level, 
                             data$strategy_return)

# 3. Value at Risk (VaR) Calculation
calculate_var <- function(returns, confidence = 0.95) {
  sorted_returns <- sort(returns)
  var_index <- floor(length(sorted_returns) * (1 - confidence))
  return(sorted_returns[var_index])
}

# Historical VaR
var_95_strategy <- calculate_var(data$strategy_return)
var_95_benchmark <- calculate_var(data$ret_benchmark)

cat("\n95% Historical VaR (Strategy):", round(var_95_strategy*100, 2), "%\n")
cat("95% Historical VaR (Benchmark):", round(var_95_benchmark*100, 2), "%\n")

# Parametric VaR (assuming normal distribution)
parametric_var <- function(returns, confidence = 0.95) {
  mu <- mean(returns)
  sigma <- sd(returns)
  q <- qnorm(1 - confidence)
  return(mu + q * sigma)
}

var_parametric_strategy <- parametric_var(data$strategy_return)
var_parametric_benchmark <- parametric_var(data$ret_benchmark)

cat("\n95% Parametric VaR (Strategy):", round(var_parametric_strategy*100, 2), "%\n")
cat("95% Parametric VaR (Benchmark):", round(var_parametric_benchmark*100, 2), "%\n")



# risk for different month frequency

# Load data
data <- read_csv("net_returns_months.csv") %>%
  mutate(date = as.Date(date))

# Calculate drawdown from cumulative returns
calculate_drawdown <- function(cum_returns) {
  peak <- cummax(cum_returns)
  drawdown <- (cum_returns - peak) / (1 + peak)
  return(drawdown)
}

# Calculate VaR (95%) from cumulative returns
calculate_var <- function(cum_returns, window) {
  periodic_returns <- diff(cum_returns) / (1 + lag(cum_returns, default = first(cum_returns)))
  rollapply(periodic_returns, width = window, 
            FUN = function(x) quantile(x, probs = 0.05, na.rm = TRUE), 
            fill = NA, align = "right")
}

# Process each frequency group
risk_metrics <- data %>%
  group_by(freq) %>%
  summarise(
    max_drawdown = min(calculate_drawdown(cum_net_return), na.rm = TRUE),
    avg_var = mean(calculate_var(cum_net_return, first(freq)), na.rm = TRUE)
  ) %>%
  filter(freq %in% c(1, 3, 6, 12)) %>%  # Only keep standard frequencies
  mutate(across(c(max_drawdown, avg_var), ~ scales::percent(., accuracy = 0.01)))

# Print results
risk_metrics %>%
  knitr::kable(col.names = c("Months", "Max Drawdown", "Avg VaR (95%)"),
               align = "c")




# risk for different weighting

# Load data
data <- read_csv("weighted_returns.csv") %>%
  mutate(date = as.Date(date))

# Calculate maximum drawdown from cumulative returns
max_drawdown <- function(cum_ret) {
  cum_ret <- cum_ret + 1  # Convert to growth factors
  drawdown <- cum_ret / cummax(cum_ret) - 1
  min(drawdown, na.rm = TRUE)
}

# Calculate VaR (95%) from periodic returns
value_at_risk <- function(returns) {
  quantile(returns, probs = 0.05, na.rm = TRUE)
}

# Calculate risk metrics for both strategies
risk_results <- data %>%
  summarise(
    # Equal-weighted strategy
    eq_drawdown = max_drawdown(cum_ret_eq),
    eq_var = value_at_risk(ret_eq),
    
    # Market-weighted strategy
    mkt_drawdown = max_drawdown(cum_ret_mkt),
    mkt_var = value_at_risk(ret_mkt)
  ) %>%
  pivot_longer(
    everything(),
    names_to = c("strategy", "metric"),
    names_sep = "_",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = "metric",
    values_from = "value"
  ) %>%
  mutate(
    strategy = ifelse(strategy == "eq", "Equal-Weighted", "Market-Weighted"),
    drawdown = scales::percent(drawdown, accuracy = 0.01),
    var = scales::percent(var, accuracy = 0.01)
  ) %>%
  select(strategy, drawdown, var)

# Display results
risk_results %>%
  knitr::kable(
    col.names = c("Strategy", "Max Drawdown", "VaR (95%)"),
    align = "c",
    caption = "Risk Metrics Comparison"
  )
