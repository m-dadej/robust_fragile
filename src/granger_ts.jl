@time using Statistics
@time using DataFrames
@time using CSV
@time using MarSwitching
@time using Tables

cor_w = 63
n_covariates = 5

run(`py src/granger_ts.py
    --region eu
    --freq daily`) # daily or weekly

include("src/granger_functions.jl")

data_raw = CSV.read("src/data/df_rets_granger.csv", DataFrame)
data = Matrix(replace.(data_raw[:, 2:end], Inf))


granger_ts = zeros(length(cor_w:size(data)[1]))

for t in cor_w:size(data)[1]
    println("$(round((t / size(data)[1])*100, digits = 2)) %")
    window = data[(t - cor_w + 1):t, 1:(end-n_covariates)]
    covariates = data[(t - cor_w + 1):t, (end-n_covariates+1):end]
    mat = granger_connect(window, covariates, false)
    granger_ts[t - cor_w + 1] = granger_degree(mat)
end

granger_out = DataFrame(Date = data_raw.Date[cor_w:end], granger = granger_ts)


CSV.write("src/data/granger_ts.csv", granger_out)

