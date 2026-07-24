#############################################################################
#
# Program Name : 03_structured_output.py
#
# Purpose: Define and test the structured output returned by the LLM
#
# Author: Sara Denner
# Date: 7/24/2026
#############################################################################

############################################################################
# Question 4 Step 4.5) Understand What even is a GenAI Assistant?
############################################################################

### What is LangChain?
### Source) https://docs.langchain.com/build-overview
### LangChain is a tool that gives users the building blocks
### to build AI agents.

### Essentially what I will be building is a tool that can turn a user's
### natural-language typed input like "Give me the subjects who had
### moderate adverse events" into a response - the response is the 
### return of the count of unique USUBJIDs and the matching USUBJIDs.

### To do this we have to follow this flow:
### 1. User input
###
### 2. LLM is used to understand the user's NLP input, and returns
###    the structured JSON output like
### {
###   "target_column": "AESEV",
###   "filter_value": "MODERATE"
### }
###
### 3. Give that JSON output to the Python function we programmed in 
###    02_filter_function.py. It will filter ADAE using Pandas.
###
### 4. Return the subject ID's and count.

### Here we are going to develop a Pydantic model. LangChain will use this model
### to tell the LLM exactly what structured output to produce, then validates
### that the returned data matches the model. 
###
### The schema forces the LLM to return the target_column and the filter_value.
### When the LLM returns that schema, it can be fed directly into the Python function.
###
### Part of this schema is the "validated" part. So, we have to conduct a 
### validation of the LLM's JSON output to ensure it's outputting 
### the right structure.
### 
### The flow can be visualized like this:
### pydantic model -> LangChain reads the model -> LangChain tells the LLM
### "return the data in this specific format" -> LLM returns the JSON in the
### communicated format -> Pydantic validates the JSON

############################################################################
# Question 4 Step 5) Define Structured LLM Output
############################################################################

### First, we will ensure that the LLM can only take the three strings
### that we are defining as "allowed". To do this we load the 'typing'
### package and use 'Literal' to parse and ensure the input meets what is "allowed"
from typing import Literal

### Next, we will load in a package (pydantic) that can validate the 
### JSON output to ensure all of the necessary stuff exists. We will use
### class QueryInstruction - each object of the QueryInstruction class must contain
### target_column and filter_value (like - AESEV and MODERATE). BaseModel
### is a pydantic class that gives us the tools to perform the validation
from pydantic import BaseModel, Field

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

###### Test a valid structured response

test_instruction = QueryInstruction(
  target_column="AESEV",
  filter_value="MODERATE"
)

print("Structured Python object:")
print(test_instruction)

print("\nStructured JSON output:")
print(test_instruction.model_dump_json(indent=2))

############################################################################
# Question 4 Step 6) Reflect and Understand Next Steps
############################################################################

## I have the Pydantic model working.
## Now, I am manually defining the JSON output that the LLM needs to interpret.
##
## I am the user. So, now we need to make it so that I can simply type:
## "Give me the subjects who had moderate adverse events."...
##
## ...and the LLM will create that Pydantic object automatically.

