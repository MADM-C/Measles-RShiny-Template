# county_level_map.R

# ============================================================
# COUNTY-LEVEL MAP MODULE
# ============================================================
#
# Purpose
# -------
# This module renders the main Minnesota county map on the dashboard.
# The map displays county-level MMR vaccination coverage for K–12 schools
# and provides the primary geographic entry point for exploring the app.
# Users can click counties to drill down into facility-level data shown
# in the submap module.
#
# Core Features
# -------------
# • Displays Minnesota counties colored by MMR vaccination coverage.
# • Shows county demographic context including total enrollment,
#   students of color, and free/reduced lunch eligibility.
# • Optionally switches to historical measles case data when enabled.
# • Allows users to select a county directly by clicking on the map.
# • Visually highlights the currently selected county.
#
# Data Sources
# ------------
# county_map_data
#   Spatial dataset of Minnesota counties joined with vaccination
#   coverage and aggregated school demographic data.
#
# measles_cases
#   County-level measles case dataset containing counts by year and
#   age group used for secondary map switch.
#
# mn_counties
#   Base county shapefile used for spatial joins and lookup of county
#   names when map polygons are clicked.
#
# pal_county
#   Color palette function used to shade counties according to MMR
#   vaccination coverage.
#
# Reactive Inputs Used
# --------------------
# input$show_cases
#   Toggles the measles case overlay on the county map.
#
# input$year_range
#   Filters measles cases to the selected year range.
#
# input$case_age_group
#   Filters measles cases by age group.
#
# input$selected_county
#   Name of the county currently selected in the dashboard controls.
#
# Outputs
# -------
# output$county_map
#   Leaflet map displaying county vaccination coverage and optional
#   measles case markers.
#
# Reactive Flow
# -------------
# User clicks county polygon
#        ↓
# county_map_shape_click event fires
#        ↓
# selected_county dropdown updates
#        ↓
# county highlight updates
#        ↓
# submap module loads facility-level data for that county
#
# ============================================================


countyMapServer <- function(input, output, session, county_map_data, measles_cases, mn_counties, pal_county) {
  
  # === County-level Leaflet Map ===
  output$county_map <- renderLeaflet({
    # Create base county map
    map <- leaflet(county_map_data, options = leafletOptions(minZoom = 5, maxZoom = 9)) %>%
      setView(lng = -94.5, lat = 46.5, zoom = 6) %>%
      setMaxBounds(-105, 40, -84, 52) %>% 
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(
        fillColor = ~pal_county(full_vax_pct),
        fillOpacity = 0.7,
        color = "white",
        weight = 1,
        layerId = ~county_lower,
        label = ~lapply(
          paste0(
            county_name, " County<br>",
            "2-dose MMR Coverage (K–12): ", full_vax_pct, "%<br>",
            "Enrollment (K–12): ", scales::comma(total_enrollment), "<br>",
            
            "Students of Color (K–12): ",
            ifelse(
              is.na(students_of_color) | is.na(total_enrollment) | total_enrollment == 0,
              "N/A",
              paste0(
                scales::comma(students_of_color), 
                " (", round(100 * students_of_color / total_enrollment, 1), "%)"
              )
            ),
            "<br>",
            
            "Free/Reduced Lunch Eligible (K–12): ",
            ifelse(
              is.na(frl_eligible) | is.na(total_enrollment) | total_enrollment == 0,
              "N/A",
              paste0(
                scales::comma(frl_eligible), 
                " (", round(100 * frl_eligible / total_enrollment, 1), "%)"
              )
            )
          ),
          htmltools::HTML
        )
      )%>%
      addLegend("bottomright", pal = pal_county, values = county_map_data$full_vax_pct,
                title = "County MMR (%)", opacity = 0.7)
    
    # === Measles case overlay ===
    if (!is.null(input$show_cases) && input$show_cases) {
      filtered_cases <- measles_cases %>%
        filter(
          year >= input$year_range[1],
          year <= input$year_range[2],
          case_when(
            input$case_age_group == "All Ages" ~ TRUE,
            TRUE ~ age_group == input$case_age_group
          )
        ) %>%
        group_by(county) %>%
        summarise(n_cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
        left_join(mn_counties, by = c("county" = "county_lower")) %>%
        mutate(centroid = st_centroid(geometry)) %>%
        st_as_sf() %>%
        st_set_geometry("centroid")
      
      if (nrow(filtered_cases) > 0) {
        map <- map %>%
          addCircleMarkers(
            data = filtered_cases,
            radius = ~pmin(10, sqrt(n_cases) * 2),
            fillColor = "purple",
            color = "black",
            stroke = TRUE,
            fillOpacity = 0.8,
            popup = ~paste0("County: ", county_name, "<br>Cases: ", n_cases),
            label = ~paste0(county_name, " County: ", n_cases, " case", ifelse(n_cases == 1, "", "s")),
            labelOptions = labelOptions(
              direction = "top",
              textsize = "13px",
              opacity = 0.85
            )
          ) %>%
          addControl(
            html = HTML("
      <div style='padding:6px 8px; background:rgba(255,255,255,0.85); border:1px solid #aaa; border-radius:4px; box-shadow:0 1px 4px rgba(0,0,0,0.2); font-size:11px; max-width:160px;'>
        <b style='font-size:12px;'>Measles Cases</b><br>
        <svg width='150' height='90'>
          <circle cx='10' cy='10' r='2' fill='purple' stroke='black' stroke-width='1'></circle>
          <text x='25' y='14'>1 case</text>

          <circle cx='10' cy='30' r='4' fill='purple' stroke='black' stroke-width='1'></circle>
          <text x='25' y='34'>~4 cases</text>

          <circle cx='10' cy='50' r='7' fill='purple' stroke='black' stroke-width='1'></circle>
          <text x='25' y='54'>~12 cases</text>

          <circle cx='10' cy='70' r='10' fill='purple' stroke='black' stroke-width='1'></circle>
          <text x='25' y='74'>30+ cases</text>
        </svg>
      </div>
          "),
            position = "topright"
          )
      }
    }
    
    map
  })
  
  # === Click county polygon to update county dropdown ===
  observeEvent(input$county_map_shape_click, {
    clicked <- input$county_map_shape_click$id
    match <- mn_counties %>% filter(county_lower == clicked) %>% pull(county_name)
    if (length(match) == 1) {
      updateSelectInput(session, "selected_county", selected = match)
    }
  })
  # === Highlight selected county in orange ===
  observeEvent(input$selected_county, {
    req(input$selected_county)
    
    selected_lower <- tolower(input$selected_county)
    
    selected_shape <- county_map_data %>%
      dplyr::filter(county_lower == selected_lower)
    
    leafletProxy("county_map") %>%
      clearGroup("highlight") %>%
      addPolygons(
        data = selected_shape,
        fill = FALSE,
        color = "orange",
        weight = 4,
        opacity = 1,
        group = "highlight"
      )
  })
}
