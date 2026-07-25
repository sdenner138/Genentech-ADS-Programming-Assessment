#############################################################################
#
# Program Name : clinical_trial_data_agent.py
#
# Purpose: Create a GenAI-style clinical data assistant that translates
#          natural-language AE questions into structured Pandas queries.
#
# Author: Sara Denner
# Date: 7/25/2026
#############################################################################

###############################################################################
# NOTE TO REVIEWER: all of the logic and learning that went into the creation
# of this program is stored in files 00-04 in the Question_4_GenAI folder
# of this repository. The code stored here will be commented, but not as
# detailed as those previous programs. 
################################################################################

############################################################################
# Load Packages
############################################################################

# See 03_structured_output.py for reasoning.
from typing import Literal
from pydantic import BaseModel, Field
import pandas as pd

# LLM packages
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI


############################################################################
# Define the structured output schema
############################################################################

# define "QueryInstruction" class, which uses Pydantic's BaseModel function
# to validate the LLM output. The descriptions explain to the LLM what 
# each field is.
# Defining target_column using Literal[] ensures that the input string
# MUST be within the 3 defined terms.

class QueryInstruction(BaseModel):
  """
  Structured filtering instructions produced by the LLM.
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
    min_length=1,
    description=(
      "The non-empty value extracted from the user's question "
      "that should be searched for in the selected target column"
    )
  )
  
############################################################################
# Define the Clinical Trial Data Agent
############################################################################

# Define a reusable object that groups the entire LLM workflow together
class ClinicalTrialDataAgent:
    """
    Interpret natural-language adverse event questions and execute the 
    corresponding Pandas query against an ADAE dataframe.
    """

    ## Initialize the agent's class.
    ## "self" is the current instance of the agent.
    def __init__(
        self,
        dataframe: pd.DataFrame,
        model_name: str = "gpt-5-mini"
    ):
        """
        Initialize the agent.

        Parameters
        ----------
        dataframe : pandas.DataFrame
            ADAE dataset.

        model_name : str
            OpenAI model used to interpret the user's question.
        """

        # Store the ADAE dataset inside the agent. We copy it 
        # to reduce the risk of changing the original data if the agent
        # performs any changes on it
        self.dataframe = dataframe.copy()

        ## SCHEMA DEFINITION - define the string that describes the
        ## relevant columns to the LLM. It gives the LLM context.
        self.dataset_schema = {
            "AESEV": (
                "Adverse event severity or intensity. "
                "Example values include MILD, MODERATE, and SEVERE."
            ),
            "AETERM": (
                "Reported term for a specific adverse event or condition. "
                "Example values include HEADACHE and NAUSEA."
            ),
            "AESOC": (
                "System Organ Class or body system associated with the "
                "adverse event. Example values include CARDIAC DISORDERS "
                "and SKIN AND SUBCUTANEOUS TISSUE DISORDERS."
            )
        }
        
        ## Fail-Fast validation:
        ## The agent must validate the input ADAE dataset to ensure
        ## that the necessary columns are included in the dataset
        self._validate_dataframe()

        ## Connect the agent to an LLM model. Use the model=model_name, where
        ## model_name can change the model without rewriting the class
        self.llm = ChatOpenAI(
            model=model_name,
            
            # temperature tells the model to behave more consistently and 
            # less creatively; we want classification and extraction. It
            # should not create alternative wording to the structure of the
            # defined output.
            temperature=0
        )

        ## Tell the model to output a STRUCTURED output object
        ## that matches the QueryInstruction definition from earlier
        self.structured_llm = self.llm.with_structured_output(
            QueryInstruction,
            method="json_schema",
            strict=True
        )

        ## Create two prompts to the LLM - "system", which contains
        ## the rules for the LLM's activity; "human", which will be
        ## populated with the user's question when we run it
        self.prompt_template = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    """
You are a clinical trial data assistant.

Translate the user's natural-language question into one structured
filtering instruction for the ADAE dataset.

Use the dataset schema below to determine the correct target column.

Dataset schema:
{dataset_schema}

