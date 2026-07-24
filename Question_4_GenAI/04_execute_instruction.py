#############################################################################
#
# Program Name : 04_execute_instruction.py
#
# Purpose: Connecting the dots and understanding what I've done so far,
#         by creating a single script that creates the QueryInstruction,
#         creates the filter_subjects() function, and imports the ADAE dataset.
#         I'm doing this before integrating AI, to understand the structure of the
#         agent.
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

############################################################################
# Question 4 Step 7) Connect the schema from 03_structured output.py
#                     to the filtering function.
############################################################################

############################################################################
### 1.) Load packages and read in data.
############################################################################

# See 03_structured_output.py for reasoning.
from typing import Literal
from pydantic import BaseModel, Field
import pandas as pd

############################################################################
### 2.) Create the QueryInstruction - define and validate LLM output as JSON
############################################################################

# define "QueryInstruction" class, which uses BaseModel to validate the 
# LLM output. The descriptions explain to the LLM what each field is.
class QueryInstruction(BaseModel):
  """
  Structured filtering instructions returned by the LLM.
  """
  target_column: Literal["AESEV", "AETERM", "AESOC"] = Field(
    description=(
      "The ADAE column to filter. "
      "Use AESEV for adverse event severity or intensity. "
      "Use AETERM for a specific reported adverse event term. "
      "and use AESOC for a System Organ Class."
    )
  )
  
  filter_value: str = Field(
    description=(
      "The value extracted from the user's question "
      "that should be searched for in target_column"
    )
  )
############################################################################
### 3.) Define the filtering function that will pass QueryInstruction
###     and use pandas to filter ADAE and get the output we need.
############################################################################
def filter_subjects(
  dataframe,
  instruction
):
  
  """
  Filter ADAE and return the matching subjects who correspond to 
  the input query.
  
  Parameters
  ------------
  dataframe : pandas.DataFrame
    Pharmaverse ADAE dataset.
    
  instruction : QueryInstruction
    Structured JSON output containing the target column
    and filter value
    
  Returns
  ------------
  1. tuple
    Number of unique subjects and list of USUBJIDs.
  """
    
  filtered = dataframe[
    dataframe[instruction.target_column]
    .fillna("")
    .str.contains(
      instruction.filter_value, 
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
### 4.) Test structured output with the Pandas execution function
############################################################################

adae = pd.read_csv(
    "Question_4_GenAI/adae.csv",
    dtype=str
)

instruction = QueryInstruction(
    target_column="AESEV",
    filter_value="MODERATE"
)

count, ids = filter_subjects(
    dataframe=adae,
    instruction=instruction
)

print("Structured Python object:")
print(test_instruction)

print("\nStructured JSON output:")
print(test_instruction.model_dump_json(indent=2))

print(f"\nUnique subject count: {count}")

print("\nSubject IDs:")
print(ids)


