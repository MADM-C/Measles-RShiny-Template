# ============================================================
# SUBMAP MODULE (Facility-Level Map)
# ============================================================
#
# Purpose
# -------
# This module renders the facility-level map that appears after a county
# is selected on the main county dashboard map. The submap allows users to
# explore individual schools and child care facilities within the selected
# county and view their MMR vaccination coverage.
#
# Core Features
# -------------
# • Displays individual schools, child cares, or both depending on the
#   selected point_type filter.
# • Uses a small micro-offset for schools so that facilities sharing the
#   same geographic coordinates remain visible and clickable.
# • Clicking a marker updates the global selected_school_id reactive value
#   and synchronizes the dropdown selector.
# • Selecting a facility from the dropdown highlights the facility on the
#   map and centers the user’s attention on that location.
# • Shows facility-level vaccination information through popups and labels.
# • Provides optional layer controls when both schools and child cares are
#   displayed simultaneously.
#
# Data Inputs
# -----------
# school_demo_joined
#   Spatial dataset containing school vaccination coverage, demographic
#   attributes, and geometry.
#
# daycare_joined
#   Spatial dataset containing child care vaccination coverage and geometry.
#
# county_map_data
#   County boundary geometry used to draw the outline of the currently
#   selected county.
#
# selected_school_id
#   Reactive value shared across modules that stores the ID of the currently
#   selected facility. This allows the grade details module to update when a
#   school is selected from the map or dropdown.
#
# format_vax_pct
#   Helper function used to format vaccination percentages consistently in
#   labels, popups, and tables.
#
# Reactive Inputs Used
# --------------------
# input$selected_county
#   Determines which county’s facilities are shown on the submap.
#
# input$selected_location
#   Dropdown selection used to highlight a specific school or child care.
#
# input$point_type
#   Controls whether the map displays schools, child cares, or both.
#
# input$sub_map_marker_click
#   Triggered when a facility marker is clicked on the map.
#
# Outputs
# -------
# output$sub_map
#   Leaflet map displaying facility-level vaccination coverage and
#   interactive selection behavior.
#
# Reactive Flow
# -------------
# County selected on main map
#        ↓
# Facilities for that county rendered on submap
#        ↓
# User clicks facility marker OR selects from dropdown
#        ↓
# selected_school_id updated
#        ↓
# Grade details module updates facility-specific information
#
# ============================================================

