library(shiny)
library(shinythemes)
#library(leaflet)
library(shinyjs)

shinyUI(fluidPage(theme = shinytheme("cerulean"),
                  
                  # HTML head section to import css and JS as needed
                  tags$head(
                    includeCSS("www/custom_style.css")
                    ),
                  
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
                                    "search"
                             )
                           ),
                           fluidRow(
                             column(12,
                                    div( id = "map"
                                         #leafletOutput("map")
                                    )
                             )
                           )
                    )
                  ),
                  
                  # ADDING GOOGLE API SCRIPTS
                  HTML('
                       <script type="text/javascript" src="custom_js.js"></script>
                       <script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?key=AIzaSyD_TSprWOtIlrzkAgJ7kW4LJj_Z2CoeGHY&callback=initMap" async defer></script>'
                       )
                  
)) 