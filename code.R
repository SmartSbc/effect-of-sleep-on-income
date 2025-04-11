library(haven)
library(dplyr)
library(ggplot2)
library(sf)
library(suncalc)
library(lubridate)
library(tidyr)
library(lmtest)
library(quantmod)
library(reshape2)
library(tseries)
library(lutz)
library(AER)
library(modelsummary)
##############################
# Cleaning function
mainframe_cleaner <- function(mainframe, sleep_range = c(0, 24), income_range = c(0, 1), age_range= c(0, 85), trunc_race = FALSE, earning_variable = FALSE){
  
  # Cleaning and Formatting Sleep
  mainframe$t010101 <- as.numeric(mainframe$t010101)
  mainframe$t010101 <- mainframe$t010101/60
  mainframe <- subset(mainframe, t010101 >= sleep_range[1] & t010101 <= sleep_range[2])
  # scaling sleep by 7 to consider it as weekly sleep time
  mainframe$t010101 <- mainframe$t010101 * 7
  
  
  # Cleaning and Formatting Race
  mainframe <- mainframe %>%
    mutate(ptdtrace.x = ifelse(ptdtrace.x >= 3 & ptdtrace.x != 4, 5, ptdtrace.x))
  race_labels <- c("White Only","Black only","Asian Only","Other")
  mainframe$ptdtrace.x <- factor(mainframe$ptdtrace.x, levels = c(1, 2, 4, 5), labels = race_labels)
  
  # Cleaning and Formatting Age
  mainframe$prtage <- as.numeric(mainframe$prtage)
  mainframe <- subset(mainframe, prtage >= age_range[1] & prtage <= age_range[2])
  
  # Generating age squared variable
  mainframe$prtagesq <- mainframe$prtage^2
  
  # Cleaning and Formatting Gender
  mainframe$pesex <- factor(mainframe$pesex, levels = c(1, 2), labels = c("Male", "Female"))
  
  # Cleaning and Formatting Occupation
  mainframe <- subset(mainframe, prdtocc1 != -1)
  mainframe <- subset(mainframe, premphrs != 0)
  occupation_labels <- c("Management occupations", "Business and financial operations occupations", "Computer and mathematical science occupations",
                         "Architecture and engineering occupations", "Life, physical, and social science occupations", "Community and social service occupations",
                         "Legal occupations", "Educational instruction and library occupations", "Arts, design, entertainment, sports, and media occupations",
                         "Healthcare practitioner and technical occupations", "Healthcare support occupations", "Protective service occupations",
                         "Food preparation and serving related occupations", "Building and grounds cleaning and maintenance occupations",
                         "Personal care and service occupations", "Sales and related occupations", "Office and administrative support occupations",
                         "Farming, fishing, and forestry occupations", "Construction and extraction occupations",
                         "Installation, maintenance, and repair occupations", "Production occupations", "Transportation and material moving occupations","Armed Forces")
  mainframe$prdtocc1 <- factor(mainframe$prdtocc1, levels = c(1:23), labels = occupation_labels)
  
  # Cleaning and Formatting Holiday
  mainframe$trholiday.x <- factor(mainframe$trholiday.x, levels = c(0, 1), labels = c("Not a Holiday", "Holiday"))
  
  # Cleaning and Formatting Year Dummy
  mainframe$hryear4 <- as.factor(mainframe$hryear4)
  
  # Cleaning and Formatting Wages
  mainframe <- subset(mainframe, prernwa != -1 & prernwa != 0)
  mainframe <- subset(mainframe, prernwa >=  quantile(mainframe$prernwa, income_range[1]) & prernwa <=  quantile(mainframe$prernwa, income_range[2])) # dropping extreme outliers
  mainframe$prernwa <- as.numeric(mainframe$prernwa) # treating the variable as a numeric 
  mainframe$prernwa <- mainframe$prernwa/100 # converting cents to dollars
  
  # Generating log(wage)
  mainframe$lwage <- log(mainframe$prernwa, base = exp(1)) 
  
  # Cleaning and Formatting Day of Week indicator
  mainframe$tudiarydate <- as.Date(as.character(mainframe$tudiarydate), format = "%Y%m%d")
  mainframe$tudiaryday.x <- factor(mainframe$tudiaryday.x, levels = c(1, 2, 3, 4, 5, 6, 7), labels = c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))
  
  location_labels <- c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID",
                       "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO",
                       "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA",
                       "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY")
  # saving the weights for regression
  mainframe$weights <- prop.table(mainframe$gestfips)
  mainframe$gestfips <- factor(mainframe$gestfips, levels = c(1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 16,
                                                              17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
                                                              30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
                                                              44, 45, 46, 47, 48, 49, 50, 51, 53, 54, 55, 56), labels = location_labels)
  
  # Cleaning and formatting Earnings
  if (earning_variable == TRUE){
  mainframe <- subset(mainframe,prernhly != -1 & prernhly >= 0) # removing blanks and 0 income observations
  mainframe <- subset(mainframe, prernhly >=  quantile(mainframe$prernhly, income_range[1]) & prernhly <=  quantile(mainframe$prernhly, income_range[2])) # dropping extreme outliers
  mainframe$prernhly <- as.numeric(mainframe$prernhly) # saving as numeric
  mainframe$prernhly <- mainframe$prernhly/100 # converting cents to dollars
  mainframe <- subset(mainframe, peernhro > 0) # removing zero income to prevent NaNs in log(income)
  mainframe$prernhly <- (mainframe$prernhly*mainframe$peernhro) # scaling hourly wage with no. of hours worked  
  
  # Generating log(earnings)
  mainframe$learnings <- log(mainframe$prernhly, base = exp(1))
  # Saving the necessary variables only
  mainframe <- subset(mainframe, select = c("prernwa", "t010101", "gestfips","ptdtrace.x","prtage", "pesex",
                                            "prdtocc1","trholiday.x", "tudiaryday.x", "tudiarydate",
                                            "gtcbsa", "hryear4", "prtagesq", "lwage", "learnings", "prernhly", "lat", "lon", "tz"))
  
  # Renaming the variables
  mainframe <- rename(mainframe, race = ptdtrace.x, sex = pesex, occupation = prdtocc1, holiday = trholiday.x, location = gestfips, day_of_week = tudiaryday.x , year = hryear4, date = tudiarydate, sleep = t010101, age = prtage, agesq = prtagesq, wage = prernwa, earnings = prernhly) 
  } else{
    mainframe <- subset(mainframe, select = c("prernwa", "t010101", "gestfips","ptdtrace.x","prtage", "pesex",
                                              "prdtocc1","trholiday.x", "tudiaryday.x", "tudiarydate",
                                              "gtcbsa", "hryear4", "prtagesq", "lwage", "lat", "lon", "tz"))
    mainframe <- rename(mainframe, race = ptdtrace.x, sex = pesex, occupation = prdtocc1, holiday = trholiday.x, location = gestfips, day_of_week = tudiaryday.x , year = hryear4, date = tudiarydate, sleep = t010101, age = prtage, agesq = prtagesq, wage = prernwa) 
  }
  mainframe <- subset(mainframe, gtcbsa != 0)
  
  # FINDING SUNSET TIMES
  
  # Getting the sunlight data
  sunset_times <- getSunlightTimes(data = mainframe, keep = c('sunset'))
  
  # Adding the sunset times to the mainframe
  mainframe$sunset_gmt <- sunset_times$sunset
  
  # Converting the sunlight data from UTC/GMT to local timezones
  mainframe$sunset_local <- mainframe$sunset_gmt
  i = 1
  # Use for loop rather than directly parsing vector as it results in syntax error
  for (i in 1:length(mainframe$sunset_local)){
    mainframe$sunset_local[i] <- format(mainframe$sunset_gmt[i], tz = mainframe$tz[i], usetz = TRUE)
  }
  # Dropping the date as the date control is taken separately
  mainframe$sunset_local <- format(mainframe$sunset_local, format = "%H:%M:%S")
  
  # Converting the time to seconds to make it suitable for regression
  
  # Define the time_to_seconds function
  time_to_seconds <- function(time_string) {
    # Split the time string by ":"
    time_components <- strsplit(time_string, ":")[[1]]
    # Convert the components to numeric values
    hours <- as.numeric(time_components[1])
    minutes <- as.numeric(time_components[2])
    seconds <- as.numeric(time_components[3])
    # Calculate the total seconds
    total_seconds <- hours * 3600 + minutes * 60 + seconds
    return(total_seconds)
  }
  # applying the function
  mainframe$sunset <- sapply(mainframe$sunset_local, time_to_seconds)
  
  # converting sunset_local to a double datatype measuring sunset in decimals
  mainframe$sunset_local <- mainframe$sunset / 3600
  
  # removing unnecessary variables for memory efficiency:
  rm("sunset_times", "i")
  
  # creating weights for the regression
  mainframe$weights <- prop.table(mainframe$gtcbsa)
  
  # saving counties as factors to create fixed effects
  mainframe$gtcbsa <- factor(mainframe$gtcbsa)
  
  # renaming the variable to be called "county"
  mainframe <- rename(mainframe, county=gtcbsa)
  
  return(mainframe)
}
categorical_plotter <- function(mainframe, y_lab= "sleep"){
  for (i in c("race", "sex", "occupation", "year", "day_of_week", "holiday")){
    plot <- ggplot(mainframe, aes_string(x = i, y = y_lab, fill = "sex")) +
      geom_boxplot() +
      labs(title = paste("Boxplot of", y_lab, "on", i),
           x = i,
           y = y_lab) +
      theme(plot.title = element_text(hjust = 0.5)) +
      theme(aspect.ratio = 3/5)
    
    # Print the plot
    print(plot)
  }
}
density_plotter_1 <- function(mainframe){
  for (i in c("sleep", "wage", "lwage", "sunset")){
    ggplot(mainframe, aes_string(x = i)) +
    geom_histogram(aes(y = after_stat(density)), fill = "lightblue", color = "black", bins = 30) +
    geom_density(color = "darkred") +
    labs(title = paste("Histogram of", i) ,
         x = i,
         y = "Density") +
    theme(plot.title = element_text(hjust = 0.5))
  }
}
density_plotter_2 <- function(mainframe){
  for (i in c("sleep", "earnings", "learnings", "sunset")){
    plot <- ggplot(mainframe, aes_string(x = i)) +
      geom_histogram(aes(y = after_stat(density)), fill = "lightblue", color = "black", bins = 30) +
      geom_density(color = "darkred") +
      labs(title = paste("Histogram of", i) ,
           x = i,
           y = "Density") +
      theme(plot.title = element_text(hjust = 0.5))
    print(plot)
  }
}
###############################
# LOADING DATASET
load("E:/Econometrics_Project_059/ec226-group059_2.RData")

