# SOURCES:
# DVV: https://www.avoindata.fi/data/fi/dataset/none
# Post:
# Rikosnimikkeet: https://stat.fi/fi/luokitukset/rikokset/rikokset_21_20230101?code=2

library(dplyr)
library(tidyr)
library(readxl)
library(digest)
library(odbc)
library(jsonlite)

if(!file.exists("./data")){dir.create("./data")}

kCount <- 1000


# generate large vector of random numbers

N <- 1000
probArray <- runif(N)

sum(probArray)
length(probArray)

# creating name arrays

firstNameData <- read_excel("./data/etunimitilasto-2025-02-04-dvv.xlsx")

lastNameData <- read_excel("./data/sukunimitilasto-2025-02-04-dvv.xlsx")

firstName <- sample(unlist(as.list(firstNameData[1])), kCount, replace = TRUE)
lastName <- sample(unlist(as.list(lastNameData[1])), kCount, replace = TRUE)

rm(firstNameData,lastNameData)

# creating addresses

addressData <- read.csv("./data/Finland_addresses_")

# international classification of crime (ICCS)

crimeClass.raw <- read.csv("./data/rikokset_21_20230101.csv")
colnames(crimeClass.raw) <- "codelist"

crimeClass <- crimeClass.raw %>% separate_wider_delim(codelist, delim = ";", names = c("c1","c2","c3","c4"))

crimeClass.clean <- crimeClass %>% select(c1,c3) %>% mutate(c1 = gsub("'","",c1)) %>% filter(!grepl("Luku",c3)) %>% filter(!grepl("LAKI",c3))

# generating combined dataset



