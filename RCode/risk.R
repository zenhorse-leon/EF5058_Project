library(tidyverse)
library(PerformanceAnalytics)
library(patchwork)
library(gridExtra)

# High Water Mark Calculation
calculate_hwm <- function(returns) {
  cum_ret <- cumprod(1 + returns)
  hwm <- cummax(cum_ret)
  return(hwm)
}

### PART 1: Strategy vs Benchmark Analysis ###
data1 <- read_csv("returns_compare.csv") %>% mutate(date = as.Date(date))

# Calculate metrics
data1 <- data1 %>%
  mutate(
    strategy_hwm = calculate_hwm(strategy_return),
    benchmark_hwm = calculate_hwm(ret_benchmark),
    strategy_drawdown = calculate_drawdowns(strategy_return),
    benchmark_drawdown = calculate_drawdowns(ret_benchmark),
    strategy_value = cumprod(1 + strategy_return),
    benchmark_value = cumprod(1 + ret_benchmark)
  )

# Create plots
hwm_plot1 <- ggplot(data1, aes(x = date)) +
  geom_line(aes(y = strategy_hwm, color = "Strategy HWM"), linetype = "dashed") +
  geom_line(aes(y = strategy_value, color = "Strategy Value")) +
  geom_line(aes(y = benchmark_hwm, color = "Benchmark HWM"), linetype = "dashed") +
  geom_line(aes(y = benchmark_value, color = "Benchmark Value")) +
  labs(title = "Strategy vs Benchmark High Water Marks", y = "Value") +
  theme_minimal()

drawdown_plot1 <- ggplot(data1, aes(x = date)) +
  geom_line(aes(y = strategy_drawdown, color = "Strategy"), linewidth = 1) +
  geom_line(aes(y = benchmark_drawdown, color = "Benchmark"), linewidth = 1) +
  labs(title = "Strategy vs Benchmark Drawdowns", y = "Drawdown") +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal()

# Print results and plots
cat("PART 1: Strategy vs Benchmark Analysis\n")
cat("Maximum Strategy Drawdown:", round(min(data1$strategy_drawdown)*100, 2), "%\n")
cat("Maximum Benchmark Drawdown:", round(min(data1$benchmark_drawdown)*100, 2), "%\n")
# print(hwm_plot1 + drawdown_plot1 + plot_layout(ncol = 2))

print(hwm_plot1)
ggsave("part1_hwm.png", hwm_plot1, width = 12, height = 6)

print(drawdown_plot1)
ggsave("part1_dd.png", drawdown_plot1, width = 12, height = 6)
ggsave("part1_hwm_dd.png", hwm_plot1 + drawdown_plot1 + plot_layout(nrow = 2), width = 12, height = 8)

### PART 2: Different Frequencies Analysis ###
data2 <- read_csv("net_returns_months.csv") %>% mutate(date = as.Date(date))

# Create plots for each frequency
freq_plots <- map(c(1, 3, 6, 12), ~{
  freq_data <- data2 %>% filter(freq == .x)
  freq_data <- freq_data %>%
    mutate(
      hwm = cummax(cum_net_return + 1),  # Calculate HWM from cumulative returns
      value = cum_net_return + 1,        # Convert to growth factors
      drawdown = (value - hwm)/hwm       # Calculate drawdown
    )
  
  hwm_plot <- ggplot(freq_data, aes(x = date)) +
    geom_line(aes(y = hwm, color = "HWM"), linetype = "dashed") +
    geom_line(aes(y = value, color = "Value")) +
    labs(title = paste(.x, "Month HWM"), y = "Value") +
    theme_minimal()
  
  dd_plot <- ggplot(freq_data, aes(x = date, y = drawdown)) +
    geom_line(color = "steelblue", linewidth = 1) +
    labs(title = paste(.x, "Month Drawdown"), y = "Drawdown") +
    scale_y_continuous(labels = scales::percent) +
    theme_minimal()
  
  hwm_plot + dd_plot + plot_layout(ncol = 2)
})

# Calculate risk metrics for each frequency
risk_metrics <- data2 %>%
  group_by(freq) %>%
  summarise(
    max_drawdown = min((cum_net_return + 1 - cummax(cum_net_return + 1))/cummax(cum_net_return + 1)),
    avg_var = mean(rollapply(net_return, width = first(freq), 
                             FUN = function(x) quantile(x, 0.05, na.rm = TRUE), 
                             fill = NA, align = "right"), na.rm = TRUE)
  ) %>%
  filter(freq %in% c(1, 3, 6, 12)) %>%
  mutate(across(c(max_drawdown, avg_var), ~ scales::percent(., accuracy = 0.01)))

ggsave("part2_hwm_dd.png", wrap_plots(freq_plots, ncol = 1), width = 12, height = 8)

# Print results and plots
cat("\nPART 2: Different Frequencies Analysis\n")
print(risk_metrics)
print(wrap_plots(freq_plots, ncol = 1))

# Print results and plots
cat("\nPART 3: Weighting Methods Analysis\n")


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


# Create plotting data
plot_data <- data %>%
  mutate(
    # Convert to growth factors (1 = 100%)
    cum_ret_eq = cum_ret_eq + 1,
    cum_ret_mkt = cum_ret_mkt + 1,
    
    # Calculate high water marks
    hw_eq = cummax(cum_ret_eq),
    hw_mkt = cummax(cum_ret_mkt),
    
    # Calculate drawdowns
    drawdown_eq = cum_ret_eq / hw_eq - 1,
    drawdown_mkt = cum_ret_mkt / hw_mkt - 1
  )

# Function to create strategy plots
create_strategy_plot <- function(strategy) {
  
  if (strategy == "eq") {
    title <- "Equal-Weighted Strategy"
    color <- "#1f77b4"  # Blue
  } else {
    title <- "Market-Weighted Strategy"
    color <- "#ff7f0e"  # Orange
  }
  
  # High water mark plot
  hw_plot <- ggplot(plot_data, aes(x = date)) +
    geom_line(aes(y = get(paste0("cum_ret_", strategy))), 
              color = color, linewidth = 0.8) +
    geom_line(aes(y = get(paste0("hw_", strategy))), 
              color = "darkred", linetype = "dashed", linewidth = 0.6) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(title = title, y = "Cumulative Return", x = "") +
    theme_minimal() +
    theme(plot.title = element_text(size = 10, face = "bold"))
  
  # Drawdown plot
  dd_plot <- ggplot(plot_data, aes(x = date, y = get(paste0("drawdown_", strategy)))) +
    geom_area(fill = color, alpha = 0.5) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(y = "Drawdown", x = "Date") +
    theme_minimal()
  
  # Combine plots
  hw_plot / dd_plot + plot_layout(heights = c(2, 1))
}

# Create plots for both strategies
eq_plot <- create_strategy_plot("eq")
mkt_plot <- create_strategy_plot("mkt")

# Combine into two-column layout
combined_plots <- (eq_plot | mkt_plot) + 
  plot_annotation(
    title = "Risk Profile: High Water Marks and Drawdowns",
    subtitle = "Comparison between equal-weighted and market-weighted strategies",
    theme = theme(plot.title = element_text(size = 12, face = "bold"),
                  plot.subtitle = element_text(size = 10))
  )

# Display the combined plots
print(combined_plots)
ggsave("part3_hwm_dd.png", combined_plots, width = 12, height = 8)


