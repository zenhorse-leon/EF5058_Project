setwd("/Users/liang/Documents/CityU/Courses/Asset Mgt & Hedge Fund Srtgc EF5058/project/RCode/")
getwd()

#(a)

# 1. 数据预处理：转换日期，计算超额收益
library(readr)
library(dplyr)
library(lubridate)
data <- read_csv("../data_processed/stock_factors_processed.csv")
data <- data %>%
  mutate(date = ymd(as.character(date)),
         excess_ret = return - rf) %>%
  arrange(code, date)

# 2. 计算动量信号（过去7到2个月累计收益，剔除最近1个月）
data <- data %>%
  group_by(code) %>%
  mutate(
    ret_lag_1 = lag(excess_ret, 1),
    ret_lag_2 = lag(excess_ret, 2),
    ret_lag_3 = lag(excess_ret, 3),
    ret_lag_4 = lag(excess_ret, 4),
    ret_lag_5 = lag(excess_ret, 5),
    ret_lag_6 = lag(excess_ret, 6),
    ret_lag_7 = lag(excess_ret, 7),
    momentum_signal = (1 + ret_lag_7) * (1 + ret_lag_6) * (1 + ret_lag_5) * (1 + ret_lag_4) *
                      (1 + ret_lag_3) * (1 + ret_lag_2) - 1
  ) %>% ungroup()

# 3. 每月分组排名（10分位），标记赢家（第10分位）和输家（第1分位）
data <- data %>%
  group_by(date) %>%
  filter(!is.na(momentum_signal)) %>%
  mutate(momentum_rank = ntile(momentum_signal, 10)) %>%
  ungroup() %>%
  mutate(position = case_when(
    momentum_rank == 10 ~ 1,
    momentum_rank == 1 ~ -1,
    TRUE ~ 0
  ))

# 4. 构建多空组合持仓期为6个月，滚动持仓
positions <- data %>%
  filter(position != 0) %>%
  select(code, date, position) %>%
  mutate(end_date = date %m+% months(5)) %>%
  rowwise() %>%
  do(data.frame(code = .$code, date = seq.Date(.$date, .$end_date, by = "month"), position = .$position)) %>%
  ungroup()

# 5. 合并持仓信号，计算策略每月超额收益
portfolio <- data %>%
  inner_join(positions, by = c("code", "date")) %>%  
  group_by(date) %>%
  mutate(
    n_stocks = sum(position.y != 0),
    weight = 1 / n_stocks,
    weighted_ret = weight * position.y * excess_ret
  ) %>%
  summarise(strategy_return = sum(weighted_ret, na.rm = TRUE)) %>%
  arrange(date)

#(b)
library(lmtest)
library(broom)
library(ggplot2)
library(PerformanceAnalytics)
# 6. 计算策略累计收益
portfolio <- portfolio %>%
  mutate(cum_return = cumprod(1 + strategy_return) - 1)

# 7. 多因子回归分析 (FF5 + UMD)
# 合并因子数据
factor_data <- data %>%
  select(date, market, SMB, HML, RMW, CMA, UMD) %>%
  distinct()

perf_data <- portfolio %>%
  left_join(factor_data, by = "date") %>%
  rename(strategy_excess = strategy_return) %>%
  drop_na()

# 回归模型
strategy_excess ~ market + SMB + HML + RMW + CMA + UMD
ff_formula <- strategy_excess ~ market + SMB + HML + RMW + CMA + UMD
fit_ff <- lm(strategy_excess ~ market + SMB + HML + RMW + CMA + UMD, data = perf_data)
summary(fit_ff)



#考虑市场基准
# 计算累计收益
benchmark_returns <- data %>%
  group_by(date) %>%
  summarise(ret_benchmark = mean(market, na.rm = TRUE)) %>%
  arrange(date)

