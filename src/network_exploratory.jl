
@time using Statistics
@time using DataFrames
@time using CSV

n_covariates = 5

run(`py src/granger_ts.py
    --region eu
    --freq daily`) 

include("granger_functions.jl")

data_raw = CSV.read("src/data/df_rets_granger.csv", DataFrame)
data = Matrix(replace.(data_raw[:, 2:end], Inf))

mat = granger_connect(data[:,1:(end-n_covariates)], data[:, (end-n_covariates+1):end], true)

