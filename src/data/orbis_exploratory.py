import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression

df = pd.read_excel('src/data/Export 14_04_2024 14_01.xlsx', sheet_name = 'Results')
#df.columns.str.replace(r'(\d*\.\d+|\d+)', '', regex=True).unique()

df.drop(df.filter(regex=' yr').columns, axis=1, inplace=True)

df.columns = df.columns.str.replace('Credit Default Swaps – Spread 5 years Senior Unsecurred\n', 'cds_')
df.columns = df.columns.str.replace('Total assets\nth EUR ', 'assets_')
df.columns = df.columns.str.replace('Last avail. quarter', '')
df.columns = df.columns.str.replace('Interbank assets\n', 'ib_assets_')
df.columns = df.columns.str.replace('Derivative financial instruments (Assets)\n', 'derivs_assets_')
df.columns = df.columns.str.replace('Net loans & advances to customers\n', 'loans_')
df.columns = df.columns.str.replace('Interbank liabilities\n', 'ib_liab')
df.columns = df.columns.str.replace('Derivative financial instruments (Liabilities)\n_th EUR ', 'derivs_liabs_')
df.columns = df.columns.str.replace('Derivative financial instruments (Liabilities)\n', 'derivs_liabs_')
df.columns = df.columns.str.replace('Total equity\n', 'derivs_liabs_')
df.columns = df.columns.str.replace('Long-term funding\n', 'lt_funding_')
df.columns = df.columns.str.replace('Total customer deposits\n', 'depo_')
df.columns = df.columns.str.replace('Net interest income (expense)\n', 'nii_')
df.columns = df.columns.str.replace('Net trading income (losses) on securities and derivatives\n', 'nti_')
df.columns = df.columns.str.replace('Net impairment charges on loans & advances\n', 'impairment_')
df.columns = df.columns.str.replace('Operating Income\n', 'op_income_')
df.columns = df.columns.str.replace('Common and Preferred dividends declared\n', 'div_')
df.columns = df.columns.str.replace('Common and Preferred dividends declared\n', 'div_')
df.columns = df.columns.str.replace('Quarter - ', '')
df.columns = df.columns.str.replace('th EUR Last avail. yr', '')
df.columns = df.columns.str.replace('th EUR ', '')
df.columns = df.columns.str.replace('Last avail. yr', '')
df.rename(columns = {'Company name Latin alphabet': 'comp'}, inplace = True)
df.drop(['Unnamed: 0'], axis=1, inplace=True)
df = df[df.comp != 'BANK OF IRELAND GROUP PLC'] # BANK OF IRELAND has more non-na values

id_vars = ['comp', 'Country']

df = df.melt(id_vars=id_vars)

df['quarter'] = df.variable.str.extract(r'(\d*\.\d+|\d+)', expand=False)
df.replace({'quarter': pd.NA}, 0, inplace=True)
df.replace({'value':'n.a.'}, pd.NA, inplace=True)

df.value = pd.to_numeric(df.value, errors='coerce')
df.variable = df.variable.str.replace(r'(\d*\.\d+|\d+)', '', regex=True)
df.variable = df.variable.str.replace('_', '', regex=True)
df.quarter = pd.to_numeric(df.quarter) * 3 * 30
df['date'] = pd.to_datetime('31/03/2024', dayfirst = True, format = "%d/%m/%Y") - pd.to_timedelta(df.quarter, unit='D')

df.groupby(['variable']).value.apply(lambda x: x.isna().sum() / len(x) * 100).sort_values(ascending=False)

df = df.dropna(subset = 'value').drop('quarter', axis=1)
df = df[~df.variable.isin(['nti', 'div', 'cds', 'derivsassets', 'derivsliabs'])] # not enough data for these variables
