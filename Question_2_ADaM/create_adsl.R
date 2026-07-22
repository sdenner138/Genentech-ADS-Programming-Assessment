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

##########################################
# STEP 2) Initialize ADSL
##########################################

adsl <- dm %>%
  select(-DOMAIN) %>%

########################################################
# STEP 3) Derive Required Treatment Variables (TRT01P)
########################################################

  mutate(TRT01P = ARM, TRT01A = ACTARM)

##############################################################################
# STEP 4) Derive/Impute Numeric Treatment Date/Time (TRTSDTM/TRTSTMF/TRTEDTM)
##############################################################################

# Create numeric exposure start/end datetime from EX character start date (EXSTDTC)/end date (EXENDTC),
# including necessary time imputations. Since no spec is provided for EXENDTC, follow the same
# rules as EXSTDTC.
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    
    # Complete date required. Only impute time components.
    highest_imputation = "h",
    
    # Per spec; if time is missing, impute completely missing time with 00:00:00.
    # If time is partially missing, 00 for missing hours, 00 for missing minutes, 
    # 00 for missing seconds.
    time_imputation = "first",
    
    # If only seconds are missing, do not populate TRTSTMF.
    ignore_seconds_flag = TRUE
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    highest_imputation = "h",
    time_imputation = "first",
    ignore_seconds_flag = TRUE
  )
  
# Retain only valid exposure records so valid-dose condition is defined
# once, and can be used for TRTSDTM and TRTEDTM derivations.
ex_valid <- ex_ext %>%
  filter(
    (EXDOSE > 0 |
        (EXDOSE == 0 & str_detect(
            EXTRT, regex("PLACEBO", ignore_case = TRUE)
            )
         )
     )
  )

# Derive treatment start (TRTSDTM) from first valid exposure record
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_valid,
    
    # Valid TRTSDTM records must have usable EX start datetime
    filter_add = !is.na(EXSTDTM),
    
    # Merge by study and subject
    by_vars = exprs(STUDYID, USUBJID),
    
    # Sort chronologically by date, use EXSEQ as tie-breaker
    order = exprs(EXSTDTM, EXSEQ),
    
    # Select first valid exposure record
    mode = "first",
    
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF)
    
  ) %>%
  
# Derive treatment end (TRTEDTM) from last valid exposure record 
  derive_vars_merged(
    dataset_add = ex_valid,
    
    # Valid TRTEDTM records must have usable EX end datetime
    filter_add = !is.na(EXENDTM),
    by_vars = exprs(STUDYID, USUBJID),
    order = exprs(EXENDTM, EXSEQ),
    
    # Select last valid exposure record
    mode = "last",
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
  ) %>%
  
  # Derive TRTSDT/TRTEDT
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM))
    
##############################################################################
# STEP 5) Derive AGEGR9/AGEGR9N
##############################################################################

# Create lookup table
agegr9_lookup <- exprs(
  ~condition, ~AGEGR9, ~AGEGR9N,
  AGE < 18, "<18", 1,
  between(AGE, 18, 50), "18 - 50", 2,
  AGE > 50, ">50", 3
)


adsl <- adsl %>%
  derive_vars_cat(
    definition = agegr9_lookup
  ) %>%

##############################################################################
# STEP 6) Derive ITTFL
##############################################################################
  derive_var_merged_exist_flag(
    dataset_add = dm,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = ITTFL,
    
    # Per spec, if DM.ARM is populated, ITTFL = "Y", else "N". In a real study, 
    # screen failures would likely have ITTFL = "N"
    condition = !is.na(ARM) & trimws(ARM) != "",
    true_value = "Y",
    false_value = "N",
    missing_value = "N"
  ) %>%

