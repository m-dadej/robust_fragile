library(tidyverse)
library(ggplot2)
library(xtable)

# repository path
path <- "C:/Users/Mateusz/Documents/py/finanse/robust_fragile/"

cor_wins <- c(63, 256)
markets <- c("eu", "us")

df <- data.frame()

for (market in markets) {
  for (cor_win in cor_wins) {
    
    df_granger <- read.csv(paste0(path, "src/data/archive/granger_ts_", cor_win, market, ".csv"))
    df_cor <- read.csv(paste0(path, "src/data/archive/bank_cor_", cor_win, market, ".csv"))
    
    df <- select(df_cor, Date, cor_lw, eig) %>%
      full_join(df_granger, by = "Date") %>%
      mutate(market = market,
             cor_win = cor_win,
             Date = as.Date(Date)) %>%
      filter(granger != 0.0) %>%
      rbind(df)
  }
}


clean_ts <- function(x){
  
  x <- (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
  return(x)
}

# connectedness time series not from the appendix
connectedness_ts_main <- drop_na(df) %>%
  mutate(across(c("cor_lw", "eig", "granger"), 
                \(x){(x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)} )) %>%
  filter(if_all(c("cor_lw", "eig", "granger"), \(x){x < mean(x, na.rm = TRUE) + 3 * sd(x, na.rm = TRUE)} )) %>%
  pivot_longer(cols = c(cor_lw, eig, granger)) %>%
  drop_na() %>%
  mutate(name = case_when(name == "cor_lw" ~ "Ledoit-Wolf",
                          name == "eig" ~ "Eigendecomposition",
                          name == "granger" ~ "Granger causality")) %>%
  filter(market == "us" & cor_win == 63 &
        Date > "2008-02-11") %>% 
  ggplot(aes(x = Date)) +
  geom_line(aes(y = value)) +
  facet_wrap(~name, ncol = 1) +
  theme_minimal() +
  scale_x_date(date_breaks = "4 years", date_labels = "%Y") +
  labs(x = "", y = "")

ggsave(paste0(path, "paper/img/connect_ts.png"), connectedness_ts_main, width = 8, height = 5, dpi = 300, bg = "white")


# connectedness time series from the appendix
connect_ts_app <- drop_na(df) %>%
mutate(across(c("cor_lw", "eig", "granger"), 
                  \(x){(x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)} )) %>%
  filter(if_all(c("cor_lw", "eig", "granger"), \(x){x < mean(x, na.rm = TRUE) + 3 * sd(x, na.rm = TRUE)} )) %>%
  pivot_longer(cols = c(cor_lw, eig, granger)) %>%
  drop_na() %>%
  #filter(market != "us" | cor_win != 63) %>%
  filter(Date > "2008-02-11") %>%
  mutate(market = case_when(market == "eu" ~ "EU",
                            market == "us" ~ "US"),
         name = case_when(name == "cor_lw" ~ "Ledoit-Wolf",
                          name == "eig" ~ "Eigendecomposition",
                          name == "granger" ~ "Granger causality")) %>%
  rename(window = cor_win, method = name) %>%
  ggplot(aes(x = Date)) +
  geom_line(aes(y = value)) +
  facet_grid(vars(market, window), cols = vars(method), scales = "free_x", labeller = "label_both") +
  theme_minimal() +
  labs(x = "", y = "") +
  scale_x_date(date_breaks = "4 years", date_labels = "%Y")

ggsave(paste0(path, "paper/img/connect_ts_app.png"), connect_ts_app, width = 8, height = 5, dpi = 300, bg = "white")


drop_na(df) %>%
  mutate(across(c("cor_lw", "eig", "granger"), 
                \(x){(x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)} )) %>%
  filter(if_all(c("cor_lw", "eig", "granger"), \(x){x < mean(x, na.rm = TRUE) + 3 * sd(x, na.rm = TRUE)} )) %>%
  filter(market == "us") %>%
  pivot_wider(names_from = c(market, cor_win), values_from = c(cor_lw, eig, granger)) %>%
  select(-Date) %>%
  cor(use = "pairwise.complete.obs") %>%
  xtable()
  
  
