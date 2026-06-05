# ============================================================
# PACKAGE AND DATA INITIALIZATION
# ============================================================
# This script loads all required R packages and data objects
# used throughout the dashboard. It is sourced at the start of
# the application to ensure that dependencies, datasets, and
# shared objects (e.g., color palettes) are available to both
# the UI and server components.
#
# Data Sources Loaded:
# • County-level vaccination coverage
# • School vaccination data
# • Child care vaccination data
# • Grade-level vaccination data
# • Religious and tutoring center locations (used in proximity analysis)
#
# Shared Objects Created:
# • pal_county – color palette used to display county-level
#   MMR vaccination coverage on maps.
# ============================================================


###### Necessary R Packages for Dashboard
library(shiny)
library(leaflet)
library(dplyr)
library(sf)
library(tigris)
library(readr)
library(stringr)
library(readxl)
library(gt)
library(ggplot2)
library(DT)
library(osmdata)
library(leaflet.extras)
library(openxlsx)
library(tidygeocoder)

load("App Data/county_vaccine_data.RData")

load("App Data/daycare_vaccine_data.RData")

load("App Data/grade_level_vaccine_data.RData")

load("App Data/school_vaccine_data.RData")

# ==== Palette ====
pal_county <- colorBin(
  palette = c("red", "orange", "gold", "darkgreen"),
  bins = c(0, 85, 90, 95, 100),
  domain = county_map_data$full_vax_pct,
  na.color = "gray"
)
