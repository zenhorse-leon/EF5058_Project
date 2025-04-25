
import os
import numpy as np
import pandas as pd
from tushare_fetcher import TushareFetcher
import yaml
from tqdm import tqdm

cfg_path = './configs/config.yml'

with open(cfg_path, 'r') as file:
    configs = yaml.safe_load(file)

token = configs['token']

tushare_fetcher = TushareFetcher(token)

years = np.arange(2000, 2025)
start_date = '%d1231' % years[0]
end_date = '%d1231' % years[-1]

out_dir = './data/'
if not os.path.exists(out_dir):
    os.makedirs(out_dir)


df_int = pd.DataFrame()

for year in years:
    start_date = '%d0101' % year
    end_date = '%d1231' % year
    df_year = tushare_fetcher.pro.shibor(start_date=start_date, end_date=end_date)
    df_int = pd.concat([df_int, df_year], axis=0)
df_int = df_int.sort_values(by='date', ascending=True)
df_int['date'] = df_int['date'].astype(str)
df_int = df_int.drop_duplicates(subset=['date'], keep='last')
df_int.to_csv(os.path.join(out_dir, 'shibor.csv'), index=False)


path_stock_basic = os.path.join(out_dir, 'stock_basic.csv')
if os.path.exists(path_stock_basic):
    stock_basic = pd.read_csv(path_stock_basic)
else:
    stock_basic = tushare_fetcher.get_stock_basic()
    stock_basic.to_csv(path_stock_basic, index=False)

path_trade_cal = os.path.join(out_dir, 'trade_cal.csv')
if os.path.exists(path_trade_cal):
    trade_cal = pd.read_csv(path_trade_cal)
    trade_cal['cal_date'] = trade_cal['cal_date'].astype(str)
else:
    trade_cal = tushare_fetcher.get_trade_calendar(start_date, end_date)
    trade_cal = trade_cal.sort_values(by='cal_date', ascending=True)
    trade_cal.to_csv(path_trade_cal, index=False)

last_date = trade_cal.iloc[-1]['cal_date']

con_path = os.path.join(out_dir, 'index_con.csv')
if os.path.exists(con_path):
    index_con = pd.read_csv(con_path)
else:
    index_con = tushare_fetcher.pro.index_weight(index_code='399300.SZ', trade_date=last_date)
    index_con.to_csv(con_path, index=False)

code_list = index_con['con_code'].values

path_latest_basic = os.path.join(out_dir, 'latest_basic.csv')
if os.path.exists(path_latest_basic):
    latest_basic = pd.read_csv(path_latest_basic)
else:
    latest_basic = tushare_fetcher.get_daily_basic_one(last_date)
    latest_basic.to_csv(path_latest_basic, index=False)
latest_basic = latest_basic.sort_values(by='total_mv', ascending=False)


# filter banks and ensurance
bank_industry = ['银行', '保险']
stock_selected = stock_basic[~stock_basic['industry'].isin(bank_industry)]
stock_selected = stock_selected[stock_selected['ts_code'].isin(code_list)]

codes = stock_selected['ts_code']
print(len(codes))

universe = []
# codes = latest_basic['ts_code'].values[:10]

for code in codes:
    name = stock_basic[stock_basic['ts_code'] == code]['name'].values[0]
    universe.append({'code': code, 'name': name})
# print(universe)
universe_df = pd.DataFrame(universe)
universe_df.to_csv(os.path.join(out_dir, 'universe.csv'), index=False)

for stock in tqdm(universe, dynamic_ncols=True):
    path_stock = os.path.join(out_dir, f"{stock['code']}.csv")
    if os.path.exists(path_stock):
        stock_df = pd.read_csv(path_stock)
    else:
        stock_df = tushare_fetcher.get_daily_data(stock['code'], start_date, end_date)
        stock_df = stock_df.sort_values(by='trade_date', ascending=True)
        stock_df.to_csv(path_stock, index=False)

    path_basic = os.path.join(out_dir, f"{stock['code']}_basic.csv")
    if os.path.exists(path_basic):
        basic_df = pd.read_csv(path_basic)
    else:
        basic_df = tushare_fetcher.get_daily_basic(stock['code'], start_date, end_date)
        basic_df = basic_df.sort_values(by='trade_date', ascending=True)
        basic_df.to_csv(path_basic, index=False)
    
    path_financial = os.path.join(out_dir, f"{stock['code']}_financial.csv")

    if os.path.exists(path_financial):
        financial_df = pd.read_csv(path_financial)
    else:
        financial_dict = []
        for year in years:
            periods = ['%d0630' % year, '%d1231' % year]
            # periods = ['%d1231' % year]
            for period in periods:
                financial_year_df = tushare_fetcher.get_fina_indicator_one(stock['code'], period)
                if len(financial_year_df) == 0:
                    continue
                financial_year_df = financial_year_df.sort_values(by='end_date', ascending=True)
                financial_year_df = financial_year_df.head(1)
                year_dict = financial_year_df.to_dict(orient='records')
                financial_dict.append(year_dict[0])

        financial_df = pd.DataFrame(financial_dict)
        financial_df.to_csv(path_financial, index=False)

    
for code in tushare_fetcher.index_list:
    path_index = os.path.join(out_dir, f"index_{code}.csv")
    if os.path.exists(path_index):
        index_df = pd.read_csv(path_index)
    else:
        index_df = tushare_fetcher.get_index_data(code, start_date, end_date)
        index_df = index_df.sort_values(by='trade_date', ascending=True)
        index_df.to_csv(path_index, index=False)

