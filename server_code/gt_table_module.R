# ==== GT TABLE MODULE (server-side) ====

# ============================================================
# GT TABLE MODULE (Statewide Data Tables and Epicurve)
# ============================================================
#
# Purpose
# -------
# This module generates the statewide data tables displayed on the
# "Tables" tab of the dashboard (now called "Summary Figures"). It provides summary views of:
#
# • School vaccination coverage
# • Child care vaccination coverage
# • Historical measles case counts
#
# The module also renders the measles epidemic curve when historical
# case data are selected.
#
# Core Features
# -------------
# • Builds three cleaned datasets used for table display:
#     - school_table
#     - daycare_table
#     - case_table
#
# • Displays vaccination coverage tables using the `gt` package with:
#     - color-coded MMR coverage
#     - sortable columns
#     - formatted enrollment values
#     - privacy-safe display for blurred values (e.g. ">95%")
#
# • Displays measles case counts by year and age group in a wide-format
#   table when historical case data are selected.
#
# • Synchronizes the county selector with the selected table type,
#   including a special "Statewide" option for historical cases.
#
# • Renders an epidemic curve showing annual measles cases for either
#   the selected county or statewide totals.
#
# Data Inputs
# -----------
# school_demo_joined
#   Spatial dataset containing school vaccination coverage and
#   enrollment data. Geometry is removed before table construction.
#
# daycare_joined
#   Spatial dataset containing child care vaccination coverage and
#   MMR-eligible enrollment counts.
#
# measles_cases
#   Dataset containing historical measles cases by county, year,
#   and age group.
#
# counties
#   Used to generate the list of counties for the table dropdown.
#
# Reactive Inputs Used
# --------------------
# input$table_type
#   Determines which table to display:
#       - School Vaccine Coverage
#       - Child Care Vaccine Coverage
#       - Historical Measles Cases
#
# input$gt_selected_county
#   County selected for table filtering.
#
# input$gt_sort_by
#   Column used to sort the school vaccination coverage table.
#
# Outputs
# -------
# output$summary_table
#   Main `gt` table displaying vaccination coverage or measles
#   case counts depending on the selected table type.
#
# output$epi_curve
#   Bar chart showing measles cases by year for the selected
#   county or statewide.
#
# Reactive Flow
# -------------
# User selects table type
#        ↓
# County selector updates to match valid choices
#        ↓
# Data filtered to selected county
#        ↓
# GT table rendered
#
# If historical cases selected:
#        ↓
# Epidemic curve generated from filtered case data
#
# ============================================================
# Expects in parent env: input, output, session,
#   school_demo_joined (sf), daycare_joined (sf), measles_cases (df)

