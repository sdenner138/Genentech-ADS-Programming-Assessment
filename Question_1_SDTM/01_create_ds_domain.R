####################################################################################
# 
# Program Name : 01_create_ds_domain.R
#
# Purpose: Generate SDTM Dataset DS using Pharmaverse/SDTM.OAK package
#
# Author: Sara Denner
#
####################################################################################

###########################################################
# STEP 0) Initialize Project Directories and Log
###########################################################

question_dir <- "Question_1_SDTM"

output_dir <- file.path(question_dir, "output")
log_dir <- file.path(question_dir, "logs")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

output_file <- file.path(output_dir, "ds.csv")
log_file <- file.path(log_dir, "01_create_ds_domain.log")

### Start Log
sink(log_file, split = TRUE)

cat("========================================\n")
cat("Question 1 - Create DS Domain\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

##############################################################################
# STEP 1) Load required packages, Read in data, and explore SDTM.OAK package
##############################################################################

library(pharmaverseraw)
library(pharmaversesdtm)
library(sdtm.oak)
library(dplyr)

ds_raw <- pharmaverseraw::ds_raw

# Explore raw DS data
names(ds_raw)
dim(ds_raw)
glimpse(ds_raw)
head(ds_raw)

# Read in completed DM
dm <- pharmaversesdtm::dm
head(dm)

###############
# STEP 2) Create Oak ID Vars
#
# This allows us to utilize sdtm.oak package by creating
# the three necessary variables, oak_id, raw_source, patient_number, that
# appear in the programming pipeline.
###############

ds_raw <- ds_raw %>% 
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

####################################################
# STEP 3) Read in Controlled Terminology(CT)
####################################################

# first, download the CSV into this project. To do this, I downloaded directly from the 
# GitHub link, and uploaded into a new 'metadata' folder within the repo.
study_ct <- read.csv("metadata/sdtm_ct.csv")

############################################################################################
# STEP 4) Map Topic Variable
#
# In DS, the topic variable is DSTERM. We will map this from IT.DSTERM, where here
# IT is raw_ds dataset.
# According to aCRF, "If OTHERSP is null, map the value in IT.DSTERM to DSTERM. Else if 
# OTHERSP is not null, map the value in OTHERSP to DSTERM"
############################################################################################

# there is no CT for DSTERM, so we will use the assign_no_ct function.
# Since we need to add a condition, we will use the condition_add function.

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

# For the records where OTHERSP is not null, replace the 
# original DSTERM mapping to OTHERSP.

ds <- assign_no_ct(
  tgt_dat = ds,
  raw_dat = ds_raw_othersp,
  raw_var = "OTHERSP",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
)

##########################################################
# STEP 5) Map Rest of the Variables
##########################################################

### Controlled Terminology Update ############################################
#
# 7/20/26 - 
# in provided study controlled terminology (CT) dataset,
# the values in the collected_value variable do not always match 
# the corresponding values collected in the raw DS dataset. 
# 
# Since the terms are very similar, I can easily match the collected values
# from the ds_raw dataset to the correct CT per CDISC standards.
#
# To do this, I will add records onto the CT dataset that map the correct CT
# to the actual collected value in ds_raw.
#
# Within a codelist group, simply add records where 
# collected_value = 'raw_ds_value' and term_value = 'correct CDISC CT value'
# 
### Controlled Terminology Update End ############################################

### Map DSDECOD

dsdecod_clst <- "C66727"

# View the DSDECOD CT from the study_ct dataset
study_ct %>%
  dplyr::filter(codelist_code == dsdecod_clst) %>%
  dplyr::select(
    codelist_code,
    collected_value,
    term_value,
    term_synonyms
  ) %>%
  dplyr::arrange(term_value)

# Map collected values from IT.DSDECOD variable to correct CT
# per CDISC SDTM CT document in the ds_ct_updates table below.
ds_ct_updates <- tibble::tribble(
  ~codelist_code, ~collected_value,                ~term_value,
  dsdecod_clst,   "Randomized",                    "RANDOMIZED",
  dsdecod_clst,   "Completed",                     "COMPLETED",
  dsdecod_clst,   "Study Terminated by Sponsor",   "STUDY TERMINATED BY SPONSOR",
  dsdecod_clst,   "Screen Failure",                "SCREEN FAILURE",
  dsdecod_clst,   "Lost to Follow-Up",              "LOST TO FOLLOW-UP"
)

ds_ct_updates <- ds_ct_updates %>%
  dplyr::mutate(
    term_code = NA_character_,
    CodedData = term_value,
    term_preferred_term = term_value,
    term_synonyms = NA_character_,
    raw_codelist = "DSDECOD"
  )

# merge the new records into the working CT specification
study_ct_ds <- study_ct %>%
  
  # Keep every row except the rows in the DSDECOD codelist 
  # whose collected value appears in ds_ct_updates
  dplyr::filter(
    !(
      codelist_code == dsdecod_clst &
        collected_value %in% ds_ct_updates$collected_value
    )
  ) %>%
  
  # add in the new records
  dplyr::bind_rows(ds_ct_updates)

### Now, derive DSDECOD using the edited CT; and assign_ct from sdtm.oak

ds <- ds %>%
  
  # Map DSDECOD;  CT codelist_code = C66727; Rule = "If OTHERSP is null then map IT.DSDECOD 
  # to DSDECOD, else map OTHERSP to DSDECOD
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct_ds,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  
  # Add condition; when OTHERSP is not null, replace original DSDECOD mapping 
  # with collected text in OTHERSP.
  assign_no_ct(
    raw_dat = ds_raw_othersp,
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  )

### Derive DSCAT
  # Derivation Rule: If OTHERSP is null then do the following: If IT.DSDECOD = 'Randomized' 
  # then DSCAT = 'PROTOCOL MILESTONE'. Else, map DSCAT as 'DISPOSITION EVENT'.
  # else if OTHERSP is not null then map DSCAT as 'OTHER EVENT'.

  # Since we are not deriving DSCAT using the study_ct sheet,
  # We will use hardcode_no_ct and condition_add

ds <- ds %>%
  
  # If OTHERSP is missing and IT.DSDECOD = 'Randomized', 
  # assign DSCAT = 'PROTOCOL MILESTONE'
  hardcode_no_ct(
    raw_dat = condition_add(
      dat = ds_raw,
      (is.na(OTHERSP) | trimws(OTHERSP)=="") & IT.DSDECOD == "Randomized"
    ),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    id_vars = oak_id_vars()
  ) %>%
  
  # If OTHERSP is missing and IT.DSDECOD is not 'Randomized', 
  # assign DSCAT = 'DISPOSITION EVENT'
  hardcode_no_ct(
    raw_dat = condition_add(
      dat=ds_raw,
      (is.na(OTHERSP)|trimws(OTHERSP)=="") & IT.DSDECOD != "Randomized"
    ),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    id_vars = oak_id_vars()
  ) %>%
  
  # If OTHERSP is populated, assign DSCAT = 'OTHER EVENT'
  hardcode_no_ct(
    raw_dat = condition_add(
      dat=ds_raw,
      !is.na(OTHERSP) & trimws(OTHERSP) != ""
    ),
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    id_vars = oak_id_vars()
  )

### Map DSDTC.
# Derivation Rule: if DSTMCOL is not null, DSDTC is the concatenation of DSDTCOL and DSTMCOL in 
# ISO8601 format. Else if DSTMCOL is null, DSDTC is DSDTCOL in ISO8601 format.
#
# assign_datetime function can handle two variable inputs, and handles when one or the 
# other is null. Also able to convert into ISO 8601 format.

ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    raw_fmt = c("m-d-y", "H:M"),
    id_vars = oak_id_vars()
  )