returns_compare <- portfolio %>%
  left_join(benchmark_returns, by = "date") %>%
  arrange(date) %>%
  mutate(
    cum_ret_strategy = cumprod(1 + strategy_return) - 1,
    cum_ret_benchmark = cumprod(1 + ret_benchmark) - 1,
    excess_return = strategy_return - ret_benchmark
  )
# 画累计收益曲线对比
library(ggplot2)
library(scales) 
ggplot(returns_compare, aes(x = date)) +
  geom_line(aes(y = cum_ret_strategy, color = "Strategy Cumulative Return")) +
  geom_line(aes(y = cum_ret_benchmark, color = "Benchmark Cumulative Return")) +
  scale_y_continuous(labels = percent) +
  labs(
    title = "Comparison of Strategy and Benchmark Cumulative Returns",
    y = "Cumulative Return",
    x = "Date",
    color = "Legend"
  ) +
  theme_minimal() +
  scale_color_manual(values = c("Strategy Cumulative Return" = "blue", "Benchmark Cumulative Return" = "red"))

# 计算绩效指标
# 转换为xts对象方便用PerformanceAnalytics包
library(xts)
library(PerformanceAnalytics)

# 转换为xts对象，假设是月度收益，scale=12
rets_xts <- xts(returns_compare[, c("strategy_return", "ret_benchmark")], order.by = returns_compare$date)

# 使用PerformanceAnalytics计算年化收益、波动率、夏普比率
perf_table <- table.AnnualizedReturns(rets_xts, scale = 12)
print(perf_table)

# 统计检验：CAPM回归，策略收益对基准收益回归
model <- lm(strategy_return ~ ret_benchmark, data = returns_compare)
summary(model)

# alpha显著说明策略超越市场基准的异常收益




# 8. 子样本回归
perf_data <- perf_data %>%
  mutate(period = case_when(
    date >= as.Date("2000-01-01") & date <= as.Date("2007-11-30") ~ "Pre-GFC Expansion",
    date >= as.Date("2007-12-01") & date <= as.Date("2009-06-30") ~ "Global Financial Crisis",
    date >= as.Date("2009-07-01") & date <= as.Date("2019-12-31") ~ "Post-GFC Expansion",
    date >= as.Date("2020-01-01") ~ "COVID-19 Pandemic",
    TRUE ~ NA_character_
  ))

# 过滤掉未定义的时期，分组回归并整理结果
subsample_results <- perf_data %>%
  filter(!is.na(period)) %>%
  group_by(period) %>%
   group_modify(~ tidy(lm(ff_formula, data = .x)))

print(subsample_results, n = 28)

# 9. 交易成本模拟：不同调仓频率净收益
# 假设1%往返交易成本，按调仓频率均摊
calc_net_return <- function(freq_months) {
  cost_per_month <- 0.01 / freq_months
  portfolio %>%
    mutate(net_return = strategy_return - cost_per_month) %>%
    mutate(cum_net_return = cumprod(1 + net_return) - 1) %>%
    select(date, net_return, cum_net_return) %>%
    mutate(freq = freq_months)
}

net_returns <- bind_rows(
  calc_net_return(1),
  calc_net_return(3),
  calc_net_return(6),
  calc_net_return(12)
)

# 10. 绘图：累计净收益对比不同调仓频率
ggplot(net_returns, aes(x = date, y = cum_net_return, color = factor(freq))) +
  geom_line(size = 1) +
  labs(title = "Momentum Strategy Cumulative Net Returns under Different Rebalance Frequencies",
       x = "Date", y = "Cumulative Net Return",
       color = "Rebalance Frequency (months)") +
  theme_minimal()

# 11. 绩效指标计算
library(xts)

# 创建xts时间序列对象
strategy_returns_xts <- xts(portfolio$strategy_return, order.by = as.Date(portfolio$date))

# 计算年化收益率
annualized_return <- Return.annualized(strategy_returns_xts, scale = 12)

print(annualized_return)

# === 计算等权重组合收益 ===
library(dplyr)
library(readr)
returns <- read_csv("stock_factors_processed(2).csv")
returns <- returns %>%
  mutate(date = ymd(as.character(date)))

