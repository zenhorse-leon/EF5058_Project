import tushare as ts
import pandas as pd
from datetime import datetime, timedelta

class TushareFetcher:
    def __init__(self, token):
        self.pro = ts.pro_api(token)
        self.limit = 6000
        self.limit_per_min = 200

        self.index_list = ['000001.SH', '000300.SH', '399300.SZ']
        
    def get_stock_basic(self):
        """Get basic information of all stocks"""
        return self.pro.stock_basic(
            exchange='',
            list_status='L',
            fields='ts_code,symbol,name,area,industry,list_date'
        )
    
    def get_trade_calendar(self, start_date, end_date):
        """Get trading calendar"""
        return self.pro.trade_cal(
            start_date=start_date,
            end_date=end_date,
            is_open='1',
            fields='cal_date,is_open'
        )
    
    def get_daily_data(self, ts_code, start_date, end_date):
        """Get daily trading data for a specific stock"""
        return self.pro.daily(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            fields='ts_code,trade_date,open,high,low,close,pct_chg,vol,amount'
        )
    
    def get_daily_data_one(self, trade_date):
        """Get daily trading data for a specific stock"""
        return self.pro.daily(
            trade_date=trade_date,
            fields='ts_code,trade_date,open,high,low,close,pct_chg,vol,amount'
        )
    
    def get_daily_basic(self, ts_code, start_date, end_date):
        """Get daily basic data for a specific stock"""
        return self.pro.daily_basic(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            fields='ts_code,trade_date,turnover_rate,volume_ratio,pe,pe_ttm,pb,dv_ratio,dv_ttm,total_share,float_share,total_mv,circ_mv'
        )

    def get_daily_basic_one(self, trade_date):
        """Get daily basic data for a specific stock"""
        return self.pro.daily_basic(
            trade_date=trade_date,
            fields='ts_code,trade_date,turnover_rate,volume_ratio,pe,pe_ttm,pb,dv_ratio,dv_ttm,total_share,float_share,total_mv,circ_mv'
        )
    
    def get_index_data_one(self, ts_code, trade_date):
        """Get daily trading data for a specific stock"""
        return self.pro.index_daily(
            ts_code=ts_code,
            trade_date=trade_date,
            fields='ts_code,trade_date,open,high,low,close,pct_chg,vol,amount'
        )
    
    def get_index_basic_one(self, trade_date):
        """Get daily basic data for a specific stock"""
        return self.pro.index_dailybasic(
            trade_date=trade_date,
            fields='ts_code,trade_date,turnover_rate,pe,pe_ttm,pb,total_share,float_share,total_mv'
        )
    
    def get_index_basic(self, ts_code, start_date, end_date):
        """Get basic information of all indices"""
        return self.pro.index_dailybasic(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            fields='ts_code,trade_date,turnover_rate,pe,pe_ttm,pb,total_share,float_share,total_mv'
        ) 
    
    def get_index_data(self, ts_code, start_date, end_date):
        """Get daily trading data for a specific stock"""
        return self.pro.index_daily(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            fields='ts_code,trade_date,open,high,low,close,pct_chg,vol,amount'
        )
    
    def get_fina_indicator(self, ts_code, start_date, end_date):
        """Get financial indicators for a specific stock"""
        return self.pro.fina_indicator(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            # fields='ts_code,end_date,eps,current_ratio,quick_ratio,roe'
        )
    
    def get_fina_indicator_one(self, ts_code, period):
        """Get financial indicators for a specific stock"""
        return self.pro.fina_indicator(
            ts_code=ts_code,
            period=period,
        )
    
    def get_index_daily(self, ts_code, start_date, end_date):
        """Get daily index data"""

        return self.pro.index_dailybasic(
            trade_date='20250327',
            )
        return self.pro.index_daily(
            ts_code=ts_code,
            start_date=start_date,
            end_date=end_date,
            fields='ts_code,trade_data,open,high,low,close,pct_chg,vol,amount'
        )
    
    
   