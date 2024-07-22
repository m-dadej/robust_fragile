@time using LinearAlgebra
@time using Statistics
@time using DataFrames
@time using CSV
@time using MarSwitching
@time using GLM
@time using BenchmarkTools
@time using Tables
@time using Plots
using ShiftedArrays
using Dates
using DataFramesMeta

function std_err(X::Matrix, y::Vector, β::Vector)
    mse = mean((y .- X * β).^2)
    σ² = mse * (X'X)^(-1)
    return sqrt.(diag(σ²))
end    

replace_inf(x) = isinf(x) ? 0.0 : x

function granger_degree(x)
    return sum(replace_inf.(x)) / ((size(x)[2])^2 - size(x)[2] - sum(isinf.(x)))
end    

function unstack_ticker(df::DataFrame, ticker::String)
    ticker_df = @chain df begin
        filter(column -> column.ticker == (ticker), _)
        unstack(_)
        sort(_, :Date)
        dropmissing(_)
    end
    return ticker_df
end

function granger_cause(df::DataFrame)

    y = df.return
    X = [ones(length(y)) Matrix(df[:, Not(:return)])]
    
    β = (X'X) \ X'y
    Σ = std_err(X, y, β)
    
    lag_var_index = findall(names(df[:, Not(:return)]) .== "return_1")[1] + 1

    return β[lag_var_index], abs(β[lag_var_index] / Σ[lag_var_index]) > 1.96
end

function granger_mat(df::DataFrame, w::DataFrame)
    tickers = unique(df.ticker)

    network = zeros(size(tickers, 1), size(tickers, 1))

    for i in 1:size(tickers, 1)
        for j in 1:size(tickers, 1)

            if i == j
                continue
            end

            df_a = unstack_ticker(df, tickers[i])
            df_b = unstack_ticker(df, tickers[j])

            if "assets" ∉ names(df_a) || "assets" ∉ names(df_b)
                continue
            end
            
            link_weight = w[w.ticker .== tickers[i], "value_mean_function"][1]
            
            granger_df = @chain begin
                                    innerjoin(df_a, df_b, on = :Date, makeunique=true)
                                    select(_, [:return, :return_1, :lt_fund_share, :ib_share, :roa, :prof_ch])
                                    transform(_, :return_1 => (x -> lag(x, 1)) => :return_1,
                                                 #:return_1 => (x -> lag(x, 2)) => :return_2
                                                 )
                                    dropmissing(_)
                                end
            
            size(granger_df)[1] - size(granger_df)[2] > 10 ? nothing : continue              
            
            network[i,j] = granger_cause(granger_df)[2] ? link_weight : 0
        end
    end

    return network
end


unique(df.variable)
run(`py granger_ts.py
    --region eu
    --freq weekly`) # daily or weekly

data_raw = CSV.read("data/df_rets_granger.csv", DataFrame)
orbis_data = CSV.read("data/orbis_preproc.csv", DataFrame)
#orbis_data = subset(orbis_data, :comp => x -> x .!= "AIB GROUP PUBLIC LIMITED COMPANY")

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
df = sort(df, [:Date, :comp])

df_dates = unique(df.Date)

cor_w = 40

# average asset size
network_weight = @chain df begin
    filter(x -> (x.variable .== "assets"), _)
    dropmissing(_)
    groupby(_, :ticker)
    combine(_, :value => mean)
    transform(_, :value_mean => x -> (x / sum(x)))
end

granger_ts = zeros(length(cor_w:size(df_dates)[1]))

for t in cor_w:size(df_dates)[1]
    println("t: $t | $(round((t - cor_w+1) / size(cor_w:size(df_dates)[1])[1]*100, digits=2))")
    #println("$(round((t / size(cor_w:size(df_dates)[1])[1])*100, digits = 2)) %")
    window_df = filter(x -> (x.Date .>= df_dates[t-cor_w+1]) .& (x.Date .<= df_dates[t]), df)
    mat = granger_mat(window_df, network_weight)
    granger_ts[t - cor_w + 1] = granger_degree(mat)
end

plot(granger_ts)


CSV.write("data/bs_granger40_w_log.csv", 
          DataFrame(Date = df_dates[cor_w:end],
                    bs_granger = granger_ts))

 