dataframe_1 <- mainframe_cleaner(mainframe, sleep_range = c(2, 16), age_range = c(15, 85), income_range = c(0.1, 0.9), trunc_race = TRUE, earning_variable = FALSE)
dataframe_2 <- mainframe_cleaner(mainframe, sleep_range = c(2, 16), age_range = c(15, 85), income_range = c(0.1, 0.9), trunc_race = TRUE, earning_variable = TRUE)

#removing mainframe for efficiency
rm( mainframe)

# Detaching library(suncalc) to import updated data.table for library(modelsummary)
detach("package:suncalc", unload=TRUE)
# install.packages('data.table')
library(modelsummary)

# Summmary Statistics
datasummary_skim(dataframe_1, type = "numeric")
datasummary_skim(dataframe_2, type = "numeric")
datasummary_skim(dataframe_1, type = "categorical")
datasummary_skim(dataframe_2, type = "categorical")
density_plotter_2(dataframe_2)
categorical_plotter(dataframe_2, y_lab= "learnings")
categorical_plotter(dataframe_2)

#################################
# Run the regression models on Wage
FSLS_wage <- lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1, weights = weights)
TSLS_wage <- lm(formula = lwage ~ sunset+ county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1, weights = weights)
IV_weighted_wage <- ivreg(formula = lwage ~ sleep + county + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                       sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1,weights = weights)

