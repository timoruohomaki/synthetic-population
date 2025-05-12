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
library(readr)


if(!file.exists("./data")){dir.create("./data")}

kCount <- 1000

maakuntaKoodit <- c("00","01","02","03","04","05","06","07","08","09","10","11","12","13","14","15","16","17","18","19")
maakuntaNimet <- c("Koko maa","Uusimaa","Varsinais-Suomi","Satakunta","Kanta-Häme","Pirkanmaa","Päijät-Häme","Kymenlaakso","Etelä-Karjala",
                   "Etelä-Savo","Pohjois-Savo","Pohjois-Karjala","Keski-Suomi","Etelä-Pohjanmaa","Pohjanmaa","Keski-Pohjanmaa","Pohjois-Pohjanmaa",
                   "Kainuu","Lappi","Ahvenanmaa")
maakunnat.df <- data.frame(maakuntaKoodit,maakuntaNimet)

# generate large vector of random numbers

probArray <- runif(kCount)

# creating name arrays, no probability weights

firstNameData <- read_excel("./data/etunimitilasto-2025-02-04-dvv.xlsx")
lastNameData <- read_excel("./data/sukunimitilasto-2025-02-04-dvv.xlsx")

firstName <- sample(unlist(as.list(firstNameData[1])), kCount, replace = TRUE)
lastName <- sample(unlist(as.list(lastNameData[1])), kCount, replace = TRUE)

rm(firstNameData,lastNameData)

# creating addresses: street addresses and zip codes from one source merged with city from another, using zip as join key

addressData.raw <- read.csv2("./data/Suomi_osoitteet_2023-11-13.OPT", encoding = "latin1", colClasses = "character")

colnames(addressData.raw) <- c("Rakennustunnus","Sijaintikunta","Maakunta","Ktarkoitus","Pkoord","Ikoord","Osoitenumero","Katu_FI","Katu_SE","Katunro",
                               "Postinumero","Aanestysalue","Aanestys_FI","Aanestys_SE","Sijaintikiinteisto","Poimintapaiva")

addressData.clean <- addressData.raw %>% select(Katu_FI,Katunro,Postinumero) %>% filter(is.na(Katu_FI) | Katu_FI != "") %>% filter(is.na(Postinumero) | Postinumero != "")

rm(addressData.raw)

ptoWidth <- c(5,8,5,30,30,12,12,8,1)
postData.raw <- read.fwf("./data/PCF_20250510.dat", ptoWidth, header = FALSE, fileEncoding = "latin1", colClasses = "character")
colnames(postData.raw) <- c("Tietuetunnus","Ajopvm","Postinumero","Pto_FI","Pto_SE","Pto_lyh_FI","Pto_lyh_SE","Voimaan","Tyyppi")

# join addresses with city names

address.df <- merge(addressData.clean, postData.raw, by.x = "Postinumero", by.y = "Postinumero")

address.clean <- address.df %>% select(Katu_FI,Katunro,Postinumero,Pto_FI)

address.all <- address.clean[sample(nrow(address.clean),kCount, replace = TRUE),]

rm(addressData.clean,postData.raw, address.df, address.clean)

# phone

primaryPhone <- paste0(sample(c("060","062","065","070"), size = 
                                kCount, replace = TRUE, prob = c(0.4,0.1,0.2,0.3)),
                       "-", sample((100000:9999999), size = kCount, replace = TRUE))

# personal identification number
# note: if real control characters needed, use the function available in utils
# for privacy reasons, control characters are random to make it unlikely strings match with real persons

personID <- paste0(sprintf("%02d",(sample((1:31), size = kCount,replace = TRUE))), 
                   sprintf("%02d",(sample((1:12), size = kCount,
                                          replace = TRUE))), sample((20:99), size = kCount, replace = TRUE),
                   "-", sample((100:999), size = kCount, replace = TRUE), sample(LETTERS, size = kCount, replace = TRUE))

# international classification of crime (ICCS)

crimeClass.raw <- read.csv("./data/rikokset_21_20230101.csv")
colnames(crimeClass.raw) <- "codelist"

crimeClass <- crimeClass.raw %>% separate_wider_delim(codelist, delim = ";", names = c("c1","c2","c3","c4"))

crimeClass.clean <- crimeClass %>% select(c1,c3) %>% mutate(c1 = gsub("'","",c1)) %>% filter(!grepl("Luku",c3)) %>% filter(!grepl("LAKI",c3))

# generating combined dataset

population.df <- data.frame(firstName, lastName, address.all$Katu_FI, address.all$Katunro, address.all$Postinro, address.all$Pto_FI)