### Map DSSTDTC
# Derivation Rule: If IT.DSSDAT is not null, map the value in IT.DSSDAT to DSSTDTC in ISO8601 format

ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m-d-y"),
    id_vars = oak_id_vars()
  )

### Map VISIT/VISITNUM

# These variables have controlled terminology associated in the study_ct document.
# Derivation Rule (VISIT): map INSTANCE to VISIT according to CT in study_ct.
# Derivation Rule (VISITNUM): map INSTANCE to VISITNUM according to CT in study_ct.

# Resolve CT issues here for VISIT mapping, following the same process
# as earlier in this program. 
visit_clst <- "VISIT"

# View the VISIT CT from the study_ct dataset
study_ct %>%
  dplyr::filter(codelist_code == visit_clst) %>%
  dplyr::select(
    codelist_code,
    collected_value,
    term_value,
    term_synonyms
  ) %>%
  dplyr::arrange(term_value)

# Update the CT in a new CT dataset for VISIT, for terms that were unable to map.
# For VISIT/VISITNUM, there are more visits/visit numbers in the raw data
# than there are values in the collected_value variable.
#
# To fix this, I will follow the example of other records to standardize the
# records that do not have a CT value.
ds_ct_updates_2 <- tibble::tribble(
  ~codelist_code, ~collected_value,                ~term_value,
  visit_clst,   "Ambul Ecg Removal",            "AMBUL ECG REMOVAL",
  visit_clst,   "Unscheduled 6.1",              "UNSCHEDULED 6.1",
  visit_clst,   "Unscheduled 1.1",   "UNSCHEDULED 1.1",
  visit_clst,   "Unscheduled 5.1",                "UNSCHEDULED 5.1",
  visit_clst,   "Unscheduled 4.1",              "UNSCHEDULED 4.1",
  visit_clst,   "Unscheduled 8.2", "UNSCHEDULED 8.2",
  visit_clst,   "Unscheduled 13.1", "UNSCHEDULED 13.1"
)

