using Latexify, DataFrames, CSV,  Dates

# ...or use the archived data
data_raw = CSV.read("src/data/archive/df_rets_granger_eu_weekly.csv", DataFrame)

# number of observations per group
@chain orbis_data begin
    groupby(_, :comp)
    combine(_, nrow)
    sort(_, :nrow, rev = false)
end

df = @chain data_raw begin
    stack(_, Not(:Date))
    rename(_, Dict(:variable => :ticker, :value => :return))
    innerjoin(_, rename(orbis_data, :date => :Date), on = [:ticker, :Date])
end

top_names = @chain df begin
    select(_, Not(:month, :Country, :ticker))
    dropmissing(_)
    groupby(_, [:comp, :variable])
    combine(_, nrow => :numobs)
    groupby(_, :comp)
    combine(_, :numobs .=> x -> minimum(x))
    filter(x -> (x.numobs_function > 150), _)
end

df = filter((x)-> x.comp in top_names.comp, df)
# :roa,  :assets, :ib_net_save
descr_df = @chain df begin
    filter(x -> (x.Date == Date("2023-01-02")) , _)
    filter(x -> (x.variable in ["ibliab", "ibassets", "opincome", "assets","roa", "ib_net_save"]), _)
    dropmissing()
    groupby(_, :variable)
    combine(_, [:value => mean,
                :value => median,
                :value => std,
                :value => minimum,
                :value => maximum])
            
end    

descr_df.variable = String.(descr_df.variable) 
print(latexify(descr_df, env = :table, latex = false))
