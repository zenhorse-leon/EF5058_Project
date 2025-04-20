import pandas as pd
import os
import numpy as np


market_path = 'data_processed/market_month.csv'
stock_path = 'data_processed/combined_all.csv'


df_market = pd.read_csv(market_path)
df_stocks = pd.read_csv(stock_path)

stocks = df_stocks['code'].unique()

# factors:
# market, size, value, profitability, investment, momentum
df_stocks['size'] = df_stocks['t_mv'] / 1e8
df_stocks['value'] = 1. / df_stocks['t_pb'] # book to market
df_stocks['profitability'] = df_stocks['npta'] # net profit to total assets
df_stocks['investment'] = df_stocks['assets_yoy'] # total assets growth


df_factors = df_stocks[['code', 'name', 'date', 'return', 'size', 'value', 'profitability', 'investment', 'momentum']]

df_factors['market'] = df_factors['date'].apply(
    lambda date: np.nan if date not in df_market['date'].values else df_market[df_market['date'] == date]['market_return_ann'].values[0]
)

df_factors = df_factors.dropna()


df_factors.to_csv('data_processed/stock_factors.csv', index=False, float_format='%.4f')