#############################################################################
# 
# Program Name : 02_filter_function.py
#
# Purpose: Create a Reusable Filtering Function
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

############################################################################
# Question 4 Step 4) Build Function
############################################################################

### A.) Load packages and read in data.
import pandas as pd

adae = pd.read_csv(
  "Question_4_GenAI/adae.csv",
  dtype=str)
  
### B.) Build the function using the logic from 01_explore_adae.py
def filter_subjects(
  dataframe,
  target_column,
  filter_value
):
  
  """
  Filter ADAE and return the matching subjects who correspond to 
  the input query.
  
  Parameters
  ------------
  1. dataframe : pandas.DataFrame
    This will be the Pharmaverse ADAE dataset.
    
  2. target_col : str
    This is the column to search.
    
  3. filter_value : str
    This is the value to search within the specified column.
    
  Returns
  ------------
  1. tuple
    (number of unique subjects; list of USUBJIDs)
  """
  
  #### Validation step - limit to 3 allowed search columns for the 
  #### purpose of this assessment.
  allowed_columns = {"AESEV", "AETERM", "AESOC"}
  
  if target_column not in allowed_columns:
    raise ValueError(
      f"{target_column} is not a supported search column."
    )
    
  #### Insert the existing logic from 01_explore_adae.py into 
  #### the function.
    
  filtered = dataframe[
    dataframe[target_column]
    .fillna("")
    .str.contains(
      filter_value, 
      case=False,
      regex=False
    )
  ]
  
  subjids = (
    filtered["USUBJID"]
    .dropna()
    .drop_duplicates()
    .sort_values()
    .tolist()
  )
  
  subject_count = len(subjids)
  
  return subject_count, subjids


############################################################################
# Question 4 Step 5) Test Function
############################################################################

count,ids = filter_subjects(
  dataframe=adae,
  target_column="AESEV",
  filter_value="MODERATE"
)

print(f"Unique subject count: {count}")
print("\nSubject IDs:")

print(ids)

