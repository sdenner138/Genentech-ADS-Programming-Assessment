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
library(epiR)

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
# PLOT 1, STEP 3) Save and output plot
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

## for this plot we need to calculate and display the incidence rates
## for the top 10 most frequent AE's.

## first, to filter to the top 10 most frequent AE's, we need to 
## count the number of times each AE occurred.
## We will count a subject once within each AETERM.

ae_freq <- adae %>%
  # select distinct AETERM per USUBJID
  distinct(USUBJID,AETERM) %>%
  # count the instances of each AETERM after limiting to distinct
  count(AETERM, name = "n")

## sort descending by n to get the top ten most frequent AE's

t10 <- ae_freq %>%
  arrange(desc(n)) %>%
  slice_head(n=10)

##################################################################
# PLOT 2, STEP 2) Calculate Incidence Rate and Clopper-Pearson CI
##################################################################

## To calculate incidence rate, we can divide #of cases/N, where
## N = the number of subjects in ADSL.

N <- pharmaverseadam::adsl %>%
  filter(
    # filter to subjects who were not screen failures
    SAFFL == "Y"
  ) %>%
  distinct(USUBJID) %>%
  # count the number of nows
  nrow()

t10 <- t10 %>%
  mutate(
    inc_check = n/N
  ) %>%
  
  # Calculate incidence rate and Clopper-Pearson CI
  # SOURCE: https://search.r-project.org/CRAN/refmans/epiR/html/epi.conf.html
  # We can use the epi.conf() function to calculate the Clopper-Pearson CI
  # for an incidence rate. To do this we have to convert the dataset into a
  # matrix.
  rowwise() %>%
  mutate(
    ci_result = list(
      epiR::epi.conf(
        dat = matrix(
          c(n, N),
          nrow = 1,
          ncol = 2
        ),
        ctype = "inc.risk",
        method = "clopper-pearson",
        N = N,
        design =1,
        conf.level = 0.95
      )
    ),
    
    # Get the estimate and confidence limits
    incidence = ci_result[1, "est"],
    lower_ci = ci_result[1, "lower"],
    upper_ci = ci_result[1,"upper"]
  ) %>%
  
  # Convert the proportions to percentages for the plot
  mutate(
    incidence_pct = incidence*100,
    lower_pct = lower_ci*100,
    upper_pct = upper_ci*100
  ) %>%
  select(-c(ci_result, inc_check, incidence, lower_ci, upper_ci))

##################################################################
# PLOT 2, STEP 3) Generate the forest plot
##################################################################

## Convert AETERM values to factor to control the display order
t10 <- t10 %>%
  arrange(incidence_pct) %>%
  mutate(
    AETERM = factor(
      AETERM,
      levels = AETERM
    )
  )

## Plot
## Source: https://ggplot2.tidyverse.org/reference/geom_linerange.html

plot2 <- ggplot(
  t10, aes(x =incidence_pct, y = AETERM)
) +
  
  # We can use a horizontal error bars plot to plot the 95% CI
  geom_errorbar(
    
    # Create the 95% CI on the plot
    aes(xmin = lower_pct, xmax = upper_pct),
    
    # Display horizontally
    orientation = "y",
    
    height = 0.25,
    width = 0.25
    
  ) +
  
  ## Add in points at the true incidence pct
  geom_point(
    size = 3
  ) + 
  
  ## Add in text to show the incidence
  geom_text(
    aes(
      
      ## Place a statistic next to each confidence interval
      x = upper_pct,
      label = sprintf(
      "%.1f%% (95%% CI: %.1f, %.1f)",
      incidence_pct, lower_pct, upper_pct
      )
    ),
    hjust = -0.1, size = 3.2
  ) +
  
  ## Provide x-axis space for the labels
  scale_x_continuous(
    
    # fit the x axis labels with a %
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0.02, 0.35))
    ) +
  
  ## Add Title and axis titles
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0(
      "N = ", N, " subjects in the safety population; 95% Clopper-Pearson Confidence Intervals"
      ),
    x = "Percentage of Subjects (%)",
    y = NULL,
    caption = "NOTE 1: Point estimates represent the percentage of subjects with each adverse event term.\nNOTE 2: Subjects were counted once per adverse event term."
    
  ) +
  
  ## Add in a bw theme to match the first plot
  theme_bw() +
  
  ## Add in extra space into the plot margins to allow for
  ## space for captions, and Center the title and subtitle
  theme(plot.title = element_text(hjust = 0.5, face = "bold"),
        plot.subtitle = element_text(hjust = 0.5, face = "bold"),
        plot.caption = element_text(hjust = 0, size = 9, lineheight = 1.2),
        plot.margin = margin(t=20,r=25,b=20,l=10),
        
        # Erase horizontal grid lines for readability
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank()
  )
  
########################################################################
# PLOT 2, STEP 4) Save and output plot
########################################################################

# Static PNG
ggsave(filename = output_file2,
       plot = plot2,
       width = 9, height = 6, units = "in", dpi = 300, bg = "white"
)

cat("========================================\n")
cat("Question 3 Plot 2 Script Complete\n")
cat("Completed:", format(Sys.time()), "\n")
cat("========================================\n\n")

########################################################################
# FINAL STEP) Close the log
########################################################################

cat("\n========================================\n")
cat("Program completed successfully\n")
cat("Completed:", format(Sys.time()), "\n")
cat("========================================\n")

sink()