positions_with_ret <- positions %>%
  left_join(returns, by = c("code", "date")) %>%
  mutate(ret_adj = return - rf) 

equal_weighted <- positions_with_ret %>%
  group_by(date, position) %>%
  mutate(n_stocks = n()) %>%
  ungroup() %>%
  mutate(weight_eq = 1 / n_stocks) %>%
  group_by(date) %>%
  summarise(
    ret_long_eq = sum(ifelse(position == 1, weight_eq * ret_adj, 0), na.rm = TRUE),
    ret_short_eq = sum(ifelse(position == -1, weight_eq * ret_adj, 0), na.rm = TRUE),
    ret_eq = ret_long_eq - ret_short_eq
  ) %>%
  arrange(date)
print(equal_weighted)
# 1. 转换为xts对象（假设月度收益率）
equal_xts <- xts(equal_weighted$ret_eq, order.by = equal_weighted$date)

# 2. 计算年化收益率
annualized_return <- Return.annualized(equal_xts, scale = 12)

# 3. 计算年化波动率（标准差）
annualized_vol <- StdDev.annualized(equal_xts, scale = 12)

# 4. 计算夏普比率（无风险利率假设为0）
sharpe_ratio <- annualized_return / annualized_vol

# 5. 整理输出结果
result <- tibble(
  Annualized_Return = as.numeric(annualized_return),
  Annualized_Volatility = as.numeric(annualized_vol),
  Sharpe_Ratio = as.numeric(sharpe_ratio)
)

print(result)



## === 计算市值加权组合收益 ===
market_weighted <- positions %>%
  group_by(date, position) %>%
  mutate(total_me = sum(me, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(weight_mkt = me / total_me) %>%
  group_by(date) %>%
  summarise(
    ret_long_mkt = sum(ifelse(position == 1, weight_mkt * ret_adj, 0), na.rm = TRUE),
    ret_short_mkt = sum(ifelse(position == -1, weight_mkt * ret_adj, 0), na.rm = TRUE),
    ret_mkt = ret_long_mkt - ret_short_mkt
  ) %>%
  arrange(date)

# 合并两种权重收益对比
combined_returns <- equal_weighted %>%
  select(date, ret_eq) %>%
  left_join(market_weighted %>% select(date, ret_mkt), by = "date") %>%
  mutate(
    cum_ret_eq = cumprod(1 + ret_eq) - 1,
    cum_ret_mkt = cumprod(1 + ret_mkt) - 1
  )

# 画图比较
ggplot(combined_returns, aes(x = date)) +
  geom_line(aes(y = cum_ret_eq, color = "Equal Weight")) +
  geom_line(aes(y = cum_ret_mkt, color = "Market Cap Weight")) +
  labs(title = "Momentum Strategy Cumulative Returns: Equal vs Market Cap Weight",
       x = "Date", y = "Cumulative Return",
       color = "Weighting Method") +
  theme_minimal()

# 计算绩效指标
cat("Equal Weight Performance:\n")
cat("Annualized Return:", round(Return.annualized(combined_returns$ret_eq) * 100, 2), "%\n")
cat("Annualized Volatility:", round(StdDev.annualized(combined_returns$ret_eq) * 100, 2), "%\n")
cat("Sharpe Ratio:", round(Return.annualized(combined_returns$ret_eq) / StdDev.annualized(combined_returns$ret_eq), 3), "\n\n")

cat("Market Cap Weight Performance:\n")
cat("Annualized Return:", round(Return.annualized(combined_returns$ret_mkt) * 100, 2), "%\n")
cat("Annualized Volatility:", round(StdDev.annualized(combined_returns$ret_mkt) * 100, 2), "%\n")
cat("Sharpe Ratio:", round(Return.annualized(combined_returns$ret_mkt) / StdDev.annualized(combined_returns$ret_mkt), 3), "\n")

