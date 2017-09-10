
 //**************** START : GOOGLE MAP INITILIAZATION ****************//

 //**************** END : GOOGLE MAP INITILIAZATION ****************//
 
 function initAutocomplete() {
        var map = new google.maps.Map(document.getElementById('map'), {
          center: {lat: 18.5204, lng: 73.8567},
          zoom: 13,
          mapTypeId: 'roadmap'
        });

        // Create the search box and link it to the UI element.
        var input = document.getElementById('area_input');
        var searchBox = new google.maps.places.SearchBox(input);
        //map.controls[google.maps.ControlPosition.TOP_CENTER].push(input);

        // Bias the SearchBox results towards current map's viewport.
        map.addListener('bounds_changed', function() {
          searchBox.setBounds(map.getBounds());
        });

        var markers = [];
        // Listen for the event fired when the user selects a prediction and retrieve
        // more details for that place.
        searchBox.addListener('places_changed', function() {
          var places = searchBox.getPlaces();

          if (places.length == 0) {
            return;
          }

          // Clear out the old markers.
          markers.forEach(function(marker) {
            marker.setMap(null);
          });
          markers = [];

          // For each place, get the icon, name and location.
          var bounds = new google.maps.LatLngBounds();
          places.forEach(function(place) {
            if (!place.geometry) {
              console.log("Returned place contains no geometry");
              return;
            }
            
            var icon = {
              url: place.icon,
              size: new google.maps.Size(71, 71),
              origin: new google.maps.Point(0, 0),
              anchor: new google.maps.Point(17, 34),
              scaledSize: new google.maps.Size(25, 25)
            };
          
            var marker_coordinates = [];
           
            // Create a marker for each place.
            var marker = new google.maps.Marker({
              map: map,
              title: place.name,
              position: place.geometry.location,
              draggable:true,
              animation: google.maps.Animation.DROP,
              scaledSize : new google.maps.Size(25, 25),
              size: new google.maps.Size(71, 71),
              origin: new google.maps.Point(0, 0),
              anchor: new google.maps.Point(17, 34)
            });

            if (place.geometry.viewport) {
              // Only geocodes have viewport.
              bounds.union(place.geometry.viewport);
            } else {
              bounds.extend(place.geometry.location);
            }
            
            // INITIAL COORDINATES: getting the cordinates on selecteing the place from search bar
            marker_coordinates = {latitude : marker.getPosition().lat(), longitude :  marker.getPosition().lng()};
                
            // Capturing the change in marker position : It acts as a reactive input value  
            Shiny.onInputChange("area_coordinates", marker_coordinates);

            // Listening to the change in marker position
            google.maps.event.addListener(marker, 'dragend', function(a) {
              // GETTING CHANGED COORDINATES: getting the cordinates on selecteing the place from search bar
              marker_coordinates = {latitude : marker.getPosition().lat(), longitude :  marker.getPosition().lng()};
              
              // Capturing the change in marker position : It acts as a reactive input value
              Shiny.onInputChange("area_coordinates", marker_coordinates);
            });

          });
          map.fitBounds(bounds);
        });
        
        
 }
