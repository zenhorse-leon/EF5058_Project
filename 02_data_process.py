import pandas as pd
import os
import numpy as np
from glob import glob
from tqdm import tqdm
from datetime import datetime
from dateutil.relativedelta import relativedelta

out_month= 'data_month'
if not os.path.exists(out_month):
    os.makedirs(out_month)
out_dir = 'data_processed'
if not os.path.exists(out_dir):
    os.makedirs(out_dir)

universe_path = './data/universe.csv'
universe = pd.read_csv(universe_path).to_dict(orient='records')
# print(universe)

date_path = './data/trade_cal.csv'
trade_cal = pd.read_csv(date_path)
trade_cal['cal_date'] = pd.to_datetime(trade_cal['cal_date'], format='%Y%m%d')
dates = trade_cal['cal_date'].dt.strftime('%Y%m%d').tolist()
print(len(dates))

years = np.arange(2000, 2025)
months = np.arange(1, 13)

fin_paths = glob(os.path.join('./data', '*_financial.csv'))
fin_codes = []
for fin_path in fin_paths:
    code = os.path.basename(fin_path).split('_')[0]
    fin_codes.append(code)


index_df = pd.read_csv(os.path.join('./data', 'index_000001.SH.csv'))
index_df['trade_date'] = index_df['trade_date'].astype(str)

market_dict = []
for year in years:
    for month in months:
        start_m = '%d%02d01' % (year, month)
        end_m = '%d%02d31' % (year, month)
        month_df = index_df[(index_df['trade_date'] >= start_m) & (index_df['trade_date'] <= end_m)]
        month_df = month_df.dropna(subset=['pct_chg'])

        if not month_df.empty:
            return_month = (np.exp(np.sum(np.log(1 + month_df['pct_chg'] / 100))) - 1)
        else:
            return_month = np.nan

        end_m = '%d%02d01' % (year, month)
        current_date = datetime.strptime(end_m, '%Y%m%d')
        period_start = current_date - relativedelta(months=6)
        period_start = period_start.strftime('%Y%m%d')

        ref_index = index_df[(index_df['trade_date'] >= period_start) & (index_df['trade_date'] < end_m)]
        if not ref_index.empty:
            ref_index = ref_index.dropna(subset=['pct_chg'])
            market_return_ann = (np.exp(np.mean(np.log(1 + ref_index['pct_chg'] / 100)) * 220) - 1)
        else:
            market_return_ann = np.nan

        market_dict.append({
            'date': '%d%02d01' % (year, month),
            'market_return_ann': market_return_ann,
            'market_return_month': return_month,
            
        })
market_df = pd.DataFrame(market_dict)
market_df = market_df.sort_values(by='date', ascending=True).dropna()
market_df.to_csv(os.path.join(out_dir, 'market_month.csv'), index=False, float_format='%.4f')
        


