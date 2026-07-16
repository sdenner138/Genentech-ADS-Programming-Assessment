#####################################
# 
# Program Name : q1_sdtm_ds.R
#
# Purpose: Generate SDTM Dataset DS using Pharmaverse
#
# Author: Sara Denner
#
####################################

############
# Load required packages & Read in data
############

library(pharmaverseraw)
library(sdtm.oak)
library(dplyr)

ds_raw <= pharmaverseraw::ds_raw