# Run the regression models on earnings
FSLS_earnings <- lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2, weights = weights)
TSLS_earnings <- lm(formula = learnings ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2, weights = weights)
IV_weighted_earnings <- ivreg(formula = learnings ~ sleep + county + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                            sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2,weights = weights)

# Create a modelsummary table
summary_table <- list(
  "(1) First Stage" = FSLS_wage,
  "(1) Reduced Form" = TSLS_wage,
  "(1) IV" = IV_weighted_wage,
  "(2) First Stage" = FSLS_earnings,
  "(2) Reduced Form" = TSLS_earnings,
  "(2) IV" = IV_weighted_earnings
)

# Specify which coefficients to display
coef_map <- list(
  "sunset" = "sunset",
  "sleep" = "sleep"
)

# Generate the summary table
modelsummary(summary_table, coef_map = coef_map, vcov = "robust", stars = TRUE)

# Running Significance tests using Chisq due to the presence of non-normal residuals as seen below:
linearHypothesis(FSLS_wage, hypothesis.matrix = c("sunset = 0"), test = "Chisq")
linearHypothesis(FSLS_earnings, hypothesis.matrix = c("sunset = 0"), test = "Chisq")
linearHypothesis(TSLS_wage, hypothesis.matrix = c("sunset = 0"), test = "Chisq")
linearHypothesis(TSLS_earnings, hypothesis.matrix = c("sunset = 0"), test = "Chisq")
linearHypothesis(IV_weighted_wage, hypothesis.matrix = c("sleep = 0"), test = "Chisq")
linearHypothesis(IV_weighted_earnings, hypothesis.matrix = c("sleep = 0"), test = "Chisq")