Instructions:
- Use AESEV when the question concerns adverse event severity or intensity.
- Use AETERM when the question concerns a specific adverse event or condition.
- Use AESOC when the question concerns a body system or System Organ Class.
- Extract only the value that should be searched for.
- Do not invent a column outside the supplied schema.
                    """.strip()
                ),
                (
                    "human",
                    "{user_question}"
                )
            ]
        )

        ## LangChain pipeline. Take the completed prompt (prompt_template),
        ## send it to the structured LLM (which includes our schema definiton),
        ## and then return a QueryInstruction structured JSON Output
        self.chain = (
            self.prompt_template
            | self.structured_llm
        )


    ### tell the agent to validate that the input dataframe
    ### contains the necessary variables, but don't tell the user
    ### if it finishes successfully. Tell the user if there
    ### are any missing columns in ADAE.
    def _validate_dataframe(self) -> None:
        """
        Confirm that the dataframe contains the required variables.
        """

        required_columns = {
            "USUBJID",
            "AESEV",
            "AETERM",
            "AESOC"
        }

        ### define which columns are missing
        missing_columns = (
            required_columns
            - set(self.dataframe.columns)
        )

        if missing_columns:
            raise ValueError(
                "The ADAE dataframe is missing required columns: "
                f"{sorted(missing_columns)}"
            )

    ## Convert the schema we defined earlier into readable prompt text
    ## that the LLM can interpret
    def _format_schema(self) -> str:
        """
        Convert the dataset schema dictionary into prompt text.
        """

        return "\n".join(
            f"- {column}: {description}"
            for column, description
            in self.dataset_schema.items()
        )

    ## Here we perform the prompt --> parse part of the logic flow.
    ## It uses the LLM to turn the natural language prompt into 
    ## the JSON structured output.
    def parse_question(
        self,
        user_question: str
    ) -> QueryInstruction:
        """
        Convert a natural-language question into a validated instruction.

        Parameters
        ----------
        user_question : str
            Clinical safety question entered by the user.

        Returns
        -------
        QueryInstruction
            Validated target column and filter value.
        """

        if not user_question.strip():
            raise ValueError(
                "The user question cannot be blank."
            )
            
        ## Execute the chain we defined above. LangChain fills
        ## in the template, sends the message to the OpenAI model,
        ## then returns the validated QueryInstruction.
        instruction = self.chain.invoke(
            {
                "dataset_schema": self._format_schema(),
                "user_question": user_question
            }
        )

        ## Return what the LLM decided based on our pipeline, to determine
        ## whether it's interpreting our instructions correctly.
        return instruction

    ## EXECUTE - Create a function that takes the output from the LLM (the validated instruction),
    ## and pass it to the function we built in Pandas to filter ADAE
    def execute_query(
        self,
        instruction: QueryInstruction
    ) -> dict:
        """
        Apply the validated LLM instruction to ADAE.

        Parameters
        ----------
        instruction : QueryInstruction
            Structured target column and filter value returned by the LLM.

        Returns
        -------
        dict
            Filter interpretation, unique-subject count, and subject IDs.
        """
        
         # Remove leading and trailing spaces from the LLM-produced value.
        filter_value = instruction.filter_value.strip()
    
        # Prevent an empty or spaces-only value from matching every record.
        if not filter_value:
            raise ValueError(
                "The filter value returned by the LLM cannot be blank."
            )

        filtered = self.dataframe[
            self.dataframe[instruction.target_column]
            .fillna("")
            .str.contains(
                filter_value,
                
                # Ensure that any value passed is not case sensitive
                case=False,
                
                # Treat all text as ordinary text(no accidental interpretation
                # of special characters into regex)
                regex=False
            )
        ]

        subject_ids = (
            filtered["USUBJID"]
            .dropna()
            .drop_duplicates()
            .sort_values()
            .tolist()
        )
        
        ## Modify the original function, which originally returned a tuple,
        ## into a dictionary. This allows the output to be more descriptive.
        return {
            "target_column": instruction.target_column,
            "filter_value": filter_value,
            "subject_count": len(subject_ids),
            "subject_ids": subject_ids
        }

    ## Turn the user question --> parse_question() --> QueryInstruction -->
    ## --> execute_query() --> Result dictionary
    def ask(
        self,
        user_question: str
    ) -> dict:
        """
        Run the complete Prompt -> Parse -> Execute workflow.
        """

        instruction = self.parse_question(
            user_question
        )

        result = self.execute_query(
            instruction
        )

        return result

