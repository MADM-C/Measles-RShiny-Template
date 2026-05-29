# Server function for proximity analysis results table
# This function creates a DataTable displaying facilities that meet proximity and vaccination criteria
# The table updates automatically when map interactions change the analysis results
# Parameters:
#   proximity_map_values: list of reactive values from proximityMapServer containing:
#     - low_vaccine_facilities_data(): reactive returning filtered facility data
#     - clicked_point(): reactive returning last clicked map coordinates
#   output: Shiny output object for rendering the DataTable
#   input: Shiny input object (currently unused but required for server function signature)
proximityTableServer <- function(proximity_map_values, output, input) {
  
  output$low_vaccine_table <- DT::renderDataTable({
    
    facilities_data <- proximity_map_values$low_vaccine_facilities_data()
    clicked_point <- proximity_map_values$clicked_point()
    
    # FILTER OUT religious centers from table data
    if (!is.null(facilities_data) && nrow(facilities_data) > 0) {
      facilities_data <- facilities_data[facilities_data$facility_type %in% c("School", "Daycare"), ]
    }
    
    if (is.null(facilities_data) || nrow(facilities_data) == 0) {
      if (!is.null(clicked_point)) {
        # User has searched but no facilities meet criteria
        empty_df <- data.frame(
          message = "No facilities below threshold found in selected area",
          type = "", vaccine_rate = "", distance = "", enrollment = "",
          stringsAsFactors = FALSE
        )
      } else {
        # User hasn't performed any search yet
        empty_df <- data.frame(
          message = "Click on the map to search for low-vaccine facilities",
          type = "", vaccine_rate = "", distance = "", enrollment = "", contact_info = "",
          stringsAsFactors = FALSE
        )
      }
      return(empty_df)
    }
    
    # Calculate distances from search point to each facility
    if (!is.null(clicked_point)) {
      # Extract facility coordinates from spatial geometry
      coords <- st_coordinates(facilities_data$geometry)
      
      # Convert coordinates to radians for trigonometric distance calculation
      lat1_rad <- clicked_point$lat * pi / 180        # Search point latitude in radians
      lng1_rad <- clicked_point$lng * pi / 180        # Search point longitude in radians
      lat2_rad <- coords[,2] * pi / 180               # Facility latitudes in radians
      lng2_rad <- coords[,1] * pi / 180               # Facility longitudes in radians
      
      # Haversine formula for great-circle distance between two points on Earth
      # This accounts for Earth's curvature and provides accurate distances
      dlat <- lat2_rad - lat1_rad                     # Latitude difference
      dlng <- lng2_rad - lng1_rad                     # Longitude difference
      
      # Haversine formula components
      a <- sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlng/2)^2
      c <- 2 * atan2(sqrt(a), sqrt(1-a))
      
      # Calculate distance in kilometers (Earth's radius = 6371 km)
      distances_km <- 6371 * c
      
      # Convert to miles and round to 1 decimal place for display
      distances_miles <- round(distances_km * 0.621371, 1)
      distance_text <- distances_miles
    } else {
      # No search point available - shouldn't happen with current logic but provides fallback
      distance_text <- rep("N/A", nrow(facilities_data))
    }
    
    # Format enrollment for display (handle missing values)
    enrollment_text <- ifelse(is.na(facilities_data$enrollment), 
                              "Not Available", 
                              format(facilities_data$enrollment, big.mark = ","))
    
    # Create result table with standardized column names for internal use
    result_table <- data.frame(
      facility_name = facilities_data$facility_name,    # School or daycare name
      type = ifelse(facilities_data$facility_type == "Daycare", "Child Care", facilities_data$facility_type),            # "School" or "Daycare"
      vaccine_rate = facilities_data$full_vax_pct,      # Vaccination percentage
      distance = distance_text,                         # Distance with "mi" suffix
      enrollment = enrollment_text,                     # Enrollment numbers with formatting
      stringsAsFactors = FALSE                          # Prevent automatic factor conversion
    )
    
    return(result_table)
    
  },
  # DataTable configuration options
  extensions = 'Buttons',              # Enable the Buttons extension
  options = list(
    pageLength = 10,                    # Show 10 rows per page by default
    scrollY = "400px",                  # Enable vertical scrolling with 400px height
    scrollCollapse = TRUE,              # Collapse table height if fewer than 400px needed
    searching = TRUE,                   # Enable search/filter box
    ordering = TRUE,                    # Enable column sorting
    order = list(list(2, 'asc')),       # Default sort by vaccine rate (3rd column, 0-indexed as 2)
    dom = 'Bfrtip',                     # Add buttons to the table interface
    buttons = list(                     # Configure download buttons
      list(extend = 'csv', filename = 'low_vaccine_facilities'),
      list(extend = 'excel', filename = 'low_vaccine_facilities'),
      list(extend = 'pdf', filename = 'low_vaccine_facilities')
    ),
    columnDefs = list(list(
      targets = 3,    # Target the 4th column (Distance) - Index starts at 0
      render = DT::JS(
        "function(data, type, row, meta) {",
        "  return (type === 'display' && data != null && data !== '') ?",
        "    data + ' mi' : data;",
        "}"
      )
    ))
  ), 
  # Custom column headers displayed to user (overrides data frame column names)
  # This prevents periods in column names that R would automatically add
  colnames = c("School/Child Care Name", "Type", "Vaccine Rate", "Distance from Point", "Enrollment"),
  rownames = FALSE                      # Don't show row numbers
  )
}