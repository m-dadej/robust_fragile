using LinearAlgebra
using MarSwitching
using Base.Threads

replace(x, to) = ismissing(x) ? to : x

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
    return sum(replace_inf.(x)) / ((size(x)[2])^2 - size(x)[2] - sum(isinf.(x)))
end    