# Pass the modified column to the modelplot function
modelplot(summary_table, coef_map = coef_map)


################################
# DIAGNOSTICS
# BREUSCH-PAGAN HETEROSKEDASTICITY TEST :

bptest_list_weighted = list(
  "(1)" = bptest(FSLS_earnings), 
  "(2)" = bptest(TSLS_earnings),
  "(3)" = bptest(FSLS_wage),
  "(4)" = bptest(TSLS_wage),
  "(5)" = bptest(IV_weighted_earnings),
  "(6)" = bptest(IV_weighted_wage)
)
print(bptest_list_weighted)

bptest_list_unweighted <- list(
  "(1)" = bptest(lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2)) ,
  "(2)" = bptest(lm(formula = learnings ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2)),
  "(3)" = bptest(lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1)),
  "(4)" = bptest(lm(formula = lwage ~ sunset+ county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1)),
  "(5)" = bptest(ivreg(formula = learnings ~ sleep + county + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                         sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2)),
  "(6)" = bptest(ivreg(formula = lwage ~ sleep + county + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                         sunset + county + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1))
)
print(bptest_list_unweighted)


# RESET TEST
RESET <-list(
  "(1)" = reset(FSLS_earnings),
  "(2)" = reset(TSLS_earnings),
  "(3)" = reset(FSLS_wage),
  "(4)" = reset(TSLS_wage),
  "(5)" = reset(IV_weighted_earnings),
  "(6)" = reset(IV_weighted_wage)
  )