##############################################################################
# STEP 7) Derive LSTALVDT
##############################################################################
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        
        ### (1) Last complete date of vital assessment with a valid test result
        dataset_name = "vs",
        
        # Spec says that [VS.VSSTRESN] and [VS.VSSTRESC] "not both missing". I am 
        # interpreting this as "anything else but (both of them are missing)", 
        # meaning that one could be missing and the other is not missing.
        # I think that makes sense, since in SDTM VS, a non-numeric result for VSSTRESC
        # would be null in VSSTRESN, while a numeric result for VSSTRESC would have both populated.  
        condition = !(is.na(VSSTRESN) & is.na(VSSTRESC)) &
                    !is.na(convert_dtc_to_dt(VSDTC)),
        
        # In a STUDYID/USUBJID group, order records by date, VSSEQ (to identify last record)
        order = exprs(VSDTC, VSSEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(VSDTC),
          seq = VSSEQ
        )
      ),
      event(
        
        ### (2) Last complete onset date of Adverse Events
        dataset_name = "ae",
        
        # convert_dtc_to_dt() will return NA for partial dates,
        # since no date imputation is requested
        condition = !is.na(convert_dtc_to_dt(AESTDTC)),
        order = exprs(AESTDTC,AESEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(AESTDTC),
          seq= AESEQ
        )
      ),
      event(
        
        ### (3) Last complete disposition date
        dataset_name = "ds",
        condition = !is.na(convert_dtc_to_dt(DSSTDTC)),
        order = exprs(DSSTDTC,DSSEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(DSSTDTC),
          seq = DSSEQ
        )
      ),
      event(
        
        ### (4) Last date of treatment administration where patient received a 
        ### valid dose
        dataset_name = "adsl",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(
          LSTALVDT = as.Date(TRTEDT),
          seq = 0
        )
      )
    ),
      
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
  
    # Select the max date across all four sources.
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT)
  ) %>%
  
  # Get all required variables per ADaMIG v1.3, all other derived variables, and core DM variables
  select(
    "STUDYID", "USUBJID", "SUBJID", "SITEID","COUNTRY", "AGE", "AGEU", "AGEGR9", "AGEGR9N", "SEX", "RACE", 
    "ETHNIC","DMDTC","DMDY", "ITTFL", "ARM", "ARMCD", "ACTARM", "ACTARMCD","ARMNRS","ACTARMUD", "TRT01P", "TRT01A", 
    "TRTSDT", "TRTSDTM","TRTSTMF", "TRTEDT", "TRTEDTM","TRTETMF", "BRTHDTC", "DTHFL", "DTHDTC", "LSTALVDT"
  ) %>%
  
  # Sort by STUDYID, USUBJID
  dplyr::arrange("STUDYID", "USUBJID")

###########################################
# STEP 7) Add Variable Labels
###########################################

adsl_labels <- c(
  AGEGR9 = "Pooled Age Group 9",
  AGEGR9N = "Pooled Age Group 9 (N)",
  ITTFL = "Intent-To-Treat Population Flag",
  TRTSDT = "Date of First Exposure to Treatment",
  TRTSDTM = "Datetime of First Exposure to Treatment",
  TRTSTMF = "Time of First Exposure Imput. Flag",
  TRTEDT = "Date of Last Exposure to Treatment",
  TRTEDTM = "Datetime of Last Exposure to Treatment",
  TRTETMF = "Time of Last Exposure Imput. Flag",
  LSTALVDT = "Date Last Known Alive"
  
)

for (v in names(adsl_labels)) {
  attr(adsl[[v]], "label") <- adsl_labels[[v]]
}

###################################################
# STEP 8) Output Final Dataset and Log File
###################################################

#output
write.csv(
  adsl,
  file = "Question_2_ADaM/output/adsl.csv",
  row.names = FALSE,
  na = ""
)

#log
cat("\n========================================\n")
cat("Program completed successfully\n")
cat("Completed:", format(Sys.time()), "\n")
cat("\nDataset summary\n")
cat("----------------------------\n")
cat("Rows:", nrow(adsl), "\n")
cat("Columns:", ncol(adsl), "\n")

cat("\nVariable names:\n")
print(names(adsl))

cat("\nStructure:\n")
str(adsl)
cat("========================================\n")

sink()
      
      


  