subMapServer <- function(input, output, session,
                         school_demo_joined, daycare_joined,
                         county_map_data, selected_school_id, format_vax_pct) {
  
  # === Click school/daycare marker to update school ID and dropdown ===
  observeEvent(input$sub_map_marker_click, {
    clicked_raw <- input$sub_map_marker_click$id
    if (is.null(clicked_raw) || length(clicked_raw) == 0) return()
    clicked_id <- as.character(clicked_raw)[1]
    
    daycare_joined$idsch        <- as.character(daycare_joined$idsch)
    school_demo_joined$mde_school_id <- as.character(school_demo_joined$mde_school_id)
    
    school_df  <- sf::st_drop_geometry(school_demo_joined)
    daycare_df <- sf::st_drop_geometry(daycare_joined)
    
    school_match  <- dplyr::filter(school_df,  mde_school_id == clicked_id)
    daycare_match <- dplyr::filter(daycare_df, idsch          == clicked_id)
    
    name <- NULL
    if (nrow(school_match) > 0) {
      name <- school_match$school_name[1]  
      selected_school_id(school_match$mde_school_id[1])
    } else if (nrow(daycare_match) > 0) {
      name <- as.character(daycare_match$idsch[1]) 
      selected_school_id(daycare_match$idsch[1])
    }
    
    if (!is.null(name) && !is.na(name)) {
      updateSelectInput(session, "selected_location", selected = name)
    }
  })
  
  # === Location selection triggers highlight and fly ===
  observeEvent(input$selected_location, {
    req(input$selected_location, input$selected_county)
    point_type <- input$point_type
    
    if (point_type == "Schools") {
      selected_row <- school_demo_joined %>%
        dplyr::filter(tolower(COUNTYNAME) == tolower(input$selected_county),
                      school_name == input$selected_location) %>%  
        dplyr::slice(1)
      
      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$mde_school_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = selected_row,
            radius = 9, color = "black", weight = 3,
            fillColor = "black", fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", selected_row$school_name, "</b><br>",  
              "MMR: ", format_vax_pct(selected_row$full_vax_pct)
            )
          ) 
      }
      
    } else if (point_type == "Child Cares") {
      selected_row <- daycare_joined %>%
        dplyr::filter(idsch == input$selected_location) 
      
      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$idsch)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = selected_row,
            radius = 9, color = "black", weight = 3,
            fillColor = "black", fillOpacity = 1,
            group = "highlight",
            popup = paste0("<b>", selected_row$daycare_name, "</b><br>",  
                           "MMR: ", format_vax_pct(selected_row$full_vax_pct))
          ) 

      }
      
    } else if (point_type == "Schools and Child Cares") {
      school_row <- school_demo_joined %>%
        dplyr::filter(tolower(COUNTYNAME) == tolower(input$selected_county),
                      school_name == input$selected_location) %>%  
        dplyr::slice(1)
      
      daycare_row <- daycare_joined %>%
        dplyr::filter(tolower(COUNTYNAME) == tolower(input$selected_county),
                      daycare_name == input$selected_location) %>%  
        dplyr::slice(1)
      
      if (nrow(school_row) > 0) {
        selected_school_id(school_row$mde_school_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = school_row,
            radius = 12, color = "black", weight = 3,
            fillColor = "gold", fillOpacity = 1,
            group = "highlight",
            popup = paste0("<b>", school_row$school_name, "</b><br>",  
                           "MMR: ", format_vax_pct(school_row$full_vax_pct))
          ) 

      } else if (nrow(daycare_row) > 0) {
        selected_school_id(daycare_row$idsch)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = daycare_row,
            radius = 9, color = "black", weight = 3,
            fillColor = "black", fillOpacity = 1,
            group = "highlight",
            popup = paste0("<b>", daycare_row$daycare_name, "</b><br>", 
                           "MMR: ", format_vax_pct(daycare_row$full_vax_pct))
          ) 

      }
    }
  })
  
  # === Render the sub map with micro-offset ===
  output$sub_map <- renderLeaflet({
    req(input$selected_county)
    selected <- tolower(input$selected_county)
    
    county_shape   <- county_map_data %>% dplyr::filter(county_lower == selected)
    county_schools <- school_demo_joined  %>% dplyr::filter(tolower(COUNTYNAME) == selected)
    county_daycares<- daycare_joined %>% dplyr::filter(tolower(COUNTYNAME) == selected)
    
    # Apply micro-offset to schools
    county_schools_offset <- add_micro_offset(county_schools)

    get_fill_color <- function(vax_pct) {
      vax_num <- suppressWarnings(as.numeric(vax_pct))
      
      dplyr::case_when(
        is.na(vax_pct)                      ~ "gray",       # Missing/unknown
        grepl("^>", vax_pct)                ~ "darkgreen",       # Blurred ('>95%')
        vax_num < 85                        ~ "red",        # <85%
        vax_num < 90                        ~ "orange",     # 85–89%
        vax_num < 95                        ~ "gold",       # 90–94%
        vax_num >= 95                       ~ "darkgreen",  # ≥95%
        TRUE                                ~ "gray"        # Fallback
      )
    }
    
    # Base map with county boundary
    map <- leaflet(options = leafletOptions(minZoom = 6, maxZoom = 18)) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(data = county_shape, fillOpacity = 0.2, color = "black", weight = 2)
    
    if (input$point_type == "Schools") {
      map <- map %>%
        addCircleMarkers(
          data = county_schools_offset,
          lng = ~final_lon, 
          lat = ~final_lat,
          radius = ~ifelse(n_at_location > 1, 6, 5),  # Slightly larger for duplicates
          stroke = TRUE, 
          weight = ~ifelse(n_at_location > 1, 2, 1),  # Thicker border for duplicates
          color = "black",
          fillColor = ~get_fill_color(full_vax_pct),
          fillOpacity = 0.9,
          layerId = ~mde_school_id,
          popup = ~paste0(
            "<b>", school_name, "</b><br>", COUNTYNAME, " County<br>",  
            "Grades: ", GRADERANGE, "<br>",
            "MMR Coverage: ", format_vax_pct(full_vax_pct),
            ifelse(n_at_location > 1, 
                   paste0("<br><i>", "Warning: ", n_at_location, " schools at this location</i>"), "")
          ),
          label = ~paste0(school_name, ": ", format_vax_pct(full_vax_pct)),  
          labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
        )
      
    } else if (input$point_type == "Child Cares") {
      map <- map %>%
        addCircleMarkers(
          data = county_daycares,
          radius = 5,
          stroke = TRUE, 
          weight = 1,
          color = "black",
          fillColor = ~get_fill_color(full_vax_pct),
          fillOpacity = 0.9,
          layerId = ~idsch,
          popup = ~paste0(daycare_name, "<br>", COUNTYNAME, " County<br>","Eligible: ", enroll_mmreligible, "<br>","Vaccinated (1 dose): ", full_vax, "<br>", "Coverage: ", format_vax_pct(full_vax_pct)
          ),
          label = ~paste0(daycare_name, ": ", format_vax_pct(full_vax_pct)),  
          labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
        )
      
    } else if (input$point_type == "Schools and Child Cares") {
      map <- map %>%
        # Schools layer with micro-offset
        addCircleMarkers(
          data = county_schools_offset,
          lng = ~final_lon, 
          lat = ~final_lat,
          radius = ~ifelse(n_at_location > 1, 7, 6),  # Slightly larger for duplicates
          stroke = TRUE, 
          weight = ~ifelse(n_at_location > 1, 2, 1),  # Thicker border for duplicates
          color = "black",
          fillColor = ~get_fill_color(full_vax_pct),
          fillOpacity = 0.9,
          layerId = ~mde_school_id,
          group = "Schools",
          popup = ~paste0("<b>", school_name, "</b><br>", COUNTYNAME, " County<br>",
                          "Type: School<br>Grades: ", GRADERANGE, "<br>",
                          "MMR Coverage: ", format_vax_pct(full_vax_pct),
                          ifelse(n_at_location > 1, 
                                 paste0("<br><i>", n_at_location, " schools at this location</i>"), "")),
          label = ~paste0(school_name, " (School): ", format_vax_pct(full_vax_pct)),  
          labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
        ) %>%
        # Daycares layer (no offset needed)
        addCircleMarkers(
          data = county_daycares,
          radius = 4,
          stroke = TRUE, 
          weight = 1,
          color = "black",
          fillColor = ~get_fill_color(full_vax_pct),
          fillOpacity = 0.9,
          layerId = ~idsch,
          group = "Child Cares",
          popup = ~paste0(
            daycare_name, "<br>", COUNTYNAME, " County<br>",  
            "Type: Daycare<br>Eligible: ", enroll_mmreligible,
            "<br>Vaccinated: ", full_vax,
            "<br>Coverage: ", format_vax_pct(full_vax_pct)
          ),
          label = ~paste0(daycare_name, " (Daycare): ", format_vax_pct(full_vax_pct)),  
          labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
        ) %>%
        # Add layer control for toggling schools/daycares
        addLayersControl(
          overlayGroups = c("Schools", "Child Cares"),
          options = layersControlOptions(collapsed = FALSE)
        )
    }
    
    # --- Legend for school/daycare cut-points ---
    map <- map %>%
      addLegend(
        position = "bottomright",
        colors = c("red", "orange", "gold", "darkgreen", "gray"),
        labels = c(
          "0-85",          # red
          "85-90",        # orange
          "90-95",        # gold
          "95-100",          # dark green
          "Missing/Unknown"   # gray
        ),
        title = "School/Child Care MMR (%)",
        opacity = 0.9
      )
    
    map
  })
  # === Extra legend for School vs. Daycare shapes ===
  legend_html <- HTML("
    <div style='background:white; padding:6px; border-radius:4px; font-size:13px;'>
      <b>Location Type</b><br>
      <svg height='14' width='14'><circle cx='7' cy='7' r='6' stroke='black' stroke-width='1' fill='black' /></svg> School<br>
      <svg height='14' width='14'><circle cx='7' cy='7' r='4' stroke='black' stroke-width='1' fill='black' /></svg> Daycare
    </div>
  ")
  
  # Add/remove the legend depending on point_type
  observe({
    if (input$point_type == "Schools and Child Cares") {
      leafletProxy("sub_map") %>%
        addControl(legend_html, position = "bottomleft", layerId = "type_legend")
    } else {
      leafletProxy("sub_map") %>%
        removeControl("type_legend")
    }
  })
}