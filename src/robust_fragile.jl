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
cor_window = 63 #63 or 256
market = "eu"
weekly = "_weekly" # "" or "_weekly"
granger_df = CSV.read("src/data/archive/granger_ts_$cor_window$market$weekly.csv", DataFrame)
data = CSV.read("src/data/archive/bank_cor_$cor_window$market$weekly.csv", DataFrame)

data = sort(leftjoin(data, granger_df, on = :Date), :Date)

benchmark_lags = 3
banks_index_lags = 3
vol_lags = 3
conn_lag = 1

connectedness = :cor_lw # :granger, :eig or :cor_lw

model_df = @chain data begin
    select(_, [:banks_index, :index, connectedness])
    transform(_, :banks_index => (x -> ones(length(x))) => :intercept)
    transform(_, [:banks_index => (x -> lag(x, i)) => "banks_index_lag$i" for i in 1:banks_index_lags])
    transform(_, [:index => (x -> lag(x, i)) => "index_lag$i" for i in 1:benchmark_lags])
    dropmissing()
    get_residual(_, :banks_index, Symbol.([["banks_index_lag$i" for i in 1:banks_index_lags]..., ["index_lag$i" for i in 1:benchmark_lags]...]))
    transform(_, [connectedness => (x -> lag(x, i)) => "connectedness_lag$i" for i in 1:conn_lag])
    transform(_, [:residual => (x -> abs.(x)) => :vol])
    transform(_, [:vol => (x -> lag(x, i)) => "vol_lag$i" for i in 1:vol_lags])
    transform(_, :index => (x -> abs.(x)) => :index_vol)
    remove_outlier(_, σ = 5)
    dropmissing()
end

exog_switch = standard(Matrix(model_df[!, [["connectedness_lag$i" for i in 1:conn_lag]...]]))
#exog_switch = [standard(model_df[!, connectedness]) exog_switch]

exog = Matrix(model_df[!, [["vol_lag$i" for i in 1:vol_lags]..., "index_vol"]])

model = MSModel(model_df.vol .* 100, 2, 
                exog_vars = exog .* 100,
                exog_switching_vars = exog_switch,
                # exog_tvtp = tvtp,
                random_search_em = 5,
                random_search = 3
                )

summary_msm(model)

df_model = Matrix(dropmissing(data[:, ["banks_index", "index", "granger"]]))

df_model = remove_outlier(df_model, σ = 5)



X_mean = [ones(length(df_model[3:end,1])) add_lags(df_model[:,1], 2)[:,2:3] add_lags(df_model[:,2], 2)[:,2:3]]
β_mean = ols(df_model[3:end,1] ,X_mean)
y_hat = df_model[3:end,1] .- X_mean*β_mean 


# y_hat = sqrt.((df_model[:,1] .- mean(df_model[:,1])).^2)
# df_model[:,2] = sqrt.(df_model[:,2].^2)

# for col in 1:4
#     df_model[:,col] = standard(df_model[:,col])
# end

exog = add_lags(abs.(y_hat), 4)[:,2:5]
#exog = add_lags(df_model[:,1], 1)[:,2]
exog_switch = add_lags(df_model[6:end,3],1)[:,2] #[df_model[2:end, 3] df_model[2:end,2]]

#tvtp = [ones(length(exog[:,1])) add_lags(df_model[:,3], 1)[2:end,2]]
#tvtp[:, 2] = standard(tvtp[:, 2])


model = MSModel(abs.(y_hat[5:end]) .*100 , 2, 
                exog_vars = exog .* 100,
                exog_switching_vars = standard(exog_switch),
                # exog_tvtp = tvtp,
                # random_search_em = 10,
                random_search = 3
                )

summary_msm(model)


plot_ts = Matrix(dropmissing(data[:, ["cor_lw", "eig", "granger"]]))
cor(plot_ts)

p1 = plot(standard(plot_ts[:,1]), title = "correlation-based") 
p3 = plot(standard(plot_ts[:,2]), title = "eigen-based") 
p2 = plot(standard(plot_ts[:,3]), title = "granger-based")                    
connect_plot = plot(p1, p2, p3, layout=(3,1), legend=false,
                    size = (600,600))                    



plot(sqrt.((df_model[:,1] .- df_model[:,2]).^2))
plot(sqrt.((df_model[:,1]).^2))
plot(data.granger)

plot(abs.(y_hat[4:end]))
cor(Matrix(dropmissing(data[:, ["cor", "eig"]])))

plot(Matrix(dropmissing(data[:, ["cor", "eig"]])))

cor(df_model[2:end,1], exog_switch)

ed = expected_duration(model)
plot(ed, label = ["Calm market conditions" "Volatile market conditions"],
         title = "Time-varying expected duration of regimes") 

mean(expected_duration(model), dims = 1)

plot(smoothed_probs(model)[1:500,],
         label     = ["Calm market conditions" "Volatile market conditions"],
         title     = "Regime probabilities", 
         linewidth = 0.5,
         legend = :bottomleft)

df_ols = DataFrame(df_model, :auto)[2:end, :]
df_ols[!, "lag"] = exog
df_ols[!, "lag_cor"] = exog_switch
ols = lm(@formula(x1 ~ lag + lag_cor), df_ols)

