#************************ Shiny Application: Electoral Roll Mapper **********************#
#
# Author: Abhinandan Satpute
# R version 3.3.3 (2017-03-06)
# Platform: x86_64-pc-linux-gnu (64-bit)
# Shiny version: ‘1.0.0’
# mysql 5.5
#
#****************************************************************************************#


library(shiny)
library(shinyjs)
library(readxl)
library(dplyr)
library(DBI)
library(pool)
library(RMySQL)

#************************ START: DATABASE CONFIGURATION / DETAILS **********************#

pool <- dbPool(
  drv = RMySQL::MySQL(),
  dbname = "electoral_roll_mapper",
  host = "localhost",
  user = "root",
  password = "" # make sure that you are adding password while deploying application to staging / prod
)

# table which is having the existing area and map image mapping
table_area_details <- "area_details"

#************************ END: DATABASE CONFIGURATION / DETAILS ************************#



#************************ START: BOOTSTRAPPING AREA DETAILS ****************************#
# This section will-
# 1. Read the xlsx file stored on local machine
# 2. Validate file content
# 3. Upsert the data in the mysql database
#***************************************************************************************# 

#----------- START: XLSX FILE READING, DATA VALIDATION  ---------#
bootstrapDatabaseWithUnmappedAreaDetails <- function() {
  # reading the area details xlsx file
  area_details <-
    read_excel("reference/area_details.xlsx",
               sheet = 1,
               col_names = TRUE)
  
  #START: VALIDATING AND FILTERING INPUT DATA
  
  # fetching required columns. Ignore other fields if any
  area_details <- select(area_details, area_name, image_path)
  
  # removing the rows with NA - missing details
  area_details <- area_details[complete.cases(area_details),]
  
  # removing duplicate records from the dataset
  area_details <- unique(area_details[, 1:2])
  
  # removing leading and trailing whitespaces from the contents
  area_details$area_name <- trimws(area_details$area_name)
  area_details$image_path <- trimws(area_details$image_path)
  
  #END: VALIDATING AND FILTERING INPUT DATA
  
  # Persisting the area and it's associated details
  persistAreaDatails(area_details, table_area_details)
  
}

#------------- START: PERSISTING AREA DETAILS TO DATABASE  ---------#
persistAreaDatails <- function(data, table_name) {
  conn <- poolCheckout(pool)
  
  dbWriteTable(
    conn,
    value = data,
    name = table_name,
    row.names = FALSE,
    append = TRUE
  )
  
  poolReturn(conn)
}


# CALL TO LOAD AREA DETAILS INTO THE DATABASE
unmapped_area_details <- bootstrapDatabaseWithUnmappedAreaDetails()

#************************ END: BOOTSTRAPPING AREA DETAILS *******************#


