using MarSwitching
using DataFrames
using CSV
using Statistics
using Plots

#using Pkg; Pkg.add.(["Distributions", "MarSwitching", "DataFrames", "CSV", "Statistics", "Plots", "GLM"])
# to do:
# - odjac kurs sp500 od indeksu 
# - odjąć tez od kursu banków?

# odejmij jakis AR proces of R
function remove_outlier(data::Matrix{Float64}; σ = 5)
    
    outliers = []
    for i in 1:size(data, 2)
        outliers = [outliers; findall(data[:,i] .> (mean(data[:,i]) + m * std(data[:,i])))]
    end

    return data[(1:end) .∉ (outliers,),:]
end

function remove_outlier(data::DataFrame; σ = 5) 
    
    outliers = []
    for col in names(data)
        
        df_col = data[!, col]
        if eltype(df_col) <: Number
            outliers = [outliers; findall(df_col .> (mean(df_col) + σ * std(df_col)))]
        end
    end

    return data[(1:end) .∉ (outliers,),:]
end

standard(x::Vector{Float64}) = (x .- mean(x)) ./ std(x)
standard(x::Matrix{Float64}) = (x .- mean(x, dims=1)) ./ std(x, dims=1)

ols(y::Vector{Float64}, X::Matrix{Float64}) = (X'X) \ X'y

function get_residual(df::DataFrame, y_name::Symbol, covariate_names::Vector{Symbol})
    
    covariates = Matrix(df[!, covariate_names])
    β = ols(df[!, y_name], covariates)
    df.residual = df[!, y_name] .- covariates * β

    return df
end

include("granger_functions.jl")
# download data
# args: region us/eu, freq weekly/daily
run(`py src/stocks_download.py
    --region us
    --freq weekly
    --cor_window 40
    --eig_k 1
    --excess False`)


function remove_outlier(data, m = 3)
    
    outliers = []
    for i in 1:size(data, 2)
        outliers = [outliers; findall(data[:,i] .> (mean(data[:,i]) + m * std(data[:,i])))]
    end

    return data[(1:end) .∉ (outliers,),:]
end


# Load data
#data = CSV.read("C:/Users/HP/Documents/julia/finansowe/contagion/data/bank_cor.csv", DataFrame)
data = CSV.read("src/data/bank_cor.csv", DataFrame)

#granger_df = CSV.read("data/granger_ts.csv", DataFrame)
granger_df = CSV.read("src/data/bs_granger84.csv", DataFrame)
data = sort(innerjoin(data, granger_df, on = :Date), :Date)

plot(granger_df.Date, granger_df.bs_granger, label = "banks_index")

benchmark_lags = 3
banks_index_lags = 3
vol_lags = 4
conn_lag = 1

connectedness = :bs_granger # :bs_granger, :eig or :cor_lw

model_df = @chain data begin
    select(_, [:banks_index, :index, connectedness])
    transform(_, :banks_index => (x -> ones(length(x))) => :intercept)
    transform(_, [:banks_index => (x -> lag(x, i)) => "banks_index_lag$i" for i in 1:banks_index_lags])
    transform(_, [:index => (x -> lag(x, i)) => "index_lag$i" for i in 1:benchmark_lags])
    dropmissing()
    get_residual(_, :banks_index, Symbol.(["index", ["banks_index_lag$i" for i in 1:banks_index_lags]..., ["index_lag$i" for i in 1:benchmark_lags]...]))
    transform(_, [connectedness => (x -> lag(x, i)) => "connectedness_lag$i" for i in 1:conn_lag])
    transform(_, [:residual => (x -> abs.(x)) => :vol])
    transform(_, [:vol => (x -> lag(x, i)) => "vol_lag$i" for i in 1:vol_lags])
    transform(_, :index => (x -> abs.(x)) => :index_vol)
    remove_outlier(_, σ = 5)
    dropmissing()
end

exog_switch = standard(Matrix(model_df[!, [["connectedness_lag$i" for i in 1:conn_lag]...]]))
#exog_switch = [standard(model_df[!, connectedness]) exog_switch]

exog = Matrix(model_df[!, [["vol_lag$i" for i in 1:vol_lags]...]])

model = MSModel(model_df.vol .* 100, 2, 
                exog_vars = exog .* 100,
                exog_switching_vars = exog_switch,
                random_search_em = 2,
                random_search = 1
                )


plot(smoothed_probs(model)[:,2])
summary_msm(model)

