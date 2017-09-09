library(shiny)
library(shinythemes)

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
                           "main"
                    )
                  )
                  
)) 