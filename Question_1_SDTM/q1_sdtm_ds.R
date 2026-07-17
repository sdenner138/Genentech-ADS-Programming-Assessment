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
library(pharmaversesdtm)
library(sdtm.oak)
library(dplyr)

ds_raw <= pharmaverseraw::ds_raw

# Explore raw DS data
names(ds_raw)
dim(ds_raw)
glimpse(ds_raw)
head(ds_raw)

# Understand SDTM Oak package
ls("package:sdtm.oak")
?generate_oak_id_vars

# Study example domain

?domain_example
domain_example
domain_example()
ae_example <- domain_example("ae")
ae_example
ae_example <- read_domain_example("ae")
class(ae_example)
# example is a data frame, not a script, shows me I need to refer to sdtm.oak documentation
names(ae_example)
str(ae_example, max.level=1)

# Read in completed DM
dm <- pharmaversesdtm::dm
head(dm)

###############
# Create oak_id_vars here - this allows us to utilize sdtm.oak package by creating
# the three necessary variables, oak_id, raw_source, patient_number, that
# appear in the programming pipeline.
###############

ds_raw <- ds_raw %>% 
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

################
# Read in Controlled Terminology(CT)
################

# first, download the CSV into this project. To do this, I downloaded directly from the 
# GitHub link, and uploaded into a new 'metadata' folder within the repo.
study_ct <- read.csv("metadata/sdtm_ct.csv")

###############
# Map Topic Variable
# In DS, the topic variable is DSTERM. We will map this from IT.DSTERM, where here
# IT is raw_ds dataset.
# According to aCRF, "If OTHERSP is null, map the value in IT.DSTERM to DSTERM. Else if 
# OTHERSP is not null, map the value in OTHERSP to DSTERM"
###############

# there is no CT for DSTERM, so we will use the assign_no_ct function.
# Since we need to add a condition, we will use the condition_add function.
# Since I am learning as I go, I will keep each function call separate from the next,
# avoiding using pipe operators.

# Default mapping:
# Map IT.DSTERM to DSTERM for all records
# raw_var=IT.DSTERM, tgt_var=DSTERM

ds <- assign_no_ct(
  raw_dat = ds_raw,
  raw_var = "IT.DSTERM",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
)

# Add condition metadata to raw records where OTHERSP is populated 
ds_raw_othersp <- condition_add(
  dat = ds_raw,
  !is.na(OTHERSP) & trimws(OTHERSP) != ""
)

# For the records where the condition is met (OTHERSP is not null), replace the 
# original mapping to OTHERSP = DSTERM

ds <- assign_no_ct(
  tgt_dat = ds,
  raw_dat = ds_raw_othersp,
  raw_var = "OTHERSP",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
)
