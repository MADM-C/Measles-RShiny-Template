# Function to create the proximity map module
# This function handles the interactive map, combining school and daycare facilities,
# overlaying religious centers, and analyzing nearby low-vaccine facilities.
# Parameters:
#   school_data: reactive expression returning school data
#   daycare_data: reactive expression returning daycare data  
#   county_map_data: reactive expression returning county boundary data
#   output: Shiny output object
#   input: Shiny input object
#   session: Shiny session object
# Returns: list of reactive values and functions for use by other modules
proximityMapServer <- function(school_data, daycare_data, county_map_data, output, input, session) {
  
  # Reactive expression to combine and clean facility data
  # Automatically updates when underlying school or daycare data changes
  combined_facilities <- reactive({
    tryCatch({
      df <- combineSchoolDaycareData(school_data(), daycare_data())
      if (!is.null(df) && nrow(df) > 0 && "geometry" %in% names(df)) {
        coords <- sf::st_coordinates(df$geometry)
        valid <- !is.na(coords[,1]) & !is.na(coords[,2])
        df <- df[valid, ]
      }
      df
    }, error = function(e) {
      warning(paste("Error combining data:", e$message))
      return(NULL)
    })
  })
  
  # Reactive values to store user interactions and analysis results
  values <- reactiveValues(
    clicked_point = NULL,                    # Stores last clicked map coordinates
    low_vaccine_facilities_data = NULL       # Stores facilities below vaccine threshold
  )
  
  # Convert search radius from miles to kilometers
  # Required because distance calculations use metric system
  radius_km <- reactive({
    req(input$radius_miles)
    input$radius_miles * 1.60934
  })
  
  # Get user-selected vaccine threshold percentage
  low_vaccine_threshold <- reactive({
    req(input$vaccine_threshold)
    input$vaccine_threshold
  })
  
  # Core function to analyze proximity and identify low-vaccine facilities
  # This function is called when user clicks map or selects a facility
  # Parameters:
  #   lat: latitude of search center
  #   lng: longitude of search center  
  #   popup_title: descriptive title for the search location marker
  # Note: Only schools and daycares are analyzed (religious centers excluded)
  analyze_proximity <- function(lat, lng, popup_title) {
    facilities <- combined_facilities()
    if (is.null(facilities) || nrow(facilities) == 0) return()
    
    values$clicked_point <- list(lat = lat, lng = lng)
    
    if ("geometry" %in% names(facilities)) {
      coords <- sf::st_coordinates(facilities$geometry)
      if (nrow(coords) > 0) {
        lat1_rad <- lat * pi / 180
        lng1_rad <- lng * pi / 180
        lat2_rad <- coords[,2] * pi / 180
        lng2_rad <- coords[,1] * pi / 180
        dlat <- lat2_rad - lat1_rad
        dlng <- lng2_rad - lng1_rad
        a <- sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlng/2)^2
        c <- 2 * atan2(sqrt(a), sqrt(1-a))
        distances_km <- 6371 * c
        nearby_facilities <- facilities[distances_km <= radius_km(), ]
      } else {
        nearby_facilities <- facilities[0, ]
      }
    } else {
      nearby_facilities <- facilities
    }
    
    if (nrow(nearby_facilities) > 0 && "full_vax_pct" %in% names(nearby_facilities)) {
      vax_numeric <- as.numeric(gsub("[^0-9.]", "", nearby_facilities$full_vax_pct))
      low_vaccine_facilities <- nearby_facilities[
        !is.na(vax_numeric) & vax_numeric < low_vaccine_threshold(), 
      ]
    } else {
      low_vaccine_facilities <- nearby_facilities[0, ]
    }
    
    values$low_vaccine_facilities_data <- low_vaccine_facilities
    
    # Add specific settings for proximity circle zoom in 
    zoom_level <- dplyr::case_when(
      radius_km() <= 0.1 ~ 19,
      radius_km() <= 0.2 ~ 17,
      radius_km() <= 0.5 ~ 16,
      radius_km() <= 1   ~ 15,
      radius_km() <= 2   ~ 14,
      radius_km() <= 5   ~ 13,
      radius_km() <= 10  ~ 12,
      TRUE               ~ 10
    )
    
    # Clear only specific elements
    leafletProxy("proximity_map", session) %>%
      removeMarker("search_center") %>%
      removeShape("search_radius") %>%
      clearGroup("highlighted_facilities") %>%
      setView(lng = lng, lat = lat, zoom = zoom_level) %>%
      addMarkers(
        lng = lng, lat = lat, layerId = "search_center",
        popup = paste(popup_title, "<br>Low-vaccine facilities:", nrow(low_vaccine_facilities))
      ) %>%
      addCircles(
        lng = lng, lat = lat, radius = radius_km() * 1000,
        layerId = "search_radius", color = "red", fillOpacity = 0.1
      )
    
    # Re-add all facility markers with tooltips to ensure they persist
    facilities <- combined_facilities()
    if (!is.null(facilities) && nrow(facilities) > 0 && "geometry" %in% names(facilities)) {
      coords <- sf::st_coordinates(facilities$geometry)
      if (nrow(coords) > 0) {
        leafletProxy("proximity_map", session) %>%
          clearGroup("School/Child Care Markers") %>%
          addCircleMarkers(
            lng = coords[,1], lat = coords[,2],
            radius = 3, color = "gray", fillColor = "gray", fillOpacity = 0.7,
            group = "School/Child Care Markers",
            label = lapply(paste0(facilities$facility_name, " - ", facilities$full_vax_pct), HTML),
            labelOptions = labelOptions(noHide = FALSE, textOnly = FALSE, direction = "auto")
          )
      }
    }
    
    # Add highlighted low-vaccine facilities on top
    if (nrow(low_vaccine_facilities) > 0 && "geometry" %in% names(low_vaccine_facilities)) {
      coords <- sf::st_coordinates(low_vaccine_facilities$geometry)
      if (nrow(coords) > 0) {
        leafletProxy("proximity_map", session) %>%
          addCircleMarkers(
            lng = coords[,1], lat = coords[,2],
            radius = 5, color = "red", fillColor = "red", fillOpacity = 0.9,
            group = "highlighted_facilities",
            label = lapply(paste0(low_vaccine_facilities$facility_name, " - ", low_vaccine_facilities$full_vax_pct, " (LOW VACCINE)"), HTML),
            labelOptions = labelOptions(noHide = FALSE, textOnly = FALSE, direction = "auto")
          )
      }
    }
  }
  
  # Update facility dropdown when data changes
  # Only schools and daycares are included in the dropdown (religious/tutoring/healthcare centers excluded)
  observe({
    facilities <- combined_facilities()
    if (!is.null(facilities) && nrow(facilities) > 0) {
      
      # Clean names
      display_names <- trimws(facilities$facility_name)
      
      # Build choices (IDs = row numbers, labels = names)
      choices <- setNames(seq_len(nrow(facilities)), display_names)
      
      # Remove bad labels
      bad <- is.na(names(choices)) |
        names(choices) == "" |
        toupper(names(choices)) %in% c("NA", "NULL") |
        grepl("^na\\s*-\\s*na$", names(choices), ignore.case = TRUE)
      choices <- choices[!bad]
      
      # Sort alphabetically
      choices <- choices[order(tolower(names(choices)))]
      
      updateSelectizeInput(session, "selected_facility",
                           choices = choices,
                           selected = "",
                           server = TRUE,
                           options = list(
                             placeholder = "Type a School/Child Care name...",
                             maxOptions = length(choices)
                           ))
    }
  })
  
  # Handle facility selection from dropdown
  observeEvent(input$selected_facility, {
    if (input$selected_facility != "") {
      facilities <- combined_facilities()
      selected <- facilities[as.numeric(input$selected_facility), ]
      if ("geometry" %in% names(selected)) {
        coords <- sf::st_coordinates(selected$geometry)
        analyze_proximity(coords[2], coords[1], paste("Selected:", selected$facility_name))
      }
    }
  })
  
  # Allow User to imput a specific address
  observeEvent(input$search_address_btn, {
    req(input$address_input) # Ensure input is not empty
    
    # Create a progress notification while geocoding
    id <- showNotification("Searching address...", duration = NULL, closeButton = FALSE)
    on.exit(removeNotification(id), add = TRUE)
    
    # Geocode the address using OpenStreetMap (OSM) 
    tryCatch({
      geo_result <- tidygeocoder::geo(
        address = input$address_input, 
        method = 'osm', 
        full_results = FALSE
      )
      
      # Check if valid coordinates
      if (!is.null(geo_result) && nrow(geo_result) > 0 && !is.na(geo_result$lat) && !is.na(geo_result$long)) {
        
        # Extract coordinates
        search_lat <- geo_result$lat
        search_lng <- geo_result$long
        
        # Call existing analysis function
        analyze_proximity(
          lat = search_lat, 
          lng = search_lng, 
          popup_title = paste0("Address: ", input$address_input)
        )
        
      } else {
        showNotification("Address not found. Please try being more specific (add city/zip).", type = "error")
      }
      
    }, error = function(e) {
      showNotification(paste("Geocoding failed:", e$message), type = "error")
    })
  })
  
  # Render the main leaflet map
  output$proximity_map <- renderLeaflet({
    facilities <- combined_facilities()
    county_data <- county_map_data()
    
    map <- leaflet(options = leafletOptions(minZoom = 5, maxZoom = 20)) %>%
      setView(lng = -94.5, lat = 46.5, zoom = 6) %>%
      addProviderTiles("CartoDB.Positron")  
    
    if (!is.null(county_data)) map <- map %>% addPolygons(data = county_data, color = "black", weight = 1)
    
    if (!is.null(facilities) && nrow(facilities) > 0 && "geometry" %in% names(facilities)) {
      coords <- sf::st_coordinates(facilities$geometry)
      if (nrow(coords) > 0) {
        map <- map %>% addCircleMarkers(
          lng = coords[,1], lat = coords[,2],
          radius = 3, color = "gray", fillColor = "gray", fillOpacity = 0.7,
          group = "School/Child Care Markers",
          label = lapply(paste0(facilities$facility_name, " - ", facilities$full_vax_pct), HTML),
          labelOptions = labelOptions(noHide = FALSE, textOnly = FALSE, direction = "auto")
        )
      }
    }
    
    map <- map %>% addLayersControl(
      overlayGroups = c("School/Child Care Markers"),
      options = layersControlOptions(collapsed = FALSE)
    ) 
    
    return(map)
  })
  
  # Handle map click events for manual point selection
  observeEvent(input$proximity_map_click, {
    click <- input$proximity_map_click
    analyze_proximity(click$lat, click$lng, "Manual Search Point")
  })
  
  # Re-run analysis when search parameters change
  observeEvent(list(input$radius_miles, input$vaccine_threshold), {
    if (!is.null(values$clicked_point)) {
      analyze_proximity(values$clicked_point$lat, values$clicked_point$lng, "Manual Search Point")
    }
  })
  
  # Return reactive values and functions for use by other modules
  return(list(
    clicked_point = reactive(values$clicked_point),
    radius_km = radius_km,
    low_vaccine_threshold = low_vaccine_threshold,
    low_vaccine_facilities_data = reactive(values$low_vaccine_facilities_data)
  ))
}