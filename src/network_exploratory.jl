
@time using Statistics
@time using DataFrames
@time using CSV
using GraphPlot
using Graphs
using Compose
using Cairo
using Random

n_covariates = 5

# run(`py src/granger_ts.py
#     --region us
#     --freq daily`) 

include("granger_functions.jl")

#data_raw = CSV.read("src/data/df_rets_granger.csv", DataFrame)
data_raw_eu = CSV.read("src/data/archive/df_rets_granger_eu.csv", DataFrame)
data_eu = Matrix(replace.(data_raw_eu[:, 2:end], Inf))

mat_eu = granger_connect(data_eu[end-256:end,1:(end-n_covariates)], data_eu[end-256:end, (end-n_covariates+1):end])

data_raw_us = CSV.read("src/data/archive/df_rets_granger_us.csv", DataFrame)
data_us = Matrix(replace.(data_raw_us[:, 2:end], Inf))

mat_us = granger_connect(data_us[end-256:end,1:(end-n_covariates)], data_us[end-256:end, (end-n_covariates+1):end])

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

make_graph_image!(mat_eu, names(data_raw_eu), "eu")
make_graph_image!(mat_us, names(data_raw_us), "us")


DataFrame(region = "eu",
          density = density(SimpleDiGraph(mat_eu)),
          degree = mean(degree(SimpleDiGraph(mat_eu))),
          median_degree = median(degree(SimpleDiGraph(mat_eu))),
          assortativity = assortativity(SimpleDiGraph(mat_e)),
          cluster_coef = clustering_coefficient(SimpleDiGraph(mat_eu)),
          )
density(g)


mean(degree(SimpleDiGraph(mat_eu)))