


# notatki

- jeszcze raz sprawdz czy to nie problem ze connectedness jest autoskorelowane.
- dodaj w paperze ze to r_bank - r_banking_index (bo chcemy idiosyncratic rets)
- warto byc moze przepisac kod

- opisz wady i zalety billio vs diebold?
- niekorzystny efekt connectedness jest zgodny z acemoglu 2015 (banki nie internalizuja efektow zewnetrznych) jest jeszcze jakis paper co tez jest git - elliot? golub?
- eu connectedness seems on average smaller, which makes sense considering its a group of ocuntries, unlike USA.
- dodac grafike pokazujaca co to adjacency matrix i network w lit review???

# further research 

- VAR kontrolujacy o firm specific i macro do szacowania network

# do artykulu 

"According to Haldane (2013) “Network diagnostics ... may displace
atomised metrics such as VaR in the armoury of financial policymakers”. Network analysis,
moreover, does have a number of associated numerical measures or metrics that can prove helpful
in assessing how distinct networks differ from each other" -  z Bank of England Staff Working Paper No. 1,038

# balance sheet extension

nie dziala :

- cor_w = 36; x.numobs_function > 150; [:return, :return_1, :lt_fund_share, :ib_share, :roa, :prof_ch]

Dziala dla:

- cor_w = 40; x.numobs_function > 150; [:return, :return_1, :lt_fund_share, :ib_share, :roa, :prof_ch] - 0.065 p calue

- cor_w = 36; x.numobs_function > 150; [:return, :return_1, :lt_fund_share, :ib_share, :roa]

- cor_w = 36; x.numobs_function > 150; [:return, :return_1, :lt_fund_share, :ib_share, :roa, :prof_ch]

- cor_w = 36; x.numobs_function > 150 [:return, :return_1, :ib_share, :roa, :prof_ch] - 0.073 p value