shinyServer(function(input, output, session) {
  
  reactiveValues <- reactiveValues()
  
  #************      START: DATABASE CRUD OPERATIONS SECTION           **************#
  
  #------------  FETCHING ALL AREAS TO BE MAPPED FROM DATABASE ------------ #
  fetchAllAreasDetailsFromDatabase <- function(table_name) {
    conn <- poolCheckout(pool)
    
    #query to fetch area_name from table
    query <- paste("SELECT * FROM ", table_name, ";", sep = " ")
    
    area_details <-
      dbGetQuery(conn, query)
    
    poolReturn(conn)
    
    if (is.null(area_details))
      return(NULL)
    
    return(area_details)
  }

  
  #----------- FETCHING IMAGE PATH FOR GIVEN AREA FROM DATABASE ------------ #
  fetchSelectedAreaDetailsFromDatabase <-
    function(area_name, table_name) {
      conn <- poolCheckout(pool)
      
      #query to fetch image_path from table
      query <-
        paste("SELECT * FROM ",
              table_name,
              " where area_name = '",
              area_name,
              "';",
              sep = "")
      
      area_details <-
        dbGetQuery(conn, query)
      
      poolReturn(conn)
      
      if (is.null(area_details))
        return(NULL)
      
      return(area_details)
    }

  #------------ UPDATE AREA - CORDINATE MAPPING  ------------ #
  updateAreaCoordinates <-
    function(area_name, coordinates, table_name) {
      #query to update the co-ordinates for the given area
      query <-
        paste(
          "UPDATE ",
          table_name,
          " SET latitude = '",
          coordinates$latitude,
          "', ",
          "longitude = '",
          coordinates$longitude,
          "'",
          ", address = '",
          coordinates$formatted_address,
          "' ",
          ", mapping_status = 1" ,
          " WHERE area_name = '",
          area_name,
          "';",
          sep = ""
        )
      
      conn <- poolCheckout(pool)
      
      coordinate_update_status <-
        dbSendQuery(conn, query)
      
      poolReturn(conn)
    }
  
  #************      END: DATABASE CRUD OPERATIONS SECTION           **************#
  
  
  #************      START: RENDERING OUTPUT TO THE UI SECTION        *************#
  
  #--------------      RENDERING LIST OF AREAS:         ---------------#
  #fetching list of areas to map - populating and rendering selctinput with area names
  output$areas <-  renderUI({
    area_names <- NULL
    area_details <-
      fetchAllAreasDetailsFromDatabase(table_area_details)
    
    if (!is.null(area_details))
      area_names <- sort(area_details$area_name)
    
    selectInput(
      inputId = "area_names",
      label = "Select Area",
      choices = c("", area_names),
      selected = NULL,
      multiple = FALSE,
      selectize = TRUE,
      width = NULL,
      size = NULL
    )
  })
  
  #------------ RENDERING AREA - COORDINATE MAPPING STATUS ------------ #
  output$area_mapping_message <-  renderUI({
    
    req(input$area_names)
    
    mapping_message <-
      "Status: Not mapped"
    
    area_details <- fetchSelectedAreaDetailsFromDatabase(input$area_names, table_area_details)
    
    if (area_details$mapping_status == 1) {
      mapping_message <-
        "Status: Mapped"
    }
    
    if(!is.null(reactiveValues$update_area_coordinates_status)){
      if (area_details$mapping_status == 1) {
        mapping_message <-
          "Status: Mapped"
      }
    }
    
    span(mapping_message)
  })
  
  #------------ RENDERING MARKER DETAILS - LAT, LNG AND ADDRESS  ------ #
  output$show_marker_location <- renderUI({
    req(input$area_coordinates)
    
    coordinates <- input$area_coordinates
    
    div(
      tags$label("Lattitude :"),
      span(coordinates$latitude),
      tags$label(",     Longitude :"),
      span(coordinates$longitude),
      tags$br(),
      tags$label("Address :"),
      span(coordinates$formatted_address)
    )
  })
  
  
  #------------ RENDERING AREA - COORDINATE MAPPING DATATABLE  ------ #
  output$area_mapping_table <- renderDataTable({
    req(input$tabs)
    
    if (input$tabs == "Mapping Details") {
      area_details <- fetchAllAreasDetailsFromDatabase(table_area_details)
      
      if (is.null(area_details))
        return(NULL)
      
      area_details <-
        select(area_details,-id,-image_path,-mapping_status)
      
      colnames(area_details) <-
        c("Area Name", "Latitude", "longitude", "Address")
      return(area_details)
    }
  }, options = list(columnDefs = list(list(
    targets = c(0, 1, 2, 3), searchable = FALSE
  )),
  pageLength = 10))
  
  
  
  #---------- RENDERING IMAGE: rendering image for selcted area ----------#
  output$rough_area_image <- renderImage({
    req(input$area_names)
    
    image_path <- NULL
    
    if(input$area_names == ""){
      image_path <- "reference/no_image.jpg"
    }else{
      area_details <- fetchSelectedAreaDetailsFromDatabase(input$area_names, table_area_details)
      
      if (is.null(area_details)) {
        image_path <- "reference/default_image.jpg"
        
      } else if (is.null(area_details$image_path)) {
        # If no image found for slected area, show default image
        image_path <- "reference/default_image.jpg"
      } else{
        image_path <- area_details$image_path
      }
      
    }
    
    return(list(src = image_path,
                alt = toupper(input$area_names)))
  }, deleteFile = FALSE)
  
  
  #************      END: RENDERING OUTPUT TO THE UI SECTION        *************#
  
  # # ----- FETCHING AREA DETAILS ON SELETING AREA NAME ------#
  # fetchSelectedAreaDetails <- reactive({
  #   req(input$area_names)
  #   
  #   area_details <-
  #     fetchSelectedAreaDetailsFromDatabase(input$area_names, table_area_details)
  #   
  #   return(area_details)
  # })
  
  
  
  # observing the state of area_coordinates and accordingly enabling / disabling the save button
  observe({
    if (is.null(input$area_coordinates) | is.null(input$area_names)) {
      shinyjs::disable(id = "save_cordinates")
    } else {
      if (input$area_names != "") {
        shinyjs::enable(id = "save_cordinates")
      }
    }
  })
  
  
  # START: PERSISTING CO-ORDINATES CONFIRMATION MODAL RENDERING
  observeEvent(input$save_cordinates, {
    req(input$area_names,
        input$area_coordinates,
        input$save_cordinates)
    
    showModal(
      modalDialog(
        title = "Area and Coordinate mapping confirmation",
        "Are you sure about updating the area and coordinates apping?",
        easyClose = FALSE,
        footer =  tagList(
          actionButton("persist_cordinates", "Yes", class = "btn-success"),
          modalButton("Cancel")
        ),
        fade = TRUE
      )
    )
  })
  
  #------ START: PERSISTING CO-ORDINATES ON CALL TO PERSIST --------#
  observeEvent(input$persist_cordinates, {
    req(input$area_names,
        input$area_coordinates,
        input$persist_cordinates)
    
    # call to update-coordinate of the selected area
    reactiveValues$update_area_coordinates_status <- updateAreaCoordinates(input$area_names,
                          input$area_coordinates,
                          table_area_details)
    
    # removing the mapping modal
    removeModal()
    
    showNotification(
      paste (
        "Co-ordinates for",
        input$area_names,
        "has been stored / updated successfully",
        sep = " "
      ),
      duration = 10,
      closeButton = TRUE,
      type = "message"
    )
  })
  
})