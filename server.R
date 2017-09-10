library(shiny)
library(shinyjs)
library(readxl)
library(dplyr)
library(DBI)
library(pool)
library(RMySQL)


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

persistAreaDatails <- function(data, table_name) {
  
  conn <- poolCheckout(pool);
  
  dbWriteTable(
    conn,
    value = data,
    name = table_name,
    row.names = FALSE,
    append = TRUE
  )
  
  poolReturn(conn)
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
  persistAreaDatails(area_details, table_area_details)
  
}

#************************ END: BOOTSTRAPPING AREA DETAILS *******************#


# loading unmapped area details
unmapped_area_details <- bootstrapDatabaseWithUnmappedAreaDetails()


shinyServer(function(input, output, session){
  
  #********* START: FETCHING ALL AREAS TO BE MAPPED FROM DATABASE ************#
  fetchAreasToBeMapped <- function(table_name){
    
    conn <- poolCheckout(pool);
    
    #query to fetch area_name from table
    query <- paste("SELECT area_name FROM ", table_name, ";", sep = " ")
    
    area_details <-
      dbGetQuery(conn, query)
    
    poolReturn(conn)
    
  
    if(is.null(area_details))
      return(NULL)
    
    return(area_details$area_name)
  }
  #********* END: FETCHING ALL AREAS TO BE MAPPED FROM DATABASE ************#
  
  
  #******* START: FETCHING IMAGE PATH FOR GIVEN AREA FROM DATABASE *********#
  fetchImagePathForGivenArea <- function(area_name, table_name){
    
    conn <- poolCheckout(pool);
    
    #query to fetch image_path from table
    query <- paste("SELECT image_path FROM ", table_name, " where area_name = '", area_name, "';", sep = "")
    
    image_details <-
      dbGetQuery(conn, query)
    
    poolReturn(conn)
    
    
    if(is.null(image_details))
      return(NULL)
    
    return(image_details$image_path)
  }
  #******** END: FETCHING IMAGE PATH FOR GIVEN AREA FROM DATABASE *********#
  
  updateAreaCoordinates <- function(area_name, coordinates, table_name) {
    #query to update the co-ordinates for the given area
    query <- paste("UPDATE ", table_name, " SET latitude = '", coordinates$latitude,"', ", 
                    "longitude = '", coordinates$longitude,"'", " WHERE area_name = '", area_name, "';", sep = "")
    
    conn <- poolCheckout(pool)
    
    coordinate_update_status <-
      dbSendQuery(conn, query)
    
    poolReturn(conn)
  }
  
  
  # RENDERING LIST OF AREAS: fetching list of areas to map - populating and rendering selctinput with area names
  output$areas <-  renderUI({
    
    area_names <- fetchAreasToBeMapped(table_area_details)
    
    selectInput(inputId = "area_names", label = "Select Area", choices = c("", area_names), selected = NULL, 
                multiple = FALSE, selectize = TRUE, width = NULL, size = NULL)
  })
  
  # RENDERING IMAGE: rendering image for selcted area
  output$rough_area_image <- renderImage({
    req(input$area_names)

    image_path <- fetchImagePathForGivenArea(input$area_names, table_area_details)

    # If no image found for slected area, show default image
    if(is.null(image_path))
      image_path <- "reference/default_image.png"

    return(list(src = image_path,
                alt = toupper(input$area_names)))
  }, deleteFile = FALSE)
  
  # observing the state of area_coordinates and accordingly enabling / disabling the save button
  observe({
  
    if(is.null(input$area_coordinates) | is.null(input$area_names)){
      shinyjs::disable(id = "save_cordinates")
    } else {
       if(input$area_names != ""){
         shinyjs::enable(id = "save_cordinates") 
       }
      }
  })
  
  # observe({
  #   if(is.null(input$area_names)){
  #     shinyjs::disable(id = "area_input")
  #   } else{
  #     shinyjs::enable(id = "area_input")
  #   }
  # })
  
  # START: PERSISTING CO-ORDINATES
  observeEvent(input$save_cordinates, {
    
    req(input$area_names, input$area_coordinates, input$save_cordinates)
    
    showModal(modalDialog(
      title = "Area and Coordinate mapping confirmation",
      "Are you sure about updating the Area and Coordinates Mapping?",
      easyClose = FALSE,
      footer =  tagList(
        actionButton("persist_cordinates", "Yes", class = "btn-success"),
        modalButton("Cancel")
      ),
      fade = TRUE
    ))
  })
  
  # START: PERSISTING CO-ORDINATES
  observeEvent(input$persist_cordinates, {

    req(input$area_names, input$area_coordinates, input$persist_cordinates)

    # call to update-coordinate of the selected area
    updateAreaCoordinates(input$area_names, input$area_coordinates, table_area_details)

    # removing the mapping modal
    removeModal()

    showNotification(paste ("Co-ordinates for", input$area_names, "has been stored / updated successfully", sep = " "),
                     duration = 20, closeButton = TRUE, type = "message")
    })
  

  
})