df_combined_all = pd.DataFrame()
for stock in tqdm(universe, dynamic_ncols=True):
    if stock['code'] not in fin_codes:
        continue

    stock['code']

    stock_path = os.path.join('./data', f"{stock['code']}.csv")
    stock_df = pd.read_csv(stock_path)
    stock_df['trade_date'] = stock_df['trade_date'].astype(str)

    basic_path = os.path.join('./data', f"{stock['code']}_basic.csv")
    basic_df = pd.read_csv(basic_path)
    basic_df['trade_date'] = basic_df['trade_date'].astype(str)

    financial_df = pd.read_csv(os.path.join('./data', f"{stock['code']}_financial.csv"))
    financial_df['end_date'] = financial_df['end_date'].astype(str)

    month_dict = []
    basic_dict = []
    fin_dict = []
    for year in years:
        for month in months:
            start_m = '%d%02d01' % (year, month)
            end_m = '%d%02d31' % (year, month)

            month_df = stock_df[(stock_df['trade_date'] >= start_m) & (stock_df['trade_date'] <= end_m)]
            month_df = month_df.dropna(subset=['pct_chg'])
            if not month_df.empty:
                
                # Example date
                current_date = datetime.strptime(start_m, '%Y%m%d')
                period_start = current_date - relativedelta(months=6)
                period_start = period_start.strftime('%Y%m%d')

                period_end = start_m

                ref_data = stock_df[(stock_df['trade_date'] >= period_start) & (stock_df['trade_date'] < period_end)]

                if not ref_data.empty:
                    ref_data = ref_data.dropna(subset=['pct_chg'])
                    vol = (ref_data['pct_chg'] / 100).std() / len(ref_data) * 220
                    momentum = (np.exp(np.mean(np.log(1 + ref_data['pct_chg'] / 100)) * 220) - 1)
                else:
                    vol = np.nan
                    momentum = np.nan

                open = month_df['open'].values[0]
                close = month_df['close'].values[-1]

                return_month = (np.exp(np.sum(np.log(1 + month_df['pct_chg'] / 100))) - 1)
                
                month_dict.append({
                    'code': stock['code'],
                    'name': stock['name'],
                    'date': '%d%02d01' % (year, month),
                    'open': open,
                    'close': close,
                    'return': return_month,
                    'vol': vol,
                    'momentum': momentum,
                })

            basic_month_df = basic_df[(basic_df['trade_date'] >= start_m) & (basic_df['trade_date'] <= end_m)]
            if not month_df.empty and len(basic_month_df) > 0:

                t_mv = basic_month_df['total_mv'].values[0]
                t_pb = basic_month_df['pb'].values[0]
                t_pe = basic_month_df['pe_ttm'].values[0]
                basic_dict.append({
                    'code': stock['code'],
                    'name': stock['name'],
                    'date': '%d%02d01' % (year, month),
                    'total_share': basic_month_df['total_share'].values[0],
                    't_mv': t_mv,
                    't_pb': t_pb,
                    't_pe': t_pe,
                })


            # 'roe', 'roa', 'debt_to_assets'
            # assign financial to month
            if month > 3:
                fin_month = '%d1231' % (year)
            elif month <= 3:
                fin_month = '%d1231' % (year - 1)

            fin_ref_df = financial_df[financial_df['end_date'] == fin_month]
            if not fin_ref_df.empty:

                fin_dict.append({
                    'code': stock['code'],
                    'name': stock['name'],
                    'date': '%d%02d01' % (year, month),
                    'roe': fin_ref_df['roe'].values[0],
                    'roa': fin_ref_df['roa'].values[0],
                    'npta': fin_ref_df['npta'].values[0], # 总资产净利润
                    'assets_yoy': fin_ref_df['assets_yoy'].values[0], # 总资产同比增长率
                    'bps': fin_ref_df['bps'].values[0], # 每股净资产
                    'debt_to_assets': fin_ref_df['debt_to_assets'].values[0],
                })
        
            
    stock_month_df = pd.DataFrame(month_dict)
    stock_month_df = stock_month_df.sort_values(by='date', ascending=True)
    stock_month_df.to_csv(os.path.join(out_month, f"{stock['code']}_month.csv"), index=False, float_format='%.4f')

    stock_month_df = stock_month_df.set_index(['code', 'name', 'date'])

    basic_month_df = pd.DataFrame(basic_dict)
    basic_month_df = basic_month_df.sort_values(by='date', ascending=True)
    basic_month_df.to_csv(os.path.join(out_month, f"{stock['code']}_basic_month.csv"), index=False, float_format='%.4f')
    basic_month_df = basic_month_df.set_index(['code', 'name', 'date'])

    fin_month_df = pd.DataFrame(fin_dict)
    fin_month_df = fin_month_df.sort_values(by='date', ascending=True)
    fin_month_df.to_csv(os.path.join(out_month, f"{stock['code']}_fin_month.csv"), index=False, float_format='%.4f')
    fin_month_df = fin_month_df.set_index(['code', 'name', 'date'])

    df_combined = stock_month_df.join(basic_month_df, how='left', rsuffix='_basic')
    df_combined = df_combined.join(fin_month_df, how='left', rsuffix='_fin')
    df_combined = df_combined.reset_index()
    df_combined.to_csv(os.path.join(out_month, f"{stock['code']}_combined.csv"), index=False, float_format='%.4f')

    df_combined_all = pd.concat([df_combined_all, df_combined], axis=0)
    
df_combined_all.to_csv(os.path.join(out_dir, 'combined_all.csv'), index=False, float_format='%.4f')

    
# def combine_all_horizontal(out_month):
#     all_files = glob(os.path.join(out_month, '*_combined.csv'))
#     combined_df = pd.DataFrame()
    
#     columns = ['code', 'close','t_mv','t_pb','t_pe','roe','roa','debt_to_assets','vol']

#     df_list = {}
#     universe = []
#     for path in all_files:
#         df = pd.read_csv(path)
#         name = df['name'].values[0]
#         universe.append(name)
#         df = df.sort_values(by='date', ascending=True)
#         df = df.set_index('date')
#         df.index = pd.to_datetime(df.index, format='%Y%m%d')
#         df_list[name] = df
    

#     combined_df = pd.DataFrame(index=df_list[universe[0]].index)
#     multi_columns = pd.MultiIndex.from_product([universe, columns])

    
#     for code in universe:
#         for col in columns:
#             combined_df[(code, col)] = df_list[code][col]

#     combined_df.columns = multi_columns
    

#     return combined_df

# df = combine_all_horizontal(out_month)
# df.to_csv(os.path.join(out_dir, 'combined_all_horizontal.csv'), index=True)


