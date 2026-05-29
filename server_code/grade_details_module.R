# grade_details_module.R

# ============================================================
# GRADE DETAILS MODULE (Facility-Level Detail Panel)
# ============================================================
#
# Purpose
# -------
# This module renders the detailed information panel for the
# selected facility (school or child care). It displays grade-
# level MMR vaccination data for schools, along with enrollment
# totals and overall vaccination coverage. For child care
# facilities, grade-level information is not available, so a
# simplified message is displayed instead.
#
# Core Features
# -------------
# • Displays grade-level vaccination coverage for the selected
#   school in both a table and a bar chart.
# • Shows overall school-level enrollment and total MMR coverage.
# • Handles privacy redactions where grade-level enrollment is
#   fewer than 10 students.
# • Formats blurred vaccination values (e.g., ">95%") for both
#   table display and chart rendering.
# • Provides a searchable dropdown selector for schools and
#   child cares within the currently selected county.
#
# Data Inputs
# -----------
# selected_school_id
#   Shared reactive value that stores the ID of the currently
#   selected facility. This value is updated by the submap module
#   when users click a facility marker or select a location.
#
# school_demo_joined
#   School-level dataset containing enrollment totals and overall
#   vaccination coverage.
#
# daycare_joined
#   Dataset containing child care vaccination information used
#   primarily for the location selector.
#
# mmr_grade
#   Dataset containing grade-level vaccination coverage for
#   individual schools.
#
# format_vax_pct
#   Helper function used to format vaccination percentages for
#   consistent display across tables, charts, and popups.
#
# Reactive Inputs Used
# --------------------
# input$selected_location
#   Facility selected in the dropdown menu.
#
# input$selected_county
#   Used to populate the dropdown with schools and child cares
#   from the currently selected county.
#
# input$point_type
#   Determines whether the dropdown lists schools, child cares,
#   or both.
#
# Outputs
# -------
# output$grade_table
#   Table showing grade-level MMR vaccination coverage.
#
# output$grade_plot
#   Horizontal bar chart visualizing grade-level vaccination
#   coverage.
#
# output$grade_output
#   Combined UI panel displaying facility name, enrollment,
#   vaccination summary, and grade-level details.
#
# output$school_daycare_selector
#   Searchable dropdown menu allowing users to select a school
#   or child care facility within the selected county.
#
# Reactive Flow
# -------------
# Facility selected on submap or dropdown
#        ↓
# selected_school_id updated
#        ↓
# grade-level data pulled from mmr_grade
#        ↓
# table + bar chart rendered
#        ↓
# enrollment and coverage summary displayed
#
# ============================================================

