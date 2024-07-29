using LinearAlgebra
using MarSwitching
using Base.Threads
using Graphs

replace_missing(x, to) = ismissing(x) ? to : x

function na_share(df::Matrix{Float64})
    return sum(isinf.(df), dims=1) ./ size(df, 1)
end

function remove_infs(df::Matrix{Float64})
    
    infs = []
    for i in 1:size(df, 2)
        infs = [infs; findall(isinf.(df[:,i]))]
    end

    return df[(1:end) .∉ (infs,),:]
end

function std_err(X::Matrix, y::Vector, β::Vector)
    mse = mean((y .- X * β).^2)
    σ² = mse * (X'X)^(-1)
    return sqrt.(diag(σ²))
end    

function preproc_df(df::Matrix{Float64}, covariates::Matrix{Float64})
    pair = [df[2:end, 1] add_lags(df[:, 1], 1)[:,2] add_lags(df[:, 2], 1)[:,2] covariates[2:end, :]]
    pair = remove_infs(pair)
    pair = [pair ones(size(pair, 1))]
    return pair
end 


function granger_cause(df::Matrix{Float64}, covariates::Matrix{Float64})
    pair = preproc_df(df, covariates)

    X = pair[:, 2:end]
    y = pair[:, 1]
    
    β = (X'X) \ X'y
    Σ = std_err(X, y, β)
    
    return β[2], abs(β[2] / Σ[2]) > 1.96
end


function granger_connect(df::Matrix{Float64}, covariates::Matrix{Float64})
    
    N = size(df, 2)
    granger_mat = zeros(N, N)
    
    @threads for (i, j) in collect(Iterators.product(1:N, 1:N))      
            
        if i == j
            granger_mat[i, j] = 0
            continue
        end

        pair = df[:, [i, j]]  

        if any(na_share(pair) .>= 0.9)
            granger_mat[i, j] = Inf
            continue
        end

        if any(na_share(covariates) .>= 0.9)
            granger_mat[i, j] = Inf
            continue
        end

        if rank(preproc_df(pair, covariates)) != 4 + n_covariates
            granger_mat[i, j] = Inf
            continue
        end           

        #println(i, " ", j)
        _, signif = granger_cause(pair, covariates)
        granger_mat[i, j] = signif ? 1 : 0
    end

    return granger_mat
end

replace_inf(x) = isinf(x) ? 0.0 : x
 

function granger_degree(x)
    return sum(replace_inf.(x) .== 1) / (size(x)[2]^2 - size(x)[2])
end    

function intermediaries(x)
    interm_vec = zeros(size(x)[1])

    for i in 1:size(x)[1]
        interm_vec[i] = (sum(x[:,i]) > 0) & (sum(x[i,:]) > 0) ? 1 : 0
    end

    return interm_vec
end

function max_path(g::Matrix{Float64})

    path = Float64[]
    N = size(g)[1]

    g = SimpleDiGraph(g)

    for node in 1:N
    
        dist = dijkstra_shortest_paths(g, node).dists
        dist = dist[dist .< 1000]
        dist = dist[dist .!= 0.0]
    
        if length(dist) == 0
            continue
        end
    
        push!(path, maximum(dist))
    end

    return maximum(path)
end  

function assort_degree(mat::Matrix{Float64}, dir::String)
    g = SimpleDiGraph(mat)
    df = zeros(length(edges(g)), 2)
    i = 0

    for edge in edges(g)
        i += 1

        if dir == "in"
            df[i, 1] = indegree(g)[src(edge)]
            df[i, 2] = indegree(g)[dst(edge)]
        elseif dir == "out"
            df[i, 1] = outdegree(g)[src(edge)]
            df[i, 2] = outdegree(g)[dst(edge)]
        end

    end

    return cor(df[:,1], df[:,2])
end