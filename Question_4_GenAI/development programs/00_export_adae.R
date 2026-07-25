#############################################################################
# 
# Program Name : 00_export_adae.R
#
# Purpose: Export Pharmaverse ADAE into csv format for reading into Python
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

####################################################
# Question 4 Step 1) Export ADAE to CSV file in R
####################################################

library(pharmaverseadam)
library(dplyr)
library(readr)

## Load in ADAE
adae <- pharmaverseadam::adae

## Export ADAE as a CSV
readr::write_csv(adae, "Question_4_GenAI/adae.csv", na = "")

adae %>%
  distinct(AESEV) %>%
  arrange(AESEV)

adae %>%
  distinct(AETERM) %>%
  arrange(AETERM) %>%
  print(n=50)

adae %>%
  distinct(AESOC) %>%
  arrange(AESOC)
