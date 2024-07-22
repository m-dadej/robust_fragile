import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression

df = pd.read_excel('data/Export 14_04_2024 14_01.xlsx', sheet_name = 'Results')
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
df.quarter = pd.to_numeric(df.quarter) * 4 * 30
df['date'] = pd.to_datetime('01/03/2024', dayfirst = True, format = "%d/%m/%Y") - pd.to_timedelta(df.quarter, unit='D')

df.groupby(['variable']).value.apply(lambda x: x.isna().sum() / len(x) * 100).sort_values(ascending=False)

df = df.dropna(subset = 'value').drop('quarter', axis=1)
df = df[~df.variable.isin(['nti', 'div', 'cds', 'derivsassets', 'derivsliabs'])] # not enough data for these variables

# For each company, for each balance sheet variable add monday dates in between each quarter
# The new rows are empty
for i_comp in df.comp.unique():
    country = df[df.comp == i_comp].Country.iloc[0]
    print(i_comp + ' | ' + country)
    for i_variable in df[df.comp == i_comp].variable.unique(): 
        for i_date in df[(df.comp == i_comp) & (df.variable == i_variable)].date.unique(): 
            # get the monday dates of the last quarter
            date_range = pd.date_range(start=i_date - pd.to_timedelta(11 * 7, unit='D'),
                                       end=i_date, freq='W-MON')
            # introduce them into the dataframe
            for week_i in date_range:           
                new_row = pd.DataFrame({'comp': i_comp, 'Country': country, 'variable': i_variable, 'value': pd.NA, 'date': week_i}, index=[0])
                df = pd.concat([df, new_row], ignore_index=True)


df.loc[(df.comp == "ABN AMRO BANK NV") & (df.variable == "assets")].sort_values('date')

df.sort_values(['comp', 'variable', 'date'], inplace=True)
df.reset_index(drop=True,inplace=True)
df['month'] = pd.DatetimeIndex(df['date']).month

# interpolate the weeks from quarter data using cubic spline
df = df.assign(value = df.groupby(['comp', 'variable']).value\
        .apply(lambda x: x.interpolate(method='cubicspline'))\
        .reset_index(drop=True))\
        .dropna()

df = df[~df.drop(['value'], axis = 1).duplicated()]

# Add the ticker symbol for each company
to_ticker = {'ABN AMRO BANK NV' : 'ABN.AS',
            'AIB GROUP PUBLIC LIMITED COMPANY': 'A5G.IR',
       'ALPHA SERVICES AND HOLDINGS SOCIETE ANONYME': 'ALPHA.AT',
       'BANCA MONTE DEI PASCHI DI SIENA SPA': 'MB.MI',
       'BANCO BILBAO VIZCAYA ARGENTARIA SA': 'BBVA', 'BANCO BPM SPA': 'BAMI.MI',
       'BANCO COMERCIAL PORTUGUES, SA': 'BCP.LS', 
       'BANCO DE SABADELL SA': 'SAB.MC',
       'BANCO SANTANDER SA': 'SAN.MC',
       'BANK OF IRELAND': 'BIRG.IR',
       'BANK POLSKA KASA OPIEKI SA': 'PEO.WA',
       'BANKINTER SA' : 'BKT.MC',
        'BARCLAYS PLC': 'BARC.L', 
       'BNP PARIBAS': 'BNP.PA', 
       'BPER BANCA S.P.A.': 'BPE.MI',
       'CAIXABANK, S.A.': 'CABK.MC', 
       'COMMERZBANK AG': 'CBK.DE',
        'CREDIT AGRICOLE SA': 'ACA.PA',
       'DANSKE BANK A/S': 'DANSKE.CO', 
       'DEUTSCHE BANK AG': 'DBK.DE', 
       'DNB BANK ASA': 'DNB.OL',
       'ERSTE GROUP BANK AG': 'EBO.DE',
       'EUROBANK ERGASIAS SERVICES AND HOLDINGS SA': 'EUROB.AT', 
       'ING GROEP NV': 'INGA.AS',
       'INTESA SANPAOLO S.P.A.': 'ISP.MI', 
       'JYSKE BANK A/S': 'JYSK.CO',
       'KBC GROEP NV/ KBC GROUPE SA': 'KBC.BR',
       'MEDIOBANCA - BANCA DI CREDITO FINANZIARIO SOCIETA PER AZIONI': 'MB.MI',
       'NATIONAL BANK OF GREECE SA': 'ETE.AT',
        'NORDEA BANK ABP': 'NDA-SE.ST', 
       'OTP BANK PLC': 'OTP.BD',
       'PIRAEUS FINANCIAL HOLDINGS SA': 'TPEIR.AT',
       'POWSZECHNA KASA OSZCZEDNOSCI BANK POLSKI SA - PKO BP SA': 'PKO.WA',
       'RAIFFEISEN BANK INTERNATIONAL AG': 'RAW.DE',
       'SKANDINAVISKA ENSKILDA BANKEN AB': 'SEB-A.ST',
        'SOCIETE GENERALE': 'GLE.PA',
       'SVENSKA HANDELSBANKEN AB': 'SHB-A.ST',
        'SWEDBANK AB': 'SWED-A.ST',
        'SYDBANK A/S': 'SYDB.CO',
       'UNICAJA BANCO SA': 'UNI.MC',
        'UNICREDIT SPA': 'UCG.MI'}

df['ticker'] = df.comp.map(to_ticker)
df[df.comp == 'UNICAJA BANCO SA']

df_long = df.pivot(index=['comp', 'date', 'month', 'Country', 'ticker'], 
         columns=['variable'], values='value')\
    .reset_index()\
    .assign(ib_share = lambda x: x.ibassets / x.assets,
            lt_fund_share = lambda x: x.ltfunding / x.assets,
            roa = lambda x: x.opincome / x.assets,
            nii_share = lambda x: x.nii / x.opincome,
            ib_net_save = lambda x: x.ibassets / x.ibliab,
            depo_share = lambda x: x.depo / x.assets,
            log_assets = lambda x: np.log(x.assets))

df_long.assign(prof_ch = df_long.groupby('comp').opincome.pct_change())\
    .melt(id_vars=['comp', 'date', 'month', 'Country', 'ticker'],
          var_name='variable', value_name='value')\
    .to_csv('data/orbis_preproc.csv', index=False)
