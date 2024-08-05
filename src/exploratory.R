library(tidyverse)
library(ggplot2)
library(xtable)

drawdown <- function(ret) {
  cum_ret <- cumprod(ret + 1)
  return((cum_ret / cummax(cum_ret)) - 1)
}

df_eu <- read.csv("C:/Users/Mateusz/Documents/py/finanse/robust_fragile/src/data/archive/df_rets_granger_eu.csv") 
df_us <- read.csv("C:/Users/Mateusz/Documents/py/finanse/robust_fragile/src/data/archive/df_rets_granger_us.csv") 

not_stocks <- c("X.IRX", "XLY", "IYR", "ZN.F", "CL.F", "Open")

### IPO dates ####

get_ipo <- function(df) {
  ipo <- df %>%
    select(-any_of(not_stocks)) %>%
    pivot_longer(cols = -c(Date)) %>%
    group_by(name) %>%
    summarise(ipo = Date[which(!is.na(value))[1]]) %>%
    separate(name, into = c("ticker", "market"), sep = "\\.") %>%
    select(ticker, ipo) 
  
return(ipo)
  }
names(df_us)

ipo_us <- get_ipo(df_us)
ipo_eu <- get_ipo(df_eu)

fill_na <- data.frame(matrix(NA, nrow = 13, ncol = 2))
names(fill_na) <- names(ipo_us)

df <- rbind(ipo_us, fill_na) %>%
  cbind(ipo_eu)
  
print(xtable(df), include.rownames = FALSE)

### summary stat ####

pivot_longer(df_us, cols = -c(Date)) %>%
  mutate(market = "us") %>%
  bind_rows(pivot_longer(df_eu, cols = -c(Date)) %>% mutate(market = "eu")) %>%
  drop_na() %>%
  mutate(post_gfc = Date > as.Date("2009-02-01")) %>%
  filter(!(name %in% not_stocks)) %>%
  group_by(name) %>%
  summarise(market = tail(market, 1),
            mean_ret = mean(value, na.rm = TRUE) * 100,
            sd = sd(value, na.rm = TRUE) * 100,
            p01 = quantile(value, probs = 0.01, na.rm = TRUE) * 100,
            p99 = quantile(value, probs = 0.99, na.rm = TRUE) * 100,
            max_dd = min(drawdown(value)) * 100,
            min_ret = min(value, na.rm = TRUE) * 100,
            max_ret = max(value, na.rm = TRUE) * 100,
            n = length(value)) %>%
  group_by(market) %>%
  summarise(mean_ret = mean(mean_ret),
            sd = mean(sd),
            max_dd = mean(max_dd),
            p01 = mean(p01),
            p99 = mean(p99),
            min_ret = min(min_ret),
            max_ret = max(max_ret),
            n = mean(n)) %>%
  mutate_if(is.numeric, round, 3) %>%
  mutate(n = round(n)) %>%
  t() %>%
  xtable()

((0.03952192 / 100) + 1)^(252)
((0.04122430 / 100) + 1)^(252)


mean_cor <- function(df){
  rho <- select(df, -any_of(not_stocks)) %>%
    select(-Date) %>%
    cor(use = "pairwise.complete.obs") %>%
    mean() 
  
  return(rho)
}

select(df_eu, -any_of(not_stocks)) %>%
  select(-Date) %>%
  cor(use = "pairwise.complete.obs") %>%
  min()

mean_cor(df_us)
mean_cor(df_eu)
