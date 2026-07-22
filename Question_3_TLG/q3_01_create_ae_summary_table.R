#############################################################################
# 
# Program Name : q3_01_create_ae_summary_table.R
#
# Purpose: Generate TEAE Summary by SOC and PT, Table using {gtsummary}
#
# Author: Sara Denner
#
#############################################################################

##################################################
# STEP 0) Initialize Project Directories and Log
##################################################

question_dir <- "Question_3_TLG"

output_dir <- file.path(question_dir, "output")
log_dir <- file.path(question_dir, "logs")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

output_file <- file.path(output_dir, "teae_summary_table.html")
log_file <- file.path(log_dir, "q3_01_create_teae_summary_table.log")

### Start Log
sink(log_file, split = TRUE)

cat("========================================\n")
cat("Question 3 - Create TEAE Summary by SOC/PT Table\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

##########################################
# STEP 1) Load Packages and Read in Data
##########################################

library(dplyr)
library(gtsummary)
library(gt)

adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

###################################################################################
# STEP 2) Filter to Analysis Population (TRTEMFL =="Y") & Define Treatment Groups
###################################################################################

# Define order for display of columns
trt_ord <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

# Exclude screen failures in ADSL to ensure correct denominator counts
adsl01 <- adsl %>%
  filter(
    ACTARM %in% trt_ord
  ) %>%
  
  # Implement column ordering here
  mutate(
    ACTARM = factor(
      ACTARM, 
      levels = trt_ord
    )
  )

# Limit ADAE to subjects who exist in ADSL via inner join
# Restrict population to TRTEMFL == "Y", exclude records where AESOC is null and where reported
# term is null
# Establish correct ordering of columns by converting to factor type
adae01 <- adae %>%
  dplyr::filter(
    TRTEMFL == "Y",
    USUBJID %in% adsl01$USUBJID,
    ACTARM %in% trt_ord,
    !is.na(AETERM),
    !is.na(AESOC)
  ) %>%
  mutate(
    ACTARM = factor(
      ACTARM,
      levels = trt_ord
    )
  )

##########################################################################################
# STEP 3) Create Summary Table using {gtsummary} tbl_hierarchical function
# Source A) https://pharmaverse.github.io/cardinal/quarto/catalog/fda-table_10/
# Source B) https://www.danieldsjoberg.com/gtsummary/reference/sort_hierarchical.html
#
# NOTE: Normally this kind of table is hierarchical by system organ class (SOC; AESOC), then by
# preferred term (PT; AEDECOD). The assessment instructions specifically say to use
# AETERM instead of AEDECOD, so I will follow those instructions.
##########################################################################################

tbl <- adae01 %>%
  
  # Use tbl_hierarchical because we are interested in rates (n(%)) 
  tbl_hierarchical(
    
    # List AESOC before AETERM, as SOC is higher in hierarchy level than AETERM
    variables = c(AESOC,AETERM),
    
    # Stratify by treatment group
    by = ACTARM,
    
    # Participants counted once for each SOC and once for each AETERM
    id = USUBJID,
    
    # Use all subjects per defined treatment groups
    denominator = adsl01,
    
    # Display n(%)
    statistic = everything() ~ "{n} ({p}%)",
    
    # Add in Any TEAE count row
    overall_row = TRUE,
    label = list(
      AESOC ~ "Primary System Organ Class",
      AETERM ~ "Reported Term for the Adverse Event",
      "..ard_hierarchical_overall.." ~ "Any Treatment-Emergent AE"
    )
  ) %>%
  
  # To make this table look as close to FDA submission-style tables as possible,
  # add a third row in the header capturing n(%)
  modify_header(
    all_stat_cols() ~ "**{level}**  \nN = {n}  \nn (%)"
  ) %>%
  
  # Add in Overall(Total) column
  add_overall(
    
    #appear furthest right in table
    last = TRUE,
    col_label = "**Overall**  \nN = {N}  \nn (%)"
  ) %>%

  # Sort SOC by descending total frequency, sort AETERM by 
  # descending total frequency within SOC
  sort_hierarchical(
    sort = everything() ~ "descending"
  )

# Replace '0(0%)' with '0' to emphasize missingness
tbl1 <- tbl %>%
  modify_table_body(
    ~ .x %>%
      dplyr::mutate(
        
        # across is like a do-loop in SAS; apply this for all statistics columns
        dplyr::across(
          starts_with("stat_"),
          
          # in each statistics column, replace values matching a zero-count percentage
          # with just '0'
          ~ gsub("^0 \\([^)]*%\\)$", "0", .)
        )
      )
  )


#################################################################################
# STEP 4) Format the table using {gt}; add header and footnotes
# Source A) https://gt.rstudio.com/
# Source B) https://gt.rstudio.com/reference/tab_header.html?q=header#null
# AI was used to help style the gt object.
##################################################################################

tbl_gt <- tbl1 %>%
  
  # Convert the table to a gt object
  as_gt() %>%
  
  ## Assessment Name
  tab_header(
    title = html("
        <div style='text-align:left;font-size:14px'>
        <b>Genentech ADS Programming Assessment</b>
        </div>
        
        <div style='text-align:center;font-size:18px'>
        <b>Table X.X.X</b><br>
        Treatment-Emergent Adverse Events by Primary System Organ Class and Reported Term
        </div>
        ")
  ) %>%
  
  ## Footnotes
  tab_source_note(
    source_note = 
      md("TEAE = Treatment Emergent Adverse Event.<br>
      N = Total number of participants in the treatment group.<br>
      n = Number of participants with at least one treatment-emergent adverse event.<br>
      Note 1: Adverse events were coded using MedDRA verision XX<br>
      Note 2: Participants were counted once for each system organ class and once for each reported term."
         )
  )


###########################################################################
# STEP 5) Export Output as HTML, Generate Log File
# Source A) https://gt.rstudio.com/reference/gtsave.html?q=html#examples
###########################################################################

# Since GT objects support HTML output, we will output to HTML using gtsave()
gt::gtsave(
  data = tbl_gt,
  filename = "teae_summary_table.html",
  path = "Question_3_TLG/output"
)

#log
cat("\n========================================\n")
cat("Program completed successfully\n")
cat("Completed:", format(Sys.time()), "\n")
cat("========================================\n")

sink()



