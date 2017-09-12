# Electoral Roll Mapper

# Motivation:
Providing a platform to a user to feed area details along with rough paper map image and enabling the user correlating the image with the real world coordinates with the help of Google Map and it's different API's.

### Platfrom Details:
    R version 3.3.3 (2017-03-06)
    Platform: x86_64-pc-linux-gnu (64-bit)
    Shiny version: ‘1.0.0’
    mysql 5.5
    Designed on Ubuntu 14.04

### Libraries / API used:
* shiny
* shinyjs
* readxl
* dplyr
* DBI
* pool
* RMySQL
* shinythemes
* shinyjs
* Google map JS 
* Google map API
* Google map geocoding API

### Database schema details
    Create database electoral_roll_mapper;

Table structure and creation

    Create table area_details(id integer primary key AUTO_INCREMENT, 
                          area_name varchar(100) NOT NULL,
                          image_path varchar(200) not null,
                          latitude varchar(50),
                          longitude varchar(50),
                          address varchar(200),
                          mapping_status BOOLEAN DEFAULT 0,
                          UNIQUE(area_name));
