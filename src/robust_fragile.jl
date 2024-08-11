using MarSwitching
using DataFrames
using DataFramesMeta 
using CSV
using Statistics
using Plots
using ShiftedArrays: lag

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


# download data
# args: region us/eu, freq weekly/daily
run(`py src/stocks_download.py
    --region eu
    --freq weekly
    --cor_window 63
    --eig_k 1
    --excess False`)

# get the new data...
#granger_df = CSV.read("src/data/granger_ts.csv", DataFrame)
#data = CSV.read("src/data/bank_cor.csv", DataFrame)

# ...or the one archived
cor_window = 256 #63 or 256
market = "eu"
weekly = "" # "" or "_weekly"
granger_df = CSV.read("src/data/archive/granger_ts_$cor_window$market$weekly.csv", DataFrame)
data = CSV.read("src/data/archive/bank_cor_$cor_window$market$weekly.csv", DataFrame)

data = sort(leftjoin(data, granger_df, on = :Date), :Date)

benchmark_lags = 3
banks_index_lags = 3
vol_lags = 4
conn_lag = 1

connectedness = :granger # :granger, :eig or :cor_lw

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

summary_msm(model)


ed = smoothed_probs(model)[2000:2100, :]
plot(ed, label = ["Calm market conditions" "Volatile market conditions"]) 

