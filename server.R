library(shiny)
library(readxl)
library(DBI)
library(pool)
library(RMySQL)
library(dplyr)

#************************ START: DATABASE CONFIGURATION **********************#

pool <- dbPool(
  drv = RMySQL::MySQL(),
  dbname = "electoral_roll_mapper",
  host = "localhost",
  user = "root",
  password = ""
)

# table which is having the existing area and map image mapping  
table_area_details <- "area_details"

#************************ END: DATABASE CONFIGURATION ************************#

#****************** START: PERSISTING AREA DETAILS TO DATABASE ***************#

persistAreaDatails <- function(connection, data, table_name) {
  dbWriteTable(
    connection,
    value = data,
    name = table_name,
    row.names = FALSE,
    append = TRUE
  )
}
#****************** END: PERSISTING AREA DETAILS TO DATABASE ***************#


#************************ START: BOOTSTRAPPING AREA DETAILS *******************#

bootstrapDatabaseWithUnmappedAreaDetails <- function(){
  # reading the area details xlsx file
  area_details <- read_excel("reference/area_details.xlsx", sheet = 1, col_names = TRUE)
  
  #------------------ START: VALIDATING AND FILTERING INPUT DATA ------------------#
  
  # fetching required columns. Ignore other fields if any
  area_details <- select(area_details, area_name, image_path)
    
  # removing the rows with NA - missing details
  area_details <- area_details[complete.cases(area_details), ]
  
  # removing duplicate records from the dataset
  area_details <- unique(area_details[ ,1:2])
  
  # removing leading and trailing whitespaces from the contents
  area_details$area_name <- trimws(area_details$area_name)
  area_details$image_path <- trimws(area_details$image_path)
  
  #------------------ END: VALIDATING AND FILTERING INPUT DATA   ------------------#
  
  # Persisting the area and it's associated details
  persistAreaDatails(pool, area_details, table_area_details)
  
}

#************************ END: BOOTSTRAPPING AREA DETAILS *******************#


# loading unmapped area details
unmapped_area_details <- bootstrapDatabaseWithUnmappedAreaDetails()

shinyServer(function(input, output){
  
  
  
  # output$rough_image <- renderText({
  #   print("-------- unmapped_area_details ----------")
  #   print(unmapped_area_details)
  #   
  #   source_image <- "https://drive.google.com/file/d/0B8V6CQ17I6WrX1pHZVhVRzlweU0/view?usp=sharing"
  #   
  #   print("source_image")
  #   print(source_image)
  #   
  #  image_vector <- c(
  #    
  #     '<img src="', source_image, '">'
  #   )
  #  
  #  print("======= image_vector ====")
  #  print(image_vector)
  #  
  #  return(image_vector)
  # })
})