# Genentech-ADS-Programming-Assessment

Sara Denner
July 2026

This repository contains my solutions to the Genentech Analytical Data Science (ADS) Programmer Coding Assessment. 
The assessment demonstrates clinical programming skills using Pharmaverse in R and Python, including:

1. SDTM dataset creation
2. ADaM dataset creation
3. Tables, Listings, and Graphs (TLGs)
4. Generative AI Clinical Data Assistant (LLM & LangChain)

---------------------

# Repository Structure

## Rendered Output
The Question 3 summary TEAE table is provided as both an interactive HTML output
and a corresponding HTML file. Please view the rendered table below:

**[View the rendered Treatment-Emergent Adverse Events table](https://sdenner138.github.io/Genentech-ADS-Programming-Assessment/Question_3_TLG/teae_summary_table.html)**

The corresponding HTML file is also retained in:
`Question_3_TLG/output/teae_summary_table.html`

## Question_1_SDTM

Generate SDTM Disposition (DS) domain using the {sdtm.oak} package.
Deliverables:

1. SDTM creation script
2. Output DS dataset
3. Program log

---

## Question_2_ADaM

Generate ADaM Subject-level Analysis (ADSL) dataset using the {admiral} package.
Deliverables:

1. ADaM creation script
2. Output ADSL dataset
3. Program log

---

## Question_3_TLG

Generate treatment-emergent adverse event (TEAE) outputs using {gtsummary} and {ggplot2} packages.
Deliverables:

1. TEAE Summary table script
2. TEAE Summary visualization script
3. Output table:
  - [View the rendered TEAE summary table](https://sdenner138.github.io/Genentech-ADS-Programming-Assessment/Question_3_TLG/teae_summary_table.html)
  - Source program: `Question_3_TLG/q3_01_create_ae_summary_table.R`
  - Output file: `Question_3_TLG/output/teae_summary_table.html`
4. Two Output PNG files
5. Program logs

---

## Question_4_Python

Develop a GenAI Clinical Data Assistant using Python.
Deliverables: 

1. Code of the solution developed
2. Test script
3. Example outputs

---

## Documentation

Contains supplementary documentation including:

- R Session Information
- Additional project documentation


# Software

- R 4.6.1
- Posit Cloud
- Python
- Git
- GitHub

---

# Primary R Packages

- admiral
- sdtm.oak
- tidyverse
- gtsummary
- gt
- ggplot2

---

# Repository Status

1. [7/15/2026 SD] GitHub Repository shell created, including file structure.
2. [7/20/2026 SD] SDTM deliverables generated.
3. [7/21/2026 SD] ADaM deliverables generated.
4. [7/22/2026 SD] Summary TEAE table and corresponding deliverables generated.

---

# Notes

AI-assisted development tools were used in the creation of this repository and its contents to accelerate learning new concepts, explore the Pharmaverse ecosystem, and improve code quality. All submitted code was reviewed, understood, tested, and validated by Sara Denner.
