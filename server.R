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
  fetchAllAreasDetailsFromDatabase <- function(table_name){
    
    conn <- poolCheckout(pool);
    
    #query to fetch area_name from table
    query <- paste("SELECT * FROM ", table_name, ";", sep = " ")
    
    area_details <-
      dbGetQuery(conn, query)
    
    poolReturn(conn)
    
  
    if(is.null(area_details))
      return(NULL)
    
    return(area_details)
  }
  #********* END: FETCHING ALL AREAS TO BE MAPPED FROM DATABASE ************#
  
  
  #******* START: FETCHING IMAGE PATH FOR GIVEN AREA FROM DATABASE *********#
  fetchSelectedAreaDetailsFromDatabase <- function(area_name, table_name){
    
    conn <- poolCheckout(pool);
    
    #query to fetch image_path from table
    query <- paste("SELECT * FROM ", table_name, " where area_name = '", area_name, "';", sep = "")
    
    area_details <-
      dbGetQuery(conn, query)
    
    poolReturn(conn)
    
    
    if(is.null(area_details))
      return(NULL)
    
    return(area_details)
  }
  #******** END: FETCHING IMAGE PATH FOR GIVEN AREA FROM DATABASE *********#
  
  updateAreaCoordinates <- function(area_name, coordinates, table_name) {
    #query to update the co-ordinates for the given area
    query <- paste("UPDATE ", table_name, " SET latitude = '", coordinates$latitude,"', ", 
                    "longitude = '", coordinates$longitude,"'", ", address = '", coordinates$formatted_address, "' ",", mapping_status = 1" ," WHERE area_name = '", area_name, "';", sep = "")
    
    conn <- poolCheckout(pool)
    
    coordinate_update_status <-
      dbSendQuery(conn, query)
    
    poolReturn(conn)
  }
  
  
  # RENDERING LIST OF AREAS: fetching list of areas to map - populating and rendering selctinput with area names
  output$areas <-  renderUI({
    area_names <- NULL
    area_details <- fetchAllAreasDetailsFromDatabase(table_area_details)
    
    if(!is.null(area_details))
      area_names <- sort(area_details$area_name)
    
    selectInput(inputId = "area_names", label = "Select Area", choices = c("", area_names), selected = NULL, 
                multiple = FALSE, selectize = TRUE, width = NULL, size = NULL)
  })
  
  output$area_mapping_table <- renderDataTable({
    
    req(input$tabs)
    
    if(input$tabs == "Mapping Details"){
      area_details <- fetchAllAreasDetailsFromDatabase(table_area_details)
      
      if(is.null(area_details))
        return(NULL)
      
      area_details <- select(area_details, -id, -image_path, -mapping_status)
      
      colnames(area_details) <- c("Area Name", "Latitude", "longitude", "Address")
      return(area_details)
    }
  }, options = list(columnDefs = list(list(targets = c(0, 1, 2, 3), searchable = FALSE)),
                    pageLength = 10))
  
  fetchSelectedAreaDetails <- reactive({
    req(input$area_names)
    
    area_details <- fetchSelectedAreaDetailsFromDatabase(input$area_names, table_area_details)
    
    return(area_details)
  })
  
  # RENDERING IMAGE: rendering image for selcted area
  output$rough_area_image <- renderImage({
    req(input$area_names)
    
    image_path <- NULL

    area_details <- fetchSelectedAreaDetails()
    
    if(is.null(area_details)){
      image_path <- "reference/default_image.png"
      
    }else if(is.null(area_details$image_path)){
      # If no image found for slected area, show default image
      image_path <- "reference/default_image.png"
    }else{
      image_path <- area_details$image_path
    }

    return(list(src = image_path,
                alt = toupper(input$area_names)))
  }, deleteFile = FALSE)
  
  # RENDERING LIST OF AREAS: fetching list of areas to map - populating and rendering selctinput with area names
  output$area_mapping_message <-  renderUI({
    
    area_details <- fetchSelectedAreaDetails()
    mapping_message <- "Selected area doesn't have coordinate mapping."
    
    if(area_details$mapping_status == 1){
      mapping_message <- "Selected area is already mapped with coordinates."
    }
    
    span(mapping_message)
  })
  
  output$show_marker_location <- renderUI({
    req(input$area_coordinates)
    
    coordinates <- input$area_coordinates

    div( tags$label("Lattitude :"), span(coordinates$latitude),
          tags$label(",     Longitude :"), span(coordinates$longitude), tags$br(),
          tags$label("Address :"), span(coordinates$formatted_address))
  })
  
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
      "Are you sure about updating the Area and Coordinate Mapping?",
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
                     duration = 10, closeButton = TRUE, type = "message")
    })
  

  
})