# add necessary records into the CT
ds_ct_updates_2 <- ds_ct_updates_2 %>%
  dplyr::mutate(
    term_code = NA_character_,
    CodedData = term_value,
    term_preferred_term = term_value,
    term_synonyms = NA_character_,
    raw_codelist = "VISIT"
  )

# merge in the updated mappings into the working CT specification
study_ct_ds_visit <- study_ct %>%
  dplyr::filter(
    !(
      codelist_code == visit_clst &
        collected_value %in% ds_ct_updates_2$collected_value
    )
  ) %>%
  dplyr::bind_rows(ds_ct_updates_2)

# Proceed with derivation for VISIT
ds <- ds %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct_ds_visit,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  )

# Resolve CT issues here for VISITNUM mapping, following the same process
# as earlier in this program. 
visitnum_clst <- "VISITNUM"

# View the VISITNUM CT from the study_ct dataset
study_ct %>%
  dplyr::filter(codelist_code == visitnum_clst) %>%
  dplyr::select(
    codelist_code,
    collected_value,
    term_value,
    term_synonyms
  ) %>%
  dplyr::arrange(term_value)

# Update the CT in a new CT dataset for VISITNUM, for terms that were unable
# to map. 
ds_ct_updates_3 <- tibble::tribble(
  ~codelist_code, ~collected_value,                ~term_value,
  visitnum_clst,   "Ambul Ecg Removal",            "6",
  visitnum_clst,   "Unscheduled 6.1",              "6.1",
  visitnum_clst,   "Unscheduled 1.1",   "1.1",
  visitnum_clst,   "Unscheduled 5.1",                "5.1",
  visitnum_clst,   "Unscheduled 4.1",              "4.1",
  visitnum_clst,   "Unscheduled 8.2", "8.2",
  visitnum_clst,   "Unscheduled 13.1", "13.1"
)

# add necessary records into the new CT
ds_ct_updates_3 <- ds_ct_updates_3 %>%
  dplyr::mutate(
    term_code = NA_character_,
    CodedData = term_value,
    term_preferred_term = term_value,
    term_synonyms = NA_character_,
    raw_codelist = "VISITNUM"
  )

# merge in the updated mappings into the working CT specification
study_ct_ds_visitnum <- study_ct %>%
  dplyr::filter(
    !(
      codelist_code == visitnum_clst &
        collected_value %in% ds_ct_updates_3$collected_value
    )
  ) %>%
  dplyr::bind_rows(ds_ct_updates_3)

ds <- ds %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct_ds_visitnum,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  )

########################################################
# STEP 6) Create SDTM Derived Variables
# Derive STUDYID, DOMAIN, USUBJID, DSSEQ, DSSTDY
########################################################

ds <- ds %>%
  dplyr::mutate(
    STUDYID = ds_raw$STUDY,
    DOMAIN = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM),
    DSTERM = toupper(DSTERM),
    DSDECOD = toupper(DSDECOD),
    VISITNUM = as.numeric(VISITNUM)
  ) %>%
  # sort by subject, start date of event, DSTERM
  dplyr::arrange(
    USUBJID, DSDTC, DSTERM
  ) %>%
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID","DSDTC", "DSTERM")
  ) %>%
  derive_study_day(
    sdtm_in = .,
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFXSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  select(
    "STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", "DSDECOD", "DSCAT", "VISITNUM", "VISIT",
    "DSDTC", "DSSTDTC", "DSSTDY"
  )

###########################################
# STEP 7) Add Variable Labels
###########################################

ds_labels <- c(
  STUDYID = "Study Identifier",
  DOMAIN  = "Domain Abbreviation",
  USUBJID = "Unique Subject Identifier",
  DSSEQ   = "Sequence Number",
  DSTERM  = "Reported Term for the Disposition Event",
  DSDECOD = "Standardized Disposition Term",
  DSCAT   = "Category for Disposition Event",
  VISITNUM= "Visit Number",
  VISIT   = "Visit Name",
  DSDTC   = "Date/Time of Collection",
  DSSTDTC = "Start Date/Time of Disposition Event",
  DSSTDY  = "Study Day Start of Disposition Event"
)

for (v in names(ds_labels)) {
  attr(ds[[v]], "label") <- ds_labels[[v]]
}

###################################################
# STEP 8) Output Final Dataset and Log File
###################################################

#output
write.csv(
  ds,
  file = "Question_1_SDTM/output/ds.csv",
  row.names = FALSE,
  na = ""
)

#log
cat("\n========================================\n")
cat("Program completed successfully\n")
cat("Completed:", format(Sys.time()), "\n")
cat("\nDataset summary\n")
cat("----------------------------\n")
cat("Rows:", nrow(ds), "\n")
cat("Columns:", ncol(ds), "\n")

cat("\nVariable names:\n")
print(names(ds))

cat("\nStructure:\n")
str(ds)
cat("========================================\n")

sink()