gradeDetailsServer <- function(input, output, session,
                               selected_school_id,
                               school_demo_joined,
                               daycare_joined,
                               mmr_grade,
                               format_vax_pct) {
  
  # === Table of Grade-Level MMR for Selected School ==== 
  output$grade_table <- renderTable({
    
    school_id <- selected_school_id()
    
    if (is.null(school_id) && !is.null(input$selected_location)) {
      school_id <- school_demo_joined %>%
        filter(school_name == input$selected_location) %>%
        pull(mde_school_id) %>%
        .[1]
    }
    
    req(school_id)
    
    mmr_grade %>%
      filter(mde_school_id == school_id) %>%
      select(grade, full_vax_pct) %>%
      mutate(
        grade = ifelse(grade == 0, "K", as.character(grade)),
        grade = factor(grade, levels = c("K", as.character(1:12))),
        full_vax_pct = dplyr::if_else(
          is.na(full_vax_pct) | full_vax_pct %in% c("", "NA"),
          "Data redacted (<10 enrolled)",
          format_vax_pct(full_vax_pct)
        )
      ) %>%
      arrange(grade) %>%
      rename(
        Grade = grade,
        `Vaccination Coverage` = full_vax_pct
      )
    
  })
  
  
  # === Grade-Level Bar Chart (NA-safe) ===
  output$grade_plot <- renderPlot({
    
    school_id <- selected_school_id()
    
    if (is.null(school_id) && !is.null(input$selected_location)) {
      school_id <- school_demo_joined %>%
        filter(school_name == input$selected_location) %>%
        pull(mde_school_id) %>%
        .[1]
    }
    
    req(school_id)
    
    data <- mmr_grade %>%
      filter(mde_school_id == school_id) %>%
      mutate(
        grade = ifelse(grade == 0, "K", as.character(grade)),
        grade = factor(grade, levels = c(as.character(12:1), "K")),
        
        value_raw = full_vax_pct,
        
        value_num = dplyr::case_when(
          grepl("^>\\s*95", full_vax_pct) ~ 95,
          grepl("^>\\s*98", full_vax_pct) ~ 98,
          grepl("^>\\s*99", full_vax_pct) ~ 99,
          TRUE ~ suppressWarnings(as.numeric(full_vax_pct))
        ),
        
        color = case_when(
          is.na(value_raw) ~ "gray",
          grepl("^>", value_raw) ~ "darkgreen",
          value_num < 85 ~ "red",
          value_num < 90 ~ "orange",
          value_num < 95 ~ "gold",
          value_num >= 95 ~ "darkgreen",
          TRUE ~ "gray"
        ),
        
        value_label = format_vax_pct(value_raw)
      )
    
    if (all(is.na(data$value_num))) return(NULL)
    
    ymax <- suppressWarnings(max(data$value_num, na.rm = TRUE))
    
    if (!is.finite(ymax)) return(NULL)
    
    ymax <- min(ymax + 10, 100)
    
    ggplot(data, aes(x = grade, y = value_num, fill = color)) +
      geom_col(width = 0.6) +
      scale_fill_identity() +
      coord_flip() +
      labs(
        x = "Grade",
        y = "MMR %"
      ) +
      theme(
        plot.title = element_text(hjust = 0.5, face = "bold", lineheight = 1.05)
      ) +
      theme_minimal(base_size = 14) +
      theme(
        plot.title = element_text(hjust = 0.5, face = "bold"),
        axis.title.y = element_text(vjust = 1.2),
        axis.title.x = element_text(vjust = -0.2)
      ) +
      geom_text(aes(label = value_label), hjust = -0.1, size = 4) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.20)))
    
  })
  
  
  # === UI: Display Grade Table and Demographics Together ===
  output$grade_output <- renderUI({
    
    school_id <- selected_school_id()
    
    if (is.null(school_id) && !is.null(input$selected_location)) {
      school_id <- school_demo_joined %>%
        filter(school_name == input$selected_location) %>%
        pull(mde_school_id) %>%
        .[1]
    }
    
    req(school_id)
    
    total_enrollment <- school_demo_joined %>%
      filter(mde_school_id == school_id) %>%
      summarise(total = sum(total_enrollment, na.rm = TRUE), .groups = "drop") %>%
      pull(total)
    
    is_school <- school_id %in% school_demo_joined$mde_school_id
    
    
    if (is_school) {
      
      overall_cov <- school_demo_joined %>%
        filter(mde_school_id == school_id) %>%
        pull(full_vax_pct) %>%
        .[1]
      
      grade_rows <- mmr_grade %>%
        filter(mde_school_id == school_id)
      
      all_grades_redacted <-
        nrow(grade_rows) > 0 &&
        all(is.na(grade_rows$full_vax_pct))
      
      
      if (!is.na(overall_cov) && all_grades_redacted) {
        
        tagList(
          
          tags$div(
            style = "white-space: normal; word-break: break-word; font-size: 18px; margin-bottom: 6px;",
            stringr::str_wrap(input$selected_location, width = 65)
          ),
          
          tags$p(
            strong("Total enrollment*: "),
            ifelse(is.na(total_enrollment), "N/A", total_enrollment)
          ),
          
          tags$p(
            strong("Schoolwide MMR coverage: "),
            ifelse(is.na(overall_cov), "N/A", paste0(overall_cov, "%")),
            style = "margin-top: -8px; margin-bottom: 12px;"
          ),
          
          tags$p(
            style = "margin-top: 10px; font-style: italic;",
            "Grade-level vaccination data are redacted because fewer than 10 students were enrolled in each grade. ",
            "The overall coverage reflects total reported students across all grades."
          )
          
        )
        
      } else {
        
        tagList(
          
          tags$div(
            style = "white-space: normal; word-break: break-word; font-size: 18px; margin-bottom: 6px;",
            stringr::str_wrap(input$selected_location, width = 65)
          ),
          
          tags$p(
            strong("Total enrollment*: "),
            ifelse(is.na(total_enrollment), "N/A", total_enrollment)
          ),
          
          tags$p(
            strong("Schoolwide MMR coverage: "),
            ifelse(is.na(overall_cov), "N/A", paste0(overall_cov, "%")),
            style = "margin-top: -8px; margin-bottom: 12px;"
          ),
          
          tags$div(
            style = "display: flex; flex-direction: row; gap: 20px;",
            tags$div(plotOutput("grade_plot", height = "250px", width = "350px")),
            tags$div(tableOutput("grade_table"))
          ),
          
          tags$p(
            HTML(
              paste0(
                "<em>",
                "Redacted indicates the number of eligible students was fewer than 10. Blurred values (e.g., '>95%') are intentionally rounded up for privacy.<br><br>",
                "*Enrollment counts may differ between MDH and MDE records.",
                "</em>"
              )
            )
          )
        )
        
      }
      
    } else {
      
      tags$p(em("No detailed grade-level data available for child cares."))
      
    }
    
  })
  
  
  # === UI: School/Daycare Selector ===
  output$school_daycare_selector <- renderUI({
    
    req(input$selected_county)
    
    location_choices <- if (input$point_type == "Schools") {
      
      school_demo_joined %>%
        filter(tolower(COUNTYNAME) == tolower(input$selected_county)) %>%
        pull(school_name) %>%
        unique() %>%
        sort()
      
    } else if (input$point_type == "Child Cares") {
      
      df <- daycare_joined %>%
        filter(
          tolower(COUNTYNAME) == tolower(input$selected_county),
          !is.na(idsch),
          !is.na(daycare_name)
        )
      
      location_choices <- setNames(as.character(df$idsch), df$daycare_name)
      location_choices <- location_choices[order(names(location_choices))]
      
    } else {  # Schools and Child Cares
      
      location_choices <- c(
        school_demo_joined %>%
          filter(tolower(COUNTYNAME) == tolower(input$selected_county)) %>%
          pull(school_name),
        daycare_joined %>%
          filter(tolower(COUNTYNAME) == tolower(input$selected_county)) %>%
          pull(daycare_name)
      ) %>%
        unique() %>%
        sort()
      
    }
    
    
    selectizeInput(
      inputId = "selected_location",
      label = "School/Child Care:",
      choices = c("", location_choices),
      selected = NULL,
      options = list(
        placeholder = 'Search school or child care...',
        maxOptions = 1000
      )
    )
    
  })
  
}