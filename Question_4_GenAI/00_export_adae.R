#############################################################################
# 
# Program Name : 00_export_adae.R
#
# Purpose: Export Pharmaverse ADAE into csv format for reading into Python
#
# Author: Sara Denner
#
#############################################################################

library(pharmaverseadam)
library(dplyr)
library(readr)

## Load in ADAE
adae <- pharmaverseadam::adae