print(RESET)
# JARQUE-BERA TEST OF NORMALITY:
jb_test <- list(
  "(1)" = jarque.bera.test(FSLS_earnings$residuals),
  "(2)" = jarque.bera.test(TSLS_earnings$residuals),
  "(3)" = jarque.bera.test(FSLS_wage$residuals),
  "(4)" = jarque.bera.test(TSLS_wage$residuals),
  "(5)" = jarque.bera.test(IV_weighted_earnings$residuals),
  "(6)" = jarque.bera.test(IV_weighted_wage$residuals)
  )
print(jb_test)

# CONTROL VARIATIONS:
specification_1 <- list(
  "IE Only" = lm(formula = sleep ~ sunset + race + age + agesq + sex + occupation, data = dataframe_2, weights = weights),
  "TE Only" = lm(formula = sleep ~ sunset + holiday + day_of_week + year, data = dataframe_2, weights = weights),
  "LE Only" = lm(formula = sleep ~ sunset + county, data = dataframe_2, weights = weights),
  "IE+TE" = lm(formula = sleep ~ sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2, weights = weights),
  "IE+LE" = lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation, data = dataframe_2, weights = weights),
  "TE+LE" = lm(formula = sleep ~ sunset + county + holiday + day_of_week + year, data= dataframe_2, weights = weights)
)
modelsummary(specification_1, coef_map = coef_map, vcov = "robust", stars = TRUE)

specification_2 <- list(
  "IE Only" = lm(formula = learnings ~ sunset + race + age + agesq + sex + occupation, data = dataframe_2, weights = weights),
  "TE Only" = lm(formula = learnings ~ sunset + holiday + day_of_week + year, data = dataframe_2, weights = weights),
  "LE Only" = lm(formula = learnings ~ sunset + county, data = dataframe_2, weights = weights),
  "IE+TE" = lm(formula = learnings ~ sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2, weights = weights),
  "IE+LE" = lm(formula = learnings ~ sunset + county + race + age + agesq + sex + occupation, data = dataframe_2, weights = weights),
  "TE+LE" = lm(formula = learnings ~ sunset + county + holiday + day_of_week + year, data = dataframe_2, weights= weights)
)
modelsummary(specification_2, coef_map = coef_map, vcov = "robust", stars = TRUE)

specification_3 <- list(
  "IE Only" = lm(formula = sleep ~ sunset + race + age + agesq + sex + occupation, data = dataframe_1, weights = weights),
  "TE Only" = lm(formula = sleep ~ sunset + holiday + day_of_week + year, data = dataframe_1, weights = weights),
  "LE Only" = lm(formula = sleep ~ sunset + county, data = dataframe_1, weights = weights),
  "IE+TE" = lm(formula = sleep ~ sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1, weights = weights),
  "IE+LE" = lm(formula = sleep ~ sunset + county + race + age + agesq + sex + occupation, data = dataframe_1, weights = weights),
  "TE+LE" = lm(formula = sleep ~ sunset + county + holiday + day_of_week + year, data= dataframe_1, weights = weights)
)
modelsummary(specification_3, coef_map = coef_map, vcov = "robust", stars = TRUE)

specification_4 <- list(
  "IE Only" = lm(formula = lwage ~ sunset + race + age + agesq + sex + occupation, data = dataframe_1, weights = weights),
  "TE Only" = lm(formula = lwage ~ sunset + holiday + day_of_week + year, data = dataframe_1, weights = weights),
  "LE Only" = lm(formula = lwage ~ sunset + county, data = dataframe_1, weights = weights),
  "IE+TE" = lm(formula = lwage ~ sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1, weights = weights),
  "IE+LE" = lm(formula = lwage ~ sunset + county + race + age + agesq + sex + occupation, data = dataframe_1, weights = weights),
  "TE+LE" = lm(formula = lwage ~ sunset + county + holiday + day_of_week + year, data = dataframe_1, weights = weights)
)
modelsummary(specification_4, coef_map = coef_map, vcov = "robust", stars = TRUE)

