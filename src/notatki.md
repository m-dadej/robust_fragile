
# to do:
- moze degree/density metric policzyc tylko na wartościach bez Inf - jak narazie density jest liczone N^2 - N
- Granger_bs musi takze miec dane z ETF - jak narazie nie ma

- opisz financial network externality w wynikach ze moze przez to jest ta asymetria efektu.

# notatki

- jeszcze raz sprawdz czy to nie problem ze connectedness jest autoskorelowane.
- warto byc moze przepisac kod

- niekorzystny efekt connectedness jest zgodny z acemoglu 2015 (banki nie internalizuja efektow zewnetrznych) jest jeszcze jakis paper co tez jest git - elliot? golub?

# further research 

# do artykulu 

"According to Haldane (2013) “Network diagnostics ... may displace
atomised metrics such as VaR in the armoury of financial policymakers”. Network analysis,
moreover, does have a number of associated numerical measures or metrics that can prove helpful
in assessing how distinct networks differ from each other" -  z Bank of England Staff Working Paper No. 1,038

# balance sheet extension

nie dziala :

- 40, non weigthed, [:return, :return_1,   :roa,  :assets, :ib_net_save]

- 40, weighted, [:return, :return_1,:prof_ch, :lt_fund_share,  :roa,  :assets, :ib_net_save]

- 40, weighted,  :return, :return_1, :prof_ch,  :roa,   :assets, :ib_net_save

- 40, non weigthed,  [:return, :return_1, :prof_ch,   :assets, :ib_net_save]

- 56 weight, [:return, :return_1, :prof_ch,  :lt_fund_share, :assets, :ib_net_save]

- 56, weight, [:return, :return_1, :prof_ch,  :roa, :assets, :ib_net_save]

- 84 no weight, [:return, :return_1, :prof_ch,  :lt_fund_share, :assets, :ib_net_save]
 
- 84 no weight, [:return, :return_1, :prof_ch,  :assets, :ib_net_save]

Dziala dla:

- 56 no weight, [:return, :return_1, :prof_ch,  :lt_fund_share, :assets, :ib_net_save]

- 56 no weight, [:return, :return_1, :prof_ch,  :assets, :ib_net_save]

- 56 no weight,  [:return, :return_1, :roa, :depo_share, :assets, :ib_net_save]
