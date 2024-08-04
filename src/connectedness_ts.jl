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

# download data
# args: region us/eu, freq weekly/daily
run(`py src/stocks_download.py
    --region eu
    --freq daily
    --cor_window 63
    --eig_k 1
    --excess False`)