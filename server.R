# ============================================================
# SERVER LOGIC – MIDWEST EPIVIEW: MEASLES DASHBOARD
# ============================================================
#
# Purpose
# -------
# This file coordinates all server-side logic for the dashboard
# and initializes the modular components responsible for maps,
# tables, and analytical outputs.
#
# The server primarily performs four roles:
#
# 1. Manage shared reactive state used across modules
#    (e.g., selected_school_id).
#
# 2. Initialize UI inputs such as dropdown menus and filters.
#
# 3. Load and execute Shiny modules responsible for rendering
#    maps, tables, and detailed facility views.
#
# 4. Render statewide visualizations that are not part of a
#    module (e.g., the statewide measles case map).
#
# Major Modules Initialized Here
# ------------------------------
# countyMapServer()     → county-level vaccination map
# subMapServer()        → facility-level map (schools/daycares)
# gradeDetailsServer()  → grade-level vaccination panel
# proximityMapServer()  → proximity search map
# proximityTableServer()→ results table for proximity search
#
# ============================================================

# ==== Server ====
server <- function(input, output, session) {
  # Reactive value to store selected school ID (for use in grade/demographic lookup)
  selected_school_id <- reactiveVal(NULL)

  observeEvent(input$point_type, {
    selected_school_id(NULL)
  })
  
  # Initialize dropdowns when the app loads
  observe({
    # Populate county dropdown with sorted list of unique county names
    updateSelectInput(session, "selected_county", choices = sort(unique(counties$county_name)))
    
    # Populate measles case age group selector
    updateSelectInput(
      session,
      "case_age_group",
      choices = c(
        "All Ages",
        "0-4", "5-11", "12-19", "20-49", "50+"
      ),
      selected = "All Ages"
    )
  })
  
  # --- Helper to format vaccination % values nicely ---
  format_vax_pct <- function(x) {
    ifelse(
      is.na(x),
      "NA",
      ifelse(grepl("^>", x),
             paste0(x, ifelse(grepl("%$", x), "", "%")),  # if already has %, don't add
             paste0(suppressWarnings(as.numeric(gsub("[^0-9.]", "", x))), "%"))  # strips non-numeric
    )
  }
  
  
  # === County-level Leaflet Map and Measles Cases ==== 

  source("server_code/county_level_map.R")
  
  countyMapServer(
    input = input,
    output = output,
    session = session,
    county_map_data = county_map_data,
    measles_cases = measles_cases,
    counties = counties,
    pal_county = pal_county
  )
  
# === Submap ====  
  source("functions/add_point_offset.R")
  source("server_code/submap.R")
  
  subMapServer(
    input = input,
    output = output,
    session = session,
    school_demo_joined = school_demo_joined,
    daycare_joined = daycare_joined,
    county_map_data = county_map_data,
    selected_school_id = selected_school_id,
    format_vax_pct = format_vax_pct
  )
  
  # === Grade level Details Section ==== 
  
  source("server_code/grade_details_module.R")
  
  gradeDetailsServer(
    input = input,
    output = output,
    session = session,
    selected_school_id = selected_school_id,
    school_demo_joined = school_demo_joined,
    daycare_joined = daycare_joined,
    mmr_grade = mmr_grade,
    format_vax_pct = format_vax_pct
  )
  
  # ==== GT Table Tab ====  
  
  source("server_code/gt_table_module.R", local = TRUE)
  
  # ==== Measles Outbreak Tab ====
  
  ## Call file with visualization code
  source("functions/combineSchoolDaycareData.R")
  source("server_code/measles_proximity_map.R")
  source("server_code/measles_proximity_table.R")
  
  # Initialize the proximity map module
  ## For any updating of the app, switch out what dataframe is being utilized in the reactive expressions below
  proximity_results <- proximityMapServer(
    school_data = reactive(school_demo_joined),
    daycare_data = reactive(daycare_joined),  
    county_map_data = reactive(county_map_data),
    output = output,
    input = input, 
    session = session
  )
  
  # Initialize the proximity table module (uses values from the map module)
  proximityTableServer(
    proximity_map_values = proximity_results,
    output = output,
    input = input
  )

####Add ons for specific features below##### 
  
  # ============================================================
  # STATEWIDE K–12 MMR COVERAGE
  # ============================================================
  # This helper function calculates the statewide MMR vaccination
  # rate across all schools. The calculation is enrollment-weighted,
  # meaning total vaccinated students divided by total enrolled
  # students across the entire dataset.
  #
  # This value is displayed above the county map to provide
  # statewide context when users are viewing county-level coverage.
  # ============================================================
  
  # ---- STATEWIDE K-12 COVERAGE ----
  calc_statewide_k12 <- function(df) {
    
    df <- df |>
      dplyr::filter(!is.na(full_vax), !is.na(total_enrollment))
    
    if (nrow(df) == 0) return(NA)
    
    vaccinated <- sum(df$full_vax, na.rm = TRUE)
    students   <- sum(df$total_enrollment, na.rm = TRUE)
    
    if (students == 0) return(NA)
    
    round(100 * vaccinated / students, 1)
  }
  
  statewide_k12_rate <- reactive({
    calc_statewide_k12(school_demo_joined)
  })
  
  
  # ============================================================
  # STATEWIDE MEASLES CASE MAP - this was split late in development
  # ============================================================
  # This map is shown when the user selects "Historical Measles
  # Cases" in the dashboard. It displays Minnesota counties with
  # circle markers representing the number of reported measles
  # cases within the selected year range and age group.
  #
  # Circle sizes scale with case counts, allowing quick visual
  # comparison across counties.
  # ============================================================
  
  output$statewide_map <- renderLeaflet({
    
    # ---- filter cases ----
    filtered_cases <- measles_cases %>%
      dplyr::filter(
        year >= input$year_range[1],
        year <= input$year_range[2],
        dplyr::case_when(
          input$case_age_group == "All Ages" ~ TRUE,
          TRUE ~ age_group == input$case_age_group
        )
      ) %>%
      dplyr::group_by(county) %>%
      dplyr::summarise(
        n_cases = sum(n_cases, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::left_join(
        counties,
        by = c("county" = "county_lower")
      ) %>%
      sf::st_as_sf() %>%
      dplyr::mutate(
        centroid = sf::st_centroid(geometry)
      ) %>%
      sf::st_set_geometry("centroid")
    
    # ---- build map ----
    map <- leaflet(
      counties,
      options = leafletOptions(minZoom = 5, maxZoom = 9)
    ) |>
      setView(lng = -94.5, lat = 46.5, zoom = 6) |>
      setMaxBounds(-105, 40, -84, 52) |>
      addProviderTiles("CartoDB.Positron") |>
      
      # county boundaries
      addPolygons(
        fillColor = "#f5f5f5",
        fillOpacity = 0.3,
        color = "#bdbdbd",
        weight = 1,
        label = ~county_name,
        labelOptions = labelOptions(
          direction = "auto",
          textsize = "13px",
          opacity = 0.9
        )
      )
    
    # ---- add case circles safely ----
    if (nrow(filtered_cases) > 0) {
      map <- map |>
        addCircleMarkers(
          data = filtered_cases,
          radius = ~pmin(10, sqrt(n_cases) * 2),
          fillColor = "purple",
          color = "black",
          stroke = TRUE,
          fillOpacity = 0.85,
          popup = ~paste0(
            "County: ", county_name,
            "<br>Cases: ", n_cases
          ),
          label = ~paste0(
            county_name,
            " County: ",
            n_cases,
            " case",
            ifelse(n_cases == 1, "", "s")
          )
        ) |>
        
        # ===== OLD CLEAN LEGEND =====
      addControl(
        html = HTML("
<div style='padding:6px 8px;
            background:rgba(255,255,255,0.85);
            border:1px solid #aaa;
            border-radius:4px;
            box-shadow:0 1px 4px rgba(0,0,0,0.2);
            font-size:12px;
            max-width:170px;'>

  <b style='font-size:13px;'>Measles Cases</b><br>

  <svg width='150' height='90'>
    <circle cx='10' cy='10' r='2' fill='purple' stroke='black'></circle>
    <text x='25' y='14'>1 case</text>

    <circle cx='10' cy='30' r='4' fill='purple' stroke='black'></circle>
    <text x='25' y='34'>~4 cases</text>

    <circle cx='10' cy='50' r='7' fill='purple' stroke='black'></circle>
    <text x='25' y='54'>~12 cases</text>

    <circle cx='10' cy='70' r='10' fill='purple' stroke='black'></circle>
    <text x='25' y='74'>30+ cases</text>
  </svg>

</div>
"),
        position = "topright"
      )
    }
    
    map
  })
  
  output$county_map_title <- renderUI({
    
    rate <- statewide_k12_rate()
    
    tagList(
      h4(
        "MMR Vaccine Coverage by County (K-12 Schools Only)",
        style = "font-weight:600;"
      ),
      
      if (!is.na(rate)) {
        tags$div(
          paste0("Statewide MMR Coverage: ", rate, "%"),
          style = "font-size:14px; color:#555; margin-bottom:8px;"
        )
      }
    )
  })
  
  
  # ============================================================
  # County Map Title
  # ============================================================
  # Displays the title above the county vaccination map along
  # with the calculated statewide MMR coverage value.
  # ============================================================
  
  output$submap_title <- renderUI({
    
    req(input$selected_county)
    
    county_rate <- county_map_data |>
      dplyr::filter(county_name == input$selected_county) |>
      dplyr::pull(full_vax_pct) |>
      dplyr::first()
    
    tagList(
      h4(
        "MMR Coverage for Schools and Child Cares",
        style = "font-weight:600;"
      ),
      
      if (!is.na(county_rate)) {
        tags$div(
          paste0("Countywide MMR Coverage: ", county_rate, "%"),
          style = "font-size:14px; color:#555; margin-bottom:8px;"
        )
      }
    )
  })
}