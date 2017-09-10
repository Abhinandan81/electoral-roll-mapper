library(shiny)
library(shinythemes)
library(shinyjs)

shinyUI(fluidPage(theme = shinytheme("cerulean"),
                  
                  # HTML head section to import css and JS as needed
                  tags$head(
                    includeCSS("www/custom_style.css"),
                    tags$link(rel = "stylesheet", type = "text/css", href = "//maxcdn.bootstrapcdn.com/font-awesome/4.2.0/css/font-awesome.min.css")
                    ),
                  
                  useShinyjs(),  # Set up shinyjs
                  
                  navbarPage(title = "Electoral Roll Mapper", fluid = TRUE, theme = ),
                  fluidRow(
                    column(6,
                           fluidRow(
                             column(12,
                                    uiOutput("areas")
                             )
                           ),
                           fluidRow(
                             column(12,
                                    div( id = "image_div",
                                      imageOutput("rough_area_image")
                                    )
                             )
                           )
                    ),
                    column(6,
                           fluidRow(
                             column(12,
                                    textInput(inputId = "area_input", label = "", value = "", placeholder = "Search for area")
                             )
                           ),
                           fluidRow(
                             column(12,
                                    div( id = "map"
                                    )
                             )
                           ),
                           fluidRow(
                             column(12,
                                    div( id = "save_button_div",
                                         actionButton(inputId = "save_cordinates", label = "Save Coordinates", class = "btn-success")
                                    )
                             )
                           )
                    )
                  ),
                  
                  # ADDING GOOGLE API SCRIPTS
                  HTML('
                       <script type="text/javascript" src="custom_js.js"></script>
                       <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyD_TSprWOtIlrzkAgJ7kW4LJj_Z2CoeGHY&libraries=places&callback=initAutocomplete"
                       async defer></script>
                       '
                       )
                  
)) 