# ---------- Build School Table (with demographics) ----------
school_table <- school_demo_joined %>%
  sf::st_drop_geometry() %>%
  dplyr::transmute(
    county = stringr::str_to_title(COUNTYNAME),
    name   = school_name,
    full_vax_pct_chr = full_vax_pct,  # retain the original string (e.g. ">95")
    full_vax_pct_num = suppressWarnings(
      as.numeric(stringr::str_extract(full_vax_pct, "[0-9.]+"))
    ),
    total_enrollment
  ) %>%
  dplyr::filter(
    !is.na(total_enrollment),
    total_enrollment > 0,
    !is.na(full_vax_pct_num)
  ) %>%
  dplyr::group_by(county, name, full_vax_pct_chr) %>%
  dplyr::summarise(
    full_vax_pct     = round(mean(full_vax_pct_num, na.rm = TRUE), 1),
    total_enrollment = sum(total_enrollment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::select(
    county,
    name,
    full_vax_pct,
    full_vax_pct_chr,
    total_enrollment
  )
# ---------- Build Daycare Table ----------
daycare_table <- daycare_joined %>%
  sf::st_drop_geometry() %>%
  dplyr::transmute(
    county = stringr::str_to_title(COUNTYNAME),
    name   = daycare_name,
    # numeric helper from strings like "94.2", ">95", "95%"
    full_vax_pct_chr = full_vax_pct,
    is_blurred = grepl("^>", full_vax_pct),
    full_vax_pct = suppressWarnings(as.numeric(stringr::str_extract(full_vax_pct, "[0-9.]+"))),
    total_enrollment = enroll_mmreligible
  ) %>%
  dplyr::filter(!is.na(total_enrollment)) %>%
  dplyr::mutate(
    full_vax_pct = dplyr::if_else(full_vax_pct > 100, 100, full_vax_pct, full_vax_pct)
  )

# ---------- Build Cases Table ----------
case_table <- measles_cases %>%
  dplyr::mutate(county = stringr::str_to_title(county)) %>%
  dplyr::arrange(county, year, age_group)

# ---------- Keep the county dropdown in sync with selected table ----------
observeEvent(input$table_type, {
  
  all_counties <- sort(unique(stringr::str_to_title(counties$county_name)))
  
  current_selection <- input$gt_selected_county
  
  if (input$table_type == "Historical Measles Cases") {
    
    new_choices <- c("Statewide", all_counties)
    
    if (!is.null(current_selection) && current_selection %in% new_choices) {
      new_selected <- current_selection
    } else {
      new_selected <- "Statewide"
    }
    
    updateSelectInput(
      session,
      "gt_selected_county",
      choices = new_choices,
      selected = new_selected
    )
    
  } else {
    
    if (!is.null(current_selection) && current_selection %in% all_counties) {
      new_selected <- current_selection
    } else {
      new_selected <- all_counties[1]
    }
    
    updateSelectInput(
      session,
      "gt_selected_county",
      choices = all_counties,
      selected = new_selected
    )
  }
})

# ---------- Render GT Summary Table ----------
output$summary_table <- gt::render_gt({
  req(input$table_type, input$gt_selected_county)
  
  table_to_use <- switch(
    input$table_type,
    "School Vaccine Coverage" = school_table,
    "Child Care Vaccine Coverage" = daycare_table,
    "Historical Measles Cases"   = case_table
  )
  
  filtered_data <- if (input$table_type == "Historical Measles Cases" && input$gt_selected_county == "Statewide") {
    table_to_use %>%
      dplyr::group_by(year, age_group) %>%
      dplyr::summarise(n_cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(county = "Statewide")
  } else {
    table_to_use %>%
      dplyr::filter(county == input$gt_selected_county)
  }
  
  if (nrow(filtered_data) == 0) {
    return(gt::gt(data.frame(Message = "No historical cases for selected county")))
  }
  if (input$table_type == "Historical Measles Cases") {
    
    # Define all age groups that should always appear
    all_age_groups <- c("0–4", "5–11", "12–19", "20–49", "50+", "Unknown")
    
    wide_cases <- filtered_data %>%
      mutate(
        county = as.character(county),   # <- ensures statewide survives
        age_group = gsub("-", "–", age_group),
        age_group = factor(age_group, levels = all_age_groups, ordered = TRUE)
      ) %>%
      
      # ---- EXPAND to include all age groups for every county-year ----
    tidyr::complete(
      county,
      year,
      age_group = all_age_groups,
      fill = list(n_cases = 0)
    ) %>%
      
      group_by(county, year, age_group) %>%
      summarise(total_cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
      
      # Pivot wider to table format
      tidyr::pivot_wider(
        names_from  = age_group,
        values_from = total_cases,
        values_fill = 0
      ) %>%
      arrange(year) %>%
      
      # Reorder columns so they always appear in same order
      select(
        county,
        year,
        all_of(all_age_groups[all_age_groups %in% names(.)])
      )
    
    return(
      wide_cases %>%
        gt::gt() %>%
        gt::tab_header(
          title = if (input$gt_selected_county == "Statewide") {
            "Measles Cases by Year and Age Group"
          } else {
            paste("Measles Cases by Year and Age Group: County of", input$gt_selected_county)
          }
          )
      %>%
        gt::tab_style(
          style = gt::cell_text(
            color = "#1E3A66",
            weight = "bold",
            size = "large"
          ),
          locations = gt::cells_title(groups = "title")
        ) %>%
        
        gt::cols_label(
          county = "County",
          year   = "Year",
          `0–4`   = "0–4 Years",
          `5–11`  = "5–11 Years",
          `12–19` = "12–19 Years",
          `20–49` = "20–49 Years",
          `50+`   = "50+ Years",
          Unknown = "Unknown"
        ) %>%
        
        gt::fmt_number(columns = -c(county, year), decimals = 0) %>%
        gt::cols_align(
          align = "center",
          columns = -c(county)
        ) %>%
        
        gt::data_color(
          columns = -c(county, year),
          fn = scales::col_numeric(
            palette = c("#FFF9E6", "#F9C941", "#1E3A66"),
            domain = c(0, max(wide_cases[, -c(1,2)], na.rm = TRUE))
          )
        ) %>%
        
        gt::tab_style(
          style = gt::cell_text(weight = "bold", color = "#1E3A66"),
          locations = gt::cells_column_labels(gt::everything())
        ) %>%
        
        gt::tab_options(
          table.width = gt::px(850),
          heading.align = "left",
          column_labels.background.color = "#F4E2A1",
          column_labels.font.weight = "bold",
          table.border.top.color = "#1E3A66",
          table.border.bottom.color = "#1E3A66",
          row.striping.background_color = "#FAFAFA",
          
          # Compact layout (these are safe)
          data_row.padding = gt::px(3),
          row_group.padding = gt::px(2)
        )
)
  }
  # === Schools / Daycares view ===
  sort_col <- if (!is.null(input$gt_sort_by) &&
                  input$table_type %in% c("School Vaccine Coverage",
                                          "Child Care Vaccine Coverage")) {
    input$gt_sort_by
  } else {
    "full_vax_pct"
  }
  
  # Guard: if sort_col not present, fall back
  if (!sort_col %in% names(filtered_data)) sort_col <- "full_vax_pct"
  
  # --- Sorting logic ---
  if (sort_col %in% c("name", "county")) {
    # Case-insensitive alphabetical sort
    sorted_data <- filtered_data %>%
      dplyr::arrange(tolower(.data[[sort_col]]))
  } else {
    # Numeric sorts: high → low
    sorted_data <- filtered_data %>%
      dplyr::arrange(dplyr::desc(.data[[sort_col]]))
  }
  
  # --- Build the gt table ---
  table_gt <- sorted_data %>%
    gt::gt() %>%
    gt::tab_header(
      title = paste(input$table_type, "Vaccination Summary:", input$gt_selected_county)
    ) %>%
    # Keep the ">" sign in the displayed values
    gt::fmt(
      columns = full_vax_pct,
      fns = function(x) sorted_data$full_vax_pct_chr
    ) %>%
    # Apply custom color logic
    gt::data_color(
      columns = full_vax_pct,
      fn = function(x) {
        out <- rep("gray", length(x))
        chr <- sorted_data$full_vax_pct_chr
        
        out[grepl("^>", chr)] <- "darkgreen"                     # blurred (">95", ">98")
        out[!grepl("^>", chr) & !is.na(x) & x < 85] <- "red"
        out[!grepl("^>", chr) & !is.na(x) & x >= 85 & x < 90] <- "orange"
        out[!grepl("^>", chr) & !is.na(x) & x >= 90 & x < 95] <- "gold"
        out[!grepl("^>", chr) & !is.na(x) & x >= 95] <- "darkgreen"
        out
      }
    ) %>%
    gt::cols_hide(columns = full_vax_pct_chr)
  
  if (input$table_type == "School Vaccine Coverage") {
    table_gt <- table_gt %>%
      gt::cols_label(
        county           = "County",
        name             = "School Name",
        full_vax_pct     = "MMR %",
        total_enrollment = "Enrollment"
      )
    
  } else if (input$table_type == "Child Care Vaccine Coverage") {
    
    table_gt <- table_gt %>%
      gt::fmt(
        columns = full_vax_pct,
        fns = function(x) {
          ifelse(is.na(sorted_data$full_vax_pct_chr),
                 "Data redacted",
                 sorted_data$full_vax_pct_chr)
        }
      ) %>%
      gt::cols_hide(columns = c(is_blurred)) %>%
      gt::cols_label(
        county           = "County",
        name             = "Child Care Name",
        full_vax_pct     = "MMR %",
        total_enrollment = "MMR Eligible"
      ) %>%
      gt::tab_source_note(
        source_note = "MMR coverage is not displayed for facilities with fewer than 10 enrolled children."
      )
  }
  
  table_gt
})

# ---------- Epicurve (MADMC color theme) ----------
output$epi_curve <- renderPlot({
  req(input$table_type == "Historical Measles Cases", input$gt_selected_county)
  
  all_years <- sort(unique(measles_cases$year))
  min_year  <- min(all_years, na.rm = TRUE)
  max_year  <- max(all_years, na.rm = TRUE)
  
  county_years <- data.frame(year = seq(min_year, max_year, by = 1))
  base_df <- measles_cases %>%
    dplyr::mutate(county = stringr::str_to_title(county))
  
  county_cases <- if (input$gt_selected_county == "Statewide") {
    base_df %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
      dplyr::right_join(county_years, by = "year") %>%
      dplyr::mutate(cases = tidyr::replace_na(cases, 0L))
  } else {
    base_df %>%
      dplyr::filter(county == input$gt_selected_county) %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
      dplyr::right_join(county_years, by = "year") %>%
      dplyr::mutate(cases = tidyr::replace_na(cases, 0L))
  }
  
  ggplot2::ggplot(county_cases, ggplot2::aes(x = year, y = cases)) +
    # --- Navy bars with soft edges ---
    ggplot2::geom_col(width = 0.75, fill = "#1E3A66") +
    # --- Yellow labels for readability ---
    ggplot2::geom_text(
      ggplot2::aes(label = ifelse(cases > 0, cases, "")),
      vjust = -0.5, size = 4.5, color = "black", fontface = "bold"
    ) +
    ggplot2::labs(
      x = "Year",
      y = "Number of Cases"
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(min_year, max_year, 1),
      expand = ggplot2::expansion(add = 0.3)
    ) +
    ggplot2::scale_y_continuous(
      breaks = scales::pretty_breaks(n = 8),
      labels = scales::label_number(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.15))
    ) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.title       = ggplot2::element_text(hjust = 0.5, face = "bold", color = "#1E3A66"),
      axis.title.x     = ggplot2::element_text(face = "bold", color = "#1E3A66"),
      axis.title.y     = ggplot2::element_text(face = "bold", color = "#1E3A66"),
      axis.text        = ggplot2::element_text(color = "#1E3A66"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank()
    )
})