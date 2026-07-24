#############################################################################
#
# Program Name : 02_create_visualizations.R
#
# Purpose: Generate Adverse Events Summary visualizations using {ggplot2}
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

output_file1 <- file.path(output_dir, "q3_plot1.png")
output_file2 <- file.path(output_dir, "q3_plot2.png")
log_file <- file.path(log_dir, "02_create_visualizations.log")

### Start Log
sink(log_file, split = TRUE)

cat("========================================\n")
cat("Question 3 - Create AE Visualizations\n")
cat("Started:", format(Sys.time()), "\n")
cat("========================================\n\n")

##########################################
# STEP 1) Load Packages and Read in Data
##########################################

library(ggplot2)
library(dplyr)

adae <- pharmaverseadam::adae

##########################################################
# PLOT 1, STEP 1) Prepare data for visualization
##########################################################

# The desired plot is a stacked bar chart with the legend shown.
# To create this we can use the ggplot2 geom_col function. We will
# use geom_col instead of geom_bar, because we want the height of the bar
# proportional to the number of cases in each group.
# SOURCE: https://ggplot2.tidyverse.org/reference/geom_bar.html

# Prepare data.

dat1 <- adae %>%
  
  # keep only records where AESEV is not missing and ACTARM is not missing
  filter(
    !(is.na(ACTARM)),
    ACTARM != "",
    !(is.na(AESEV)),
    AESEV != ""
  ) %>%
  
  # convert AESEV levels to factor to control the order of the plot.
  # The first factor level
  # appears at the bottom/at the left of the plot
  mutate(
    AESEV = factor(
      AESEV,
      levels = c("SEVERE", "MODERATE", "MILD")
      )
    )%>%
  
  # Convert ACTARM to factor
  mutate(
    ACTARM = factor(
      ACTARM,
      levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
    )
  )  %>%
  
  # Create a count of the number of total AE's within 1. each treatment group
  # and 2. each severity
  count(
    ACTARM,
    AESEV,
    name = "n_ae"
  )
      
####################################################################
# PLOT 1, STEP 2) Generate the visualization
# Source) https://ggplot2-book.org/getting-started

# Bonus: I will create an interactive plot, in addition, to showcase
# skills in ggplotly function in plotly package
#####################################################################

## Define the ggplot object - this gives us the background
plot1 <- ggplot(
  data = dat1,
  
  #we want trt on x, count on y, and fill to be the severity
  mapping = aes(
    x = ACTARM,
    y = n_ae,
    fill = AESEV,
    
    ## for the interactive plot, define text to hover
    text = paste0("N = ", n_ae)
    )
) +
  
  ## add 1 bar for each treatment group with a custom width,
  ## and add in a thin border between severity levels to emphasize
  ## stacks
  geom_col(width = 0.8, color = "white", linewidth = 0.2) +
  
  ## Add a count label inside each segment, only if there are at
  ## least 10 AE's
  geom_text(
    aes(label = ifelse(n_ae>10, n_ae, "")),
    position = position_stack(vjust = 0.5),
    color = "black",
    size = 3.5
  ) +
  
  ## assign a scale to the colors of the fill that so that I can 
  ## specify my own colors that I think match the severity level
  ## use scale_fill_manual, not scale_color_manual, since we assigned
  ## fill=AESEV in the aes() call. scale_fill_manual affects aesthetics
  ## mapped with fill.
  scale_fill_manual(
    values = c(
      "MILD" = "lightgreen",
      "MODERATE" = "darkorange",
      "SEVERE" = "darkred"
    ),
    name = "Severity/Intensity",
    
  ) +
  
  ## Add plot title and axis labels
  labs(
    title = "AE Severity Distribution by Treatment",
    subtitle = "Pharmaverse ADAE Summary",
    x = "Treatment Arm",
    y = "Count of AEs",
    caption = "NOTE: If no count is shown on a section of a bar, there are <10 AE's in that treatment arm and severity level"
  ) + 
  
  ## Apply a clear background
  theme_bw() +
  
  ## Center the title and Subtitle
  theme(plot.title = element_text(hjust = 0.5, face = "bold"),
        plot.subtitle = element_text(hjust = 0.5, face = "bold"),
        plot.caption = element_text(hjust = 0)
        )

########################################################################
# PLOT 1, STEP 3) Save and output both plots (one as PNG, one as html)
########################################################################

# Static PNG
ggsave(filename = output_file1,
       plot = plot1,
       width = 9, height = 6, units = "in", dpi = 300, bg = "white"
       )

cat("========================================\n")
cat("Question 3 Plot 1 Script Complete\n")
cat("Completed:", format(Sys.time()), "\n")
cat("========================================\n\n")


##########################################################
# PLOT 2, STEP 1) Prepare data for visualization
##########################################################