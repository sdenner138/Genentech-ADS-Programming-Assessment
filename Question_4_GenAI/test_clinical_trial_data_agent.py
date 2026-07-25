#############################################################################
#
# Program Name : test_clinical_trial_data_agent.py
#
# Purpose: Test the ClinicalTrialDataAgent using three natural-language
#          adverse event questions.
#
# Author: Sara Denner
# Date: 7/25/2026
#############################################################################

##############################################
# Import packages
##############################################

import pandas as pd
from clinical_trial_data_agent import ClinicalTrialDataAgent

##############################################
# Load Data
##############################################

# Read the CSV file into a Pandas DataFrame. Ensure all columns
# are character, since the GenAI assistant will read AESEV, AETERM, AESOC,
# and all are character.
adae = pd.read_csv("Question_4_GenAI/adae.csv", dtype = str)

# define the agent from what we created
agent = ClinicalTrialDataAgent(
  dataframe=adae
)

##############################################
# Define Natural-Language Questions
##############################################

questions = [
  "Give me the subjects who had Adverse events of Moderate severity.",
  "Which subjects experienced headache?",
  "Which subjects had adverse events in the cardiac disorders body system?"
]

######################################################
# Use the agent to print the results to our questions
######################################################

for question in questions:
  print("=" * 80)
  print(f"Question: {question}")
  
  try:
    result = agent.ask(question)
    
    print(f"Target Column: {result['target_column']}")
    print(f"Filter value: {result['filter_value']}")
    print(f"Unique subject count: {result['subject_count']}")
    print(f"Subject IDs: {result['subject_ids']}")
    
  except Exception as error:
    print(f"Error: {error}")
