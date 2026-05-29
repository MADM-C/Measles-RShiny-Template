# ============================================================
# USER INTERFACE (UI) – MIDWEST EPIVIEW: MEASLES DASHBOARD
# ============================================================
#
# Purpose
# -------
# This file defines the full user interface for the Midwest
# EpiView: Measles dashboard. It structures the layout of the
# application, organizes navigation across tabs, and creates
# reusable UI components used throughout the app.
#
# The UI is responsible only for layout and display elements.
# All data processing, mapping logic, and reactive behavior are
# implemented in the server-side modules.
#
# Application Structure
# ---------------------
# The dashboard is organized into four primary tabs:
#
# 1. About
#    Provides background information about measles, vaccination
#    coverage requirements, and the data sources used in the
#    dashboard. This tab also contains definitions, data notes,
#    and project acknowledgements.
#
# 2. Dashboard
#    The main interactive exploration tool. Users can view:
#       • County-level MMR vaccination coverage
#       • Historical measles case data
#       • Facility-level vaccination coverage for schools
#         and child cares within a selected county
#       • Grade-level vaccination data for individual schools
#
# 3. Summary Figures
#    Displays statewide tables summarizing:
#       • School MMR vaccination coverage
#       • Child care MMR vaccination coverage
#       • Historical measles cases by year and age group
#    These tables are rendered using the `gt` package and
#    allow users to filter by county and outcome type.
#
# 4. Proximity Map
#    Allows users to identify schools and child care facilities
#    with vaccination coverage below a user-defined threshold
#    within a specified search radius of a selected location
#    or address.
#
# Shared UI Components
# --------------------
# Several reusable UI blocks are defined at the top of this file:
#
# intro_text_vaccine_coverage
#    Introductory text explaining measles transmission and
#    vaccination coverage thresholds.
#
# definitions_block
#    Definitions of key terms used throughout the dashboard.
#
# data_notes_block
#    Notes describing limitations and sources of the vaccination
#    and geospatial datasets.
#
# dashboard_tables_intro
#    Introductory instructions for the main dashboard tab.
#
# tables_intro
#    Description of the summary figures tab.
#
# intro_text_proximity_map
#    Instructions for using the proximity search tool.
#
# footer_block
#    Shared footer including funding acknowledgements,
#    contact information, and project logos.
#
# Key Layout Elements
# -------------------
# • navbarPage is used to create the top navigation structure.
# • sidebarLayout organizes inputs and outputs in the dashboard.
# • conditionalPanel dynamically shows UI elements based on
#   user selections (e.g., county view vs. statewide case view).
# • leafletOutput containers are used for all interactive maps.
# • gt_output and DT outputs display tables generated in
#   server modules.
#
# Note
# ----
# Map rendering, table generation, and analytical logic
# is handled in the server modules:
#
# county_level_map.R
# submap.R
# grade_details_module.R
# gt_table_module.R
# proximity_map.R
# proximity_table.R
#
# ============================================================

# ==== Loading in packages ==== 
source("packages_and_data.R")
library(leaflet)
library(gt)

