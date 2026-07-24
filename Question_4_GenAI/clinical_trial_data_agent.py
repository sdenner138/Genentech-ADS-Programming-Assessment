#############################################################################
#
# Program Name : clinical_trial_data_agent.py
#
# Purpose: Create a GenAI-style clinical data assistant that translates
#          natural-language AE questions into structured Pandas queries.
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

###############################################################################
# NOTE TO REVIEWER: all of the logic and learning that went into the creation
# of this program is stored in files 00-04 in the Question_4_GenAI folder
# of this repository. The code stored here will be commented, but not as
# detailed as those previous programs. 
#
# Please also note - I do not have an OpenAI key. I will mock the LLM 
# response in my code. The logic flow will be completed below.
################################################################################

############################################################################
# Load Packages
############################################################################

# See 03_structured_output.py for reasoning.
from typing import Literal
from pydantic import BaseModel, Field
import pandas as pd

############################################################################
# Define the structured output schema
############################################################################

# define "QueryInstruction" class, which uses BaseModel to validate the 
# LLM output. The descriptions explain to the LLM what each field is.

class QueryInstruction(BaseModel):
  """
  Structured filtering instructions produced by LLM or mock LLM.
  """
  target_column: Literal["AESEV", "AETERM", "AESOC"] = Field(
    description=(
      "The ADAE column to filter. "
      "Use AESEV for adverse event severity or intensity. "
      "Use AETERM for a specific reported adverse event term. "
      "and use AESOC for a System Organ Class or body system."
    )
  )
  
  filter_value: str = Field(
    description=(
      "The value extracted from the user's question "
      "that should be searched for in the target column"
    )
  )
  
############################################################################
# Define the Clinical Trial Data Agent
############################################################################


