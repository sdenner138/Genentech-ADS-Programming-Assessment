#############################################################################
# 
# Program Name : create_adsl.R
#
# Purpose: Generate ADaM Dataset ADSL using Pharmaverse/admiral package
#
# Author: Sara Denner
#
#############################################################################

##################################################
# STEP 0) Initialize Project Directories and Log
##################################################

question_dir <- "Question_2_ADaM"

output_dir <- file.path(question_dir, "output")
log_dir <- file.path(question_dir, "logs")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

output_file <- file.path(output_dir, "adsl.csv")
log_file <- file.path(log_dir, "create_adsl.log")

### Start Log
sink(log_file, split = TRUE)

cat("========================================\n")
cat("Question 2 - Create ADSL\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

##########################################
# STEP 1) Load Packages and Read in Data
##########################################

# Load packages
library(admiral)
library(dplyr, warn.conflicts = FALSE)
library(pharmaversesdtm)
library(lubridate)
library(stringr)

# Get data
dm <- pharmaversesdtm::dm
ex <- pharmaversesdtm::ex
vs <- pharmaversesdtm::vs
ae <- pharmaversesdtm::ae
ds <- pharmaversesdtm::ds

# Standardize data
dm <- convert_blanks_to_na(dm)
ex <- convert_blanks_to_na(ex)
vs <- convert_blanks_to_na(vs)
ae <- convert_blanks_to_na(ae)
ds <- convert_blanks_to_na(ds)