specification_5 <- list(
  "IE Only" = ivreg(formula = learnings ~ sleep + race + age + agesq + sex + occupation |
                    sunset + county + race + age + agesq + sex + occupation, data = dataframe_2,weights = weights),
  "TE Only" = ivreg(formula = learnings ~ sleep + holiday + day_of_week + year |
                              sunset + holiday + day_of_week + year, data = dataframe_2,weights = weights),
  "LE Only" = ivreg(formula = learnings ~ sleep + county | sunset + county, data = dataframe_2,weights = weights),
  "IE+TE" = ivreg(formula = learnings ~ sleep + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                    sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_2,weights = weights),
  "IE+LE" = ivreg(formula = learnings ~ sleep + county + race + age + agesq + sex + occupation |
                    sunset + county + race + age + agesq + sex + occupation, data = dataframe_2,weights = weights),
  "TE+LE" = ivreg(formula = learnings ~ sleep + county + holiday + day_of_week + year | sunset + county + holiday + day_of_week + year, data = dataframe_2, weights= weights)
)
modelsummary(specification_5, coef_map = coef_map, vcov = "robust", stars = TRUE)

specification_6 <- list(
  "IE Only" = ivreg(formula = lwage ~ sleep + race + age + agesq + sex + occupation |
                      sunset + county + race + age + agesq + sex + occupation, data = dataframe_1,weights = weights),
  "TE Only" = ivreg(formula = lwage ~ sleep + holiday + day_of_week + year |
                      sunset + holiday + day_of_week + year, data = dataframe_1,weights = weights),
  "LE Only" = ivreg(formula = lwage ~ sleep + county | sunset + county, data = dataframe_1,weights = weights),
  "IE+TE" = ivreg(formula = lwage ~ sleep + race + age + agesq + sex + occupation + holiday + day_of_week + year |
                    sunset + race + age + agesq + sex + occupation + holiday + day_of_week + year, data = dataframe_1,weights = weights),
  "IE+LE" = ivreg(formula = lwage ~ sleep + county + race + age + agesq + sex + occupation |
                    sunset + county + race + age + agesq + sex + occupation, data = dataframe_1,weights = weights),
  "TE+LE" = ivreg(formula = lwage ~ sleep + county +  holiday + day_of_week + year |
                    sunset + county + holiday + day_of_week + year, data = dataframe_1,weights = weights)
)
modelsummary(specification_6, coef_map = coef_map, vcov = "robust", stars = TRUE)

######################
# MULTI-COLLINEARITY:
corr_df <- subset(dataframe_1, select = c("lwage", "sleep", "age", "sunset", "race", "sex", "occupation", "county", "day_of_week", "year", "holiday"))
corr_df <- sapply(corr_df, as.numeric)
corr_df <- cor(corr_df)
corr_df <- melt(corr_df)

# Plot heatmap
ggplot(corr_df, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Correlation") +
  geom_text(aes(Var1, Var2, label = round(value, 2)), 
            color = "black", size = 3) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 12, hjust = 1),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        legend.position = "right") +
  labs(title = "Correlation Heatmap",
       subtitle = "Correlation between variables")+
  theme(plot.title = element_text(hjust = 0.5))+
  theme(plot.subtitle = element_text(hjust = 0.5))

corr_df_2 <- subset(dataframe_2, select = c("learnings", "sleep", "age", "sunset", "race", "sex", "occupation", "county", "day_of_week", "year", "holiday"))
corr_df_2 <- sapply(corr_df_2, as.numeric)
corr_df_2 <- cor(corr_df_2)
corr_df_2 <- melt(corr_df_2)

# Plot heatmap
ggplot(corr_df_2, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Correlation") +
  geom_text(aes(Var1, Var2, label = round(value, 2)), 
            color = "black", size = 3) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 12, hjust = 1),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        legend.position = "right") +
  labs(title = "Correlation Heatmap",
       subtitle = "Correlation between variables")+
  theme(plot.title = element_text(hjust = 0.5))+
  theme(plot.subtitle = element_text(hjust = 0.5))