# === First Two Tabs Intro Paragraph ===
intro_text_vaccine_coverage <- tags$div(
  style = "margin-bottom: 10px; width: 100%; font-size: 14px; line-height: 1.5; color: #333;",
  
  # --- Callout box ONLY for first paragraph ---
  tags$div(
    style = "margin-top: 10px; margin-bottom: 16px; padding: 12px 14px;
             background-color: #f7f7f7; border-left: 4px solid #1E3A66;",
    HTML("
      Measles is a highly contagious respiratory disease that can cause serious complications, including hospitalization and death. The measles, mumps, and rubella (MMR) vaccine is highly effective at preventing infection and is the best way to prevent illness from measles. Because measles spreads so easily, at least 95% of the population needs to be vaccinated to prevent outbreaks and protect communities across Minnesota. For more information on measles, see Minnesota Department of Health website (<a href='https://www.health.state.mn.us/diseases/measles/index.html' target='_blank' style='color:#0066cc;'>MDH</a>).
    ")
  ),
  
  # --- Normal paragraph below the box ---
  tags$p(
    HTML("
      This dashboard displays public data from the Minnesota Department of Health and Minnesota Department of Education. Measles case data is reported for 2010–2025. Vaccination data is reported for child cares, schools, and grade-levels when available for the 2025–2026 school year. The K-12 MMR coverage is the percent of students with 2-doses of MMR vaccine and the child care MMR coverage rate is the percent of students with 1 dose of MMR. Data may be incomplete for some locations.
    "),
    style = "margin-bottom: 10px;"
  )
)

# === Definitions Section ===
definitions_block <- tags$div(
  style = "margin-top: 6px; margin-bottom: 14px; font-size: 14px; line-height: 1.5; color: #333;",
  HTML("
<strong>Definitions</strong>
<ul>
  <li><b>MMR coverage</b>: Percent of enrolled students who received the recommended measles, mumps, and rubella (MMR) vaccine doses (2 doses for K–12 schools, 1 dose for child cares).</li>
  <li><b>Enrollment</b>: Number of students reported by the facility in the annual immunization report. </li>
  <li><b>Eligible</b>: Students who meet the criteria to be included in vaccination coverage reporting for a school or child care facility.</li>
</ul>
")
)

# === Data Notes Section ===
data_notes_block <- tags$div(
  style = "margin-top: 6px; margin-bottom: 14px; font-size: 14px; line-height: 1.5; color: #333;",
  HTML("
<strong>Data Notes</strong>
<ul>
  <li>Vaccination rates reflect annual school and child care immunization data reported to MDH and may be incomplete for certain facilities or counties.</li>

  <li>Enrollment counts may differ between Minnesota Department of Education and Minnesota Department of Health records. These discrepancies are due to the timing of enrollment snapshots and differences in whether schools with the same name are split or aggregated across grade levels (e.g., elementary, middle, and high school campuses).</li>

  <li>Geospatial layers were sourced from the Minnesota Geospatial Commons.</li>
  
  
  <li>To protect privacy, data blurring standards were used. Data blurring involves reporting a range of vaccination coverage rather than a precise percentage. For example, schools or school districts that report all or almost all of their students being fully vaccinated have vaccination rates displayed as >95% or >98%. The range reported depends on the number of students enrolled in the school or school district. Data blurring is used to limit sharing private health information on individuals.</li>
</ul>
")
)

### Tables tab intro 
tables_intro <- tags$div(
  style = "margin-bottom: 12px",
  tags$p(
    "This tab provides figures that report MMR vaccine coverage and enrollment for all schools or child cares in a user-selected county as well as historical measles cases by year and age for that county. To use this tool, first select the outcome then select the county.",
    style = "font-size: 14px; line-height: 1.5; color: #444;"
  )
)

### Dashboard/Tables Intro
dashboard_tables_intro <- tags$div(
  style = "margin-bottom: 12px",
  tags$p(
    "This tab displays measles, mumps, and rubella (MMR) vaccine coverage data for schools and child cares in Minnesota as well as historical measles case data. 
    
    To use this tool, first select an outcome (either historical measles cases or vaccine coverage). For historical measles coverage, filter data by selecting the date range of cases to include and/or selecting age groups. For vaccine coverage, click on the map or select a county in the drop-down to view vaccine coverage data for schools and/or child cares in that county. To view grade-level vaccine coverage for a school, click the school on the map or select it from the drop-down.",
    style = "font-size: 14px; line-height: 1.5; color: #444;"
  )
) 

# === Proximity Map Intro Paragraph ===
intro_text_proximity_map <- tags$div(
  style = "margin-bottom: 10px",
  tags$p(
    HTML("
      This tool can help identify schools and child cares with low vaccination rates within a defined search area. To use this tool, first select a school/child care or enter an address. Then select a search radius in miles and define a vaccine coverage  threshold. The map will display schools and child cares with vaccine coverage less than the defined threshold in red. Facilities with vaccine coverage higher than the threshold are shown in gray. 
    "),
    style = "color: #555; line-height: 1.45; margin-top: 0px; margin-bottom: 6px;"
  )
)

# === Shared Footer (Documentation + Logos) ===
footer_block <- tags$div(
  style = "margin-top: 40px; text-align: center; max-width: 900px; margin-left: auto; margin-right: auto;",
  
  tags$div(
    HTML("
      <div style='font-size: 12.5px; color: #555; line-height: 1.55; text-align: left;'>

        <strong>Funding</strong><br>
        This work was supported by cooperative agreement CDC-RFA-FT-23-0069 from the Center for Forecasting and Outbreak Analytics of the U.S. Centers for Disease Control and Prevention (CDC). Its contents are solely the responsibility of the authors and do not necessarily represent the official views of the CDC.<br><br>

        <strong>Contact</strong><br>
  This dashboard was created by the 
  <a href='https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/about/' target='_blank' style='color:#0066cc;'>
    Midwest Analytics and Disease Modeling Center (MADMC)</a>. 
  For questions or more information, please contact 
  <a href='mailto:madmc@umn.edu' style='color:#0066cc;'>madmc@umn.edu</a>.
</div>
")
  ),
  
  tags$div(
    style = "display: flex; justify-content: center; align-items: center; gap: 40px; margin-top: 25px;",
    tags$img(src = 'umn_logo.png', style = 'height: 50px;')
  ),
  
  ## Will update automatically when app is published
  tags$p(
    paste0("Last updated: ", format(Sys.Date(), "%B %d, %Y")),
    style = "font-size: 12.5px; color: gray; margin-top: 10px; font-style: italic;"
  )
)

ui <- tagList(
  # --- UMN Branding Banner ---
  tags$div(
    style = "width: 100%; background-color: #7A0019; padding: 6px 24px;",
    tags$img(
      src = "UMN_horizontal-reversed-digital.svg",
      style = "height: 30px;"
    )
  ),
  
  navbarPage(
    title = div(
      tags$img(
        src = "madmc_logo.png",
        style = "height: 30px; margin-right: 10px; vertical-align: middle;"
      ),
      span("Midwest EpiView: MMR Coverage and Measles", style = "font-weight: 600; font-size: 20px; vertical-align: middle;")
    ),
    
    # === ABOUT TAB ===
    tabPanel(
      "About",
      fluidPage(
        tags$h3("About Midwest EpiView: MMR Coverage and Measles"),
        tags$br(),
        intro_text_vaccine_coverage,
        definitions_block,
        data_notes_block, 
        tags$hr(),
        footer_block
      )
    ),
    
    # === Dashboard Tab ===
    tabPanel(
      "Dashboard",
      fluidPage(
        dashboard_tables_intro,
        sidebarLayout(
          
          # === Sidebar for Inputs ===
          sidebarPanel(
            width = 3,
            
            # --- Statewide View Controls ---
            tags$div("Outcome:", style = "font-weight:600; margin-bottom:4px;"), 
            radioButtons(
              "map_mode",
              label = NULL,
              choices = c(
                "MMR Vaccine Coverage" = "county",
                "Historical Measles Cases" = "statewide"
              ),
              selected = "county"
            ), 
            
            conditionalPanel(
              condition = "input.map_mode == 'statewide'",
              sliderInput("year_range", "Year Range:", min = 2010, max = 2025, value = c(2015, 2020), sep = ""),
              selectInput("case_age_group", "Age Group:", choices = NULL)
            ),
            
            # --- County-level Details ---
            conditionalPanel(
              condition = "input.map_mode == 'county'",
              selectInput("selected_county", "County:", choices = NULL),
              radioButtons("point_type", "Show:",
                           choices = c("Schools", "Child Cares", "Schools and Child Cares"),
                           selected = "Schools"),
              uiOutput("school_daycare_selector")
            )
          ),
          
          # === Main Panel for Outputs ===
          mainPanel(
            width = 9,
            
            fluidRow(
              column(6,
                     conditionalPanel(
                       condition = "input.map_mode == 'county'",
                       uiOutput("county_map_title"),
                       leafletOutput("county_map", height = 500, width = "100%")
                     ),
                     conditionalPanel(
                       condition = "input.map_mode == 'statewide'",
                       h4("Historical Measles Case Data", style = "font-weight:600;"),
                       leafletOutput("statewide_map", height = 500, width = "100%")
                     )
              ),
              column(6,
                     conditionalPanel(
                       condition = "input.map_mode == 'county' && input.selected_county != ''",
                       uiOutput("submap_title"), 
                       leafletOutput("sub_map", height = 500, width = "100%")
                     )
              )
            ),
            
            # --- County-level Details: Grade-Level Table ---
            conditionalPanel(
              condition = "input.map_mode == 'county' && input.selected_county != ''",
              h4("MMR Coverage in Schools by Grade-Level", style = "font-weight:600;"),
              uiOutput("grade_demo_text"),
              tableOutput("grade_output")
            ),
            tags$hr()
          )
        )
      )
    ),
    
    # === GT Table Tab ===
    tabPanel(
      "Summary Figures",
      fluidPage(
        tables_intro,
        h3("MMR Vaccination and Measles Case Summary Figures"),
        
        fluidRow(
          # --- Left column: Controls ---
          column(
            width = 2,
            radioButtons(
              inputId = "table_type",
              label = "Select Outcome",
              choices = c("School Vaccine Coverage", "Child Care Vaccine Coverage", "Historical Measles Cases"),
              selected = "School Vaccine Coverage"
            ),
            selectInput(
              inputId = "gt_selected_county",
              label = "Select County:",
              choices = NULL
            ),
            conditionalPanel(
              condition = "input.table_type == 'School Vaccine Coverage' || 
                 input.table_type == 'Child Care Vaccine Coverage'",
              selectInput(
                inputId = "gt_sort_by",
                label = "Sort Table By:",
                choices = c(
                  "MMR %" = "full_vax_pct",
                  "Name" = "name",
                  "Enrollment" = "total_enrollment"
                ),
                selected = "full_vax_pct"
              )
            )
          ),
          
          # --- Right column: Epicurve FIRST, then GT table ---
          column(
            width = 10,
            
            # Epicurve when Measles Cases selected
            conditionalPanel(
              condition = "input.table_type == 'Historical Measles Cases'",
              tags$div(
                style = "margin-bottom: 25px;",
                h4("Measles Cases by Year", style = "font-weight: 600; color: #1E3A66;"),
                plotOutput("epi_curve", height = "350px", width = "100%"),
                tags$hr(style = "border-top: 2px solid #1E3A66; margin-top: 25px;")
              )
            ),
            
            # GT table always rendered
            gt_output("summary_table")
          )
        )
      )
    ),
    
    # === Proximity Map Tab ===
    tabPanel(
      "Proximity Map",
      fluidPage(
        intro_text_proximity_map,
        h3("School and Child Care Proximity Map"),
        
        # Controls section
        tags$div(
          role = "region",
          `aria-labelledby` = "controls-heading",
          tags$h4("Map Controls", id = "controls-heading", class = "sr-only"),
          
          # --- SECTION 1: Search Inputs (Grey Background) ---
          wellPanel(
            h4("Place a point on the map by selecting a school or a child care facility or by entering an address:", style = "margin-top: 0; margin-bottom: 15px;"),
            fluidRow(
              column(6,
                     selectizeInput(
                       inputId = "selected_facility",
                       label = "Select a facility:",
                       choices = NULL,
                       selected = NULL,
                       options = list(placeholder = "Type a School/Child Care name...")
                     )
              ),
              column(6,
                     textInput("address_input", "Enter an address (include street, city, and zipcode):",
                               placeholder = "e.g. 100 Church St SE, Minneapolis, MN, 55455"),
                     tags$div(
                       style = "margin-bottom: 10px;",
                       actionButton("search_address_btn", "Search Address", class = "btn-primary")
                     )
              )
            )
          ),
          
          # --- SECTION 2: Map Filters (White Background) ---
          fluidRow(
            style = "padding-top: 15px;",
            column(6,
                   sliderInput("radius_miles",
                               "Search Radius (miles):",
                               value = 10, min = .1, max = 10, step = .1)
            ),
            column(6,
                   sliderInput("vaccine_threshold",
                               "Low Vaccine Threshold (%):",
                               value = 85, min = 0, max = 100, step = 1)
            )
          )
        ),
        
        # Results section with proper headings and labels
        tags$div(
          role = "region",
          `aria-labelledby` = "results-heading",
          tags$h4("Results", id = "results-heading", class = "sr-only"),
          
          fluidRow(
            column(6,
                   tags$div(
                     role = "img",
                     `aria-label` = "Interactive map showing a chosen point and nearby schools with vaccination data",
                     leafletOutput("proximity_map", height = 600)
                   )
            ),
            column(6,
                   h4("Schools and Child Cares with Low Vaccine Coverage"),
                   p("Results show facilities within the selected radius that have MMR vaccine coverage below the user-defined vaccine threshold.", 
                     style = "color: #666; font-size: 14px; margin-bottom: 15px;"),
                   tags$div(
                     role = "region",
                     `aria-label` = "Data table of schools and child cares with low vaccination rates",
                     DT::dataTableOutput("low_vaccine_table")
                   )
            )
          )
        )
      )
    )
  ) 
) 