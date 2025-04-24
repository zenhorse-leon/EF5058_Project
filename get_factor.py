import pandas as pd
import os
import numpy as np
import copy

factor_path = 'data_processed/stock_factors.csv'

if not os.path.exists(factor_path):
    market_path = 'data_processed/market_month.csv'
    stock_path = 'data_processed/combined_all.csv'


    df_market = pd.read_csv(market_path)
    df_stocks = pd.read_csv(stock_path)

    stocks = df_stocks['code'].unique()

    # factors:
    # market, size, value, profitability, investment, momentum
    df_stocks['size'] = df_stocks['t_mv'] / 1e8
    df_stocks['value'] = 1. / df_stocks['t_pb'] # book to market
    df_stocks['profitability'] = df_stocks['npta'] / 100 # net profit to total assets
    df_stocks['investment'] = df_stocks['assets_yoy'] / 100 # total assets growth


    df_factors = df_stocks[['code', 'name', 'date', 'return', 'size', 'value', 'profitability', 'investment', 'momentum']]

    df_factors['market'] = df_factors['date'].apply(
        lambda date: np.nan if date not in df_market['date'].values else df_market[df_market['date'] == date]['market_return_ann'].values[0]
    )

    df_factors = df_factors.dropna()
    df_factors.to_csv('data_processed/stock_factors.csv', index=False, float_format='%.4f')

else:
    df_factors = pd.read_csv(factor_path)
    df_factors['date'] = df_factors['date'].astype(str)


def update_portfolio(portfolio_year, data):

    cols = portfolio_year.keys()

    for col in cols:
        ratio = portfolio_year[col]['ratio']
        assending = portfolio_year[col]['assending']
        df_rank = data.sort_values(by=col, ascending=assending)

        df_top = df_rank.head(int(len(df_rank) * ratio))
        df_bottom = df_rank.tail(int(len(df_rank) * ratio))

        portfolio_year[col]['top'] += df_top['code'].values.tolist()
        portfolio_year[col]['bot'] += df_bottom['code'].values.tolist()

    return

def update_factors(portfolio_year, data):

    factor_dict = {
        'size': 'SMB',
        'value': 'HML',
        'profitability': 'RMW',
        'investment': 'CMA',
        'momentum': 'UMD'
    }
    cols = portfolio_year.keys()

    data_new = data[['code', 'name', 'date', 'return', 'market']].copy()
    for col in cols:
        top_codes = portfolio_year[col]['top']
        bot_codes = portfolio_year[col]['bot']
        df_top = data[data['code'].isin(top_codes)]
        df_bottom = data[data['code'].isin(bot_codes)]
        factor = df_top['return'].mean() - df_bottom['return'].mean()
        data_new[factor_dict[col]] = [factor] * len(data_new)

    return data_new

# get portfolio factor

years = np.arange(2000, 2025)
months = np.arange(1, 13)

portfolio_tmp = {'size': {'top': [], 'bot': [], 'ratio': 0.2, 'assending': True}, 
              'value': {'top': [], 'bot': [], 'ratio': 0.2, 'assending': False}, 
              'profitability': {'top': [], 'bot': [], 'ratio': 0.2, 'assending': False}, 
              'investment': {'top': [], 'bot': [], 'ratio': 0.2, 'assending': False}, 
              'momentum': {'top': [], 'bot': [], 'ratio': 0.2, 'assending': False}
            }

portfolios = {}

df_factor_processed = pd.DataFrame()
for year in years:
    
    for month in months:
        if year == 2000 or (year == 2001 and month < 4):
            continue
        date = '%d%02d01' % (year, month)
        df_sel = df_factors[df_factors['date'] == date]
        if month == 4:
            portfolios[year] = copy.deepcopy(portfolio_tmp)
            update_portfolio(portfolios[year], df_sel)

            # print('top', len(portfolios[year]['size']['top']))
            # print('bot', len(portfolios[year]['size']['bot']))

            portfolios['latest'] = copy.deepcopy(portfolios[year])

        df_cal = update_factors(portfolios['latest'], df_sel)
        df_factor_processed = pd.concat([df_factor_processed, df_cal], axis=0, ignore_index=True)

            
df_factor_processed.to_csv('data_processed/stock_factors_processed.csv', index=False, float_format='%.6f')