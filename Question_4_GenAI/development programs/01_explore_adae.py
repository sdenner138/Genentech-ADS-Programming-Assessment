#############################################################################
# 
# Program Name : 01_explore_adae.py
#
# Purpose: Read in ADAE and explore it in Python. Explore Pandas.
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

############################################################################
# Question 4 Step 2) Read and Explore ADAE, implement display improvements
############################################################################

import pandas as pd

## Ensure that data does not cut off - display everything
pd.set_option("display.max_columns", None)
pd.set_option("display.max_colwidth", None)

# Read the CSV file into a Pandas DataFrame. Ensure all columns
# are character, since the GenAI assistant will read AESEV, AETERM, AESOC,
# and all are character.
adae = pd.read_csv("Question_4_GenAI/adae.csv", dtype = str)

# Display summary statistics
print("Number of Rows and Columns:")
print(adae.shape)

print("\nColumn names:")
print(adae.columns.tolist())

print("\nFirst five records:")
print(adae.head())

####################################################
# Question 4 Step 3) Perform "Execution" Portion
####################################################

### Goal: Obtain unique subjects who had Adverse Events of Moderate severity.

### A.) Manually filter for moderate adverse events, this is NOT unique

moderate_ae = adae[
  adae["AESEV"]
  .fillna("")
  .str.contains(
    "MODERATE", 
    case=False,
    regex=False
  )
]

print("\nNumber of Moderate AE records:")
print(len(moderate_ae))

print("\nFirst five Moderate AE records:")
print(
    moderate_ae[
        ["USUBJID", "AETERM", "AESEV", "AESOC"]
    ].head()
)

### B.) Obtain unique subjects with Moderate AE's

moderate_subjids = (
  moderate_ae["USUBJID"]
  
  # Remove missing subjects if there are any
  .dropna()
  
  #get unique subjects
  .drop_duplicates()
  
  # sort alphabetically
  .sort_values()
  
  # convert to a list
  .tolist()
)

n_moderate_subjids = len(moderate_subjids)

print("\nNumber of unique subjects with Moderate AEs:")
print(n_moderate_subjids)

print("\nMatching subject USUBJID's:")
print(moderate_subjids)
