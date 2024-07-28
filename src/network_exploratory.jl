@time using Statistics
@time using DataFrames
@time using CSV
using GraphPlot
using Graphs
using Compose
using Cairo
using Random
using Dates
using Latexify
using CovarianceEstimation

n_covariates = 5
lw_tol = 0.0002

# run(`py src/granger_ts.py
#     --region us
#     --freq daily`) 

include("granger_functions.jl")

function clean_infs(x::Matrix{Float64}, range::Vector{Int})
    na_cols = [all(isinf.(x[range,col])) for col in 1:size(x, 2)]
    df = x[range, .!na_cols]
    return df
end

function make_graph_image!(mat::Matrix{Float64}, 
                            label::Vector{String}, 
                            region::String)

    g = SimpleDiGraph(mat)
    
    rem_vertices!(g, findall(x -> x == 0, degree(g)))
    label = label[findall(x -> x != 0, degree(g))]
    
    Random.seed!(123)
    graph_circl = gplot(g, nodelabel= label, 
                     layout=circular_layout, 
                     arrowlengthfrac = 0.05,
                     nodelabelsize = 1.5)
    
    graph = gplot(g, nodelabel= label, 
                    arrowlengthfrac = 0.05,
                    nodelabelsize = 1.5)     
    
    draw(PNG("paper/img/graph_$(region)_circl.png", 20cm, 20cm), graph_circl)
    draw(PNG("paper/img/graph_$(region).png", 20cm, 20cm), graph)
end

function unweight(x::Matrix{Float64}, atol::Float64)
    
    N = size(x, 1)
    shrinked_mat = zeros(size(x))
    for (i, j) in collect(Iterators.product(1:N, 1:N))    
        
        if i == j 
            shrinked_mat[i, j] = 0.0
            continue
        end
        
        if abs(x[i, j]) < atol
            shrinked_mat[i, j] = 0.0
        else
            shrinked_mat[i, j] = 1.0
        end
    end

    return shrinked_mat
end

function get_lw_network(df::Matrix{Float64}, tol::Float64)
    LW = LinearShrinkage(ConstantCorrelation())

    mat_us_lw = cov(LW, df)
    mat_us_lw = unweight(Matrix(mat_us_lw), tol)

    return mat_us_lw
end

function graph_stats(mat::Matrix{Float64}, region::String, period::String = "daily")

    g = SimpleDiGraph(mat)

    df = DataFrame(region = region,
          period = period,
          density = density(g),
          degree = mean(degree(g)),
          median_degree = median(degree(g)),
          assortativity = assortativity(g),
          cluster_coef = global_clustering_coefficient(g),
          interm_share = sum(intermediaries(mat)) / size(mat)[1],
          max_path = max_path(mat),
          eigenvector_centrality = mean(eigenvector_centrality(g)),
          core_size_rel = sum(core_periphery_deg(SimpleGraph(g)) .== 1) / size(mat_eu)[1],
          core_size_abs = sum(core_periphery_deg(SimpleGraph(g)) .== 1))
    return df
end

size(mat_eu)

granger_degree(unweight(Matrix(mat_eu_lw), lw_tol))
maximum(mat_eu_lw)
granger_degree(mat_eu_lw)

#data_raw = CSV.read("src/data/df_rets_granger.csv", DataFrame)
data_raw_eu = CSV.read("src/data/archive/df_rets_granger_eu.csv", DataFrame)
data_eu = Matrix(replace.(data_raw_eu[:, 2:end], Inf))

mat_eu = granger_connect(data_eu[end-256:end,1:(end-n_covariates)], data_eu[end-256:end, (end-n_covariates+1):end])
mat_eu_lw = get_lw_network(data_eu[end-256:end,1:(end-n_covariates)], lw_tol)

data_raw_us = CSV.read("src/data/archive/df_rets_granger_us.csv", DataFrame)
data_us = Matrix(replace.(data_raw_us[:, 2:end], Inf))

mat_us = granger_connect(data_us[end-256:end,1:(end-n_covariates)], data_us[end-256:end, (end-n_covariates+1):end])
mat_us_lw = get_lw_network(data_us[end-256:end,1:(end-n_covariates)], lw_tol)

make_graph_image!(mat_us_lw, names(data_raw_us), "us_lw")
make_graph_image!(mat_eu_lw, names(data_raw_eu), "eu_lw")
make_graph_image!(mat_eu, names(data_raw_eu), "eu")
make_graph_image!(mat_us, names(data_raw_us), "us")


us_id06 = findall(x -> (x .> Date("2006-01-01")) .& (x .< Date("2007-01-01")), data_raw_us[:, 1])
eu_id06 = findall(x -> (x .> Date("2006-01-01")) .& (x .< Date("2007-01-01")), data_raw_eu[:, 1])

data_us06 = clean_infs(data_us, us_id06)
data_eu06 = clean_infs(data_eu, eu_id06)

mat_us06 = granger_connect(data_us06[:,1:(end-n_covariates)], data_us06[:, (end-n_covariates+1):end])
mat_eu06 = granger_connect(data_eu06[:,1:(end-n_covariates)], data_eu06[:, (end-n_covariates+1):end])


granger_stats_df = permutedims([graph_stats(mat_eu, "eu", "recent");
                                graph_stats(mat_us, "us", "recent");
                                graph_stats(mat_us06, "us", "pre_gfc");
                                graph_stats(mat_eu06, "eu", "pre_gfc")], 
                                1, makeunique=true)

lw_stats_df = permutedims([graph_stats(mat_eu_lw, "eu", "recent");
                            graph_stats(mat_us_lw, "us", "recent")],
                            1, makeunique=true)

show(stdout, MIME("text/latex"), granger_stats_df)                            
show(stdout, MIME("text/latex"), lw_stats_df)
