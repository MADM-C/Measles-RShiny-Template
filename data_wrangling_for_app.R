# ============================================================
# DATA PREPARATION SCRIPT – MEASLES / MMR DASHBOARD (TEMPLATE)
# ============================================================
#
# Purpose
# -------
# This script prepares and cleans the datasets used by the
# Midwest EpiView: Measles dashboard. It merges vaccination
# records with geographic shapefiles, reconciles facility
# identifiers, and produces the standardized objects the Shiny
# app expects.
#
# ADAPTING THIS SCRIPT TO ANOTHER STATE
# -------------------------------------
# This was built for Minnesota data, but it is intended as a
# template. Almost everything that is state-specific has been
# lifted into the CONFIG block below. To adapt it:
#
#   1. Set STATE and the input file paths in CONFIG.
#   2. Replace the ID-format and organization-filter values in
#      CONFIG with your state's conventions (see notes there).
#   3. Remap your raw column names to the names this script
#      expects (see the "Expected input columns" notes in CONFIG
#      and the README data-format section).
#
# The app itself only cares about the OUTPUT objects and their
# columns (see "OUTPUT CONTRACT" in CONFIG). However your raw
# data is shaped, the goal is to produce those objects with
# those columns.
#
# Input data files are NOT included in this repository. The
# `data/` folder must be supplied separately from your state's
# public health / education / geospatial sources.
#
# Data Sources (Minnesota example)
# --------------------------------
# • Minnesota Department of Health (MDH) immunization reports
# • Minnesota Department of Education (MDE) program location
#   shapefiles
# • Minnesota Geospatial Commons county boundaries
#
# ============================================================

library(tidyverse)
library(sf)
library(tigris)
library(readxl)


# ============================================================
# CONFIG — EDIT THIS BLOCK FOR YOUR STATE
# ============================================================

# ---- State ----
# Two-letter postal abbreviation, used to pull county boundaries
# from the Census (via tigris). NOTE: tigris downloads from the
# Census API at runtime, so this step requires internet access.
STATE       <- "MN"
COUNTY_YEAR <- 2022   # Census TIGER/Line vintage for county shapes

# ---- Input file paths ----
# All inputs live under data/. Replace with your state's files. 
# See README for the required format of each file.

PATH_COUNTY_MMR    <- "data/mmr_county2526.csv"
PATH_DEMOGRAPHICS  <- "data/demographics_school_2026.csv"
PATH_MEASLES_CASES <- "data/measles_cleaned_2025.xlsx"
PATH_DAYCARE_MMR   <- "data/mmr_cc_final2526.csv"
PATH_DAYCARE_SHP   <- "data/shapefile_unzipped/econ_child_care.shp"
PATH_SCHOOL_MMR    <- "data/mmr_school_fina2526.csv"
PATH_SCHOOL_SHP    <- "data/Shapefiles/shp_struc_school_program_locs/school_program_locations.shp"
PATH_GRADE_MMR     <- "data/mmr_grade_final2526.csv"
PATH_ID_CROSSWALK  <- "data/new_orgid.xlsx"   # optional old->new ID map; set to NA to skip

# ---- Output directory ----
# The app loads .RData files from here. 
OUT_DIR <- "App Data"

# ---- Facility ID format (STATE-SPECIFIC) ----
# Minnesota builds a 12-digit school ID from shapefile fields as:
#   ORGTYPE(2) + ORGNUMBER(4) + SCHNUMBER(3) + "000" = 12 chars
# Your state almost certainly uses a different identifier scheme.
# Adjust ID_PAD_WIDTH and the id-construction step in the school
# section below to match how YOUR vaccination records and YOUR
# location shapefile can be made to share a common key.
ID_PAD_WIDTH <- 12

# ---- Organization / program filters (STATE-SPECIFIC) ----
# These select which records in the MN school location shapefile
# count as in-scope K-12 schools (vs. districts, libraries, early
# childhood, etc.). The codes below are Minnesota MDE codes and
# will NOT mean anything in another state — replace with your own
# in-scope criteria, or remove the filter entirely if not needed.
ORGTYPE_KEEP  <- c("01","03","06","07","31","32","33","34","52","61","70","83")
CLASS_EXCLUDE <- c(60, 82, 83, 84, 85, 90)   # MN class codes to drop, if a CLASS column exists


# ============================================================
# OUTPUT CONTRACT — what the Shiny app requires
# ============================================================
# The app sources these objects from the four .RData files and
# reads the columns listed. Adapt freely upstream, but the final
# objects must provide these:
#
#   county_map_data   : county_lower, county_name, full_vax,
#                       full_vax_pct, total_enrollment,
#                       students_of_color, frl_eligible, geometry
#   measles_cases     : county, year, n_cases, age_group
#   counties          : county_lower, county_name, fips, geometry
#   daycare_joined    : daycare_name, idsch, COUNTYNAME,
#                       full_vax, full_vax_pct, enroll_mmreligible,
#                       geometry
#   school_demo_joined: school_name, school_id, COUNTYNAME,
#                       GRADERANGE, full_vax, full_vax_pct,
#                       total_enrollment, geometry
#   mmr_grade         : school_id, grade, full_vax_pct
#
# Coverage values may be numeric or "blurred" strings (e.g. ">95");
# the app handles both. Small-cell suppression / blurring should be
# applied to the SAVED data, not only at display time.
# ============================================================


# ---------- helper functions ----------
normalize_id <- function(x) {
  # keep digits only, set "" -> NA, then left-pad to ID_PAD_WIDTH
  x <- gsub("[^0-9]", "", as.character(x))
  x[nchar(x) == 0] <- NA
  x <- ifelse(is.na(x), NA, stringr::str_pad(x, width = ID_PAD_WIDTH, pad = "0"))
  x
}

# Report how many rows are missing a join key, so silent drops are visible.
report_join <- function(df, key, label) {
  message(sprintf("[join] %s: %d rows, %d missing %s",
                  label, nrow(df), sum(is.na(df[[key]])), key))
  invisible(df)
}


# ==== County Vaccination Data ====
county_mmr <- read_csv(PATH_COUNTY_MMR) %>%
  mutate(county = tolower(county), fips = as.character(fips))

# County boundaries (downloads from Census at runtime; needs internet)
counties <- counties(state = STATE, cb = TRUE, year = COUNTY_YEAR) %>%
  st_transform(4326) %>%
  mutate(county_lower = tolower(NAME), county_name = NAME, fips = GEOID)

county_map_data_pre <- counties %>%
  left_join(county_mmr, by = c("county_lower" = "county", "fips" = "fips"))

# ==== County-Level Demographics ====
demographics_school <- read_csv(PATH_DEMOGRAPHICS) %>%
  mutate(school_id = as.character(school_id))

# Keep only the total-school row per facility. ASSUMPTION: the row
# with the largest enrollment is the school total (vs. a grade or
# program sub-row). Verify this holds for your source format.
demographics_school_collapsed <- demographics_school %>%
  group_by(school_id) %>%
  slice_max(total_enrollment, n = 1, with_ties = FALSE) %>%
  ungroup()

# Aggregate to county level
county_demo <- demographics_school_collapsed %>%
  mutate(county = str_to_lower(str_replace(county_name, " County", ""))) %>%
  group_by(county) %>%
  summarise(
    total_enrollment  = sum(total_enrollment, na.rm = TRUE),
    students_of_color = sum(total_students_of_color_or_american_indian_count, na.rm = TRUE),
    frl_eligible      = sum(total_students_eligible_for_free_or_reduced_priced_meals_count, na.rm = TRUE),
    .groups = "drop"
  )

county_map_data <- county_map_data_pre %>%
  left_join(county_demo, by = c("county_lower" = "county")) %>%
  select(
    county_lower, county_name,
    full_vax, full_vax_pct,
    total_enrollment, students_of_color, frl_eligible,
    geometry
  )

# Measles case data
measles_cases <- read_excel(PATH_MEASLES_CASES) %>%
  mutate(
    county    = tolower(gsub(" County", "", county)),
    year      = as.integer(year),
    n_cases   = as.integer(n_cases),
    age_group = as.character(age_group)
  )

dir.create(OUT_DIR, showWarnings = FALSE)
save(county_map_data, measles_cases, counties,
     file = file.path(OUT_DIR, "county_vaccine_data.RData"))


# ==== Daycare / Child Care Data ====
daycarecsv <- read_csv(PATH_DAYCARE_MMR) %>%
  mutate(idsch = as.character(idsch))

# Child care location shapefile. Field names (License_Nu, Name_of_Pr,
# AddressLin) are truncated shapefile column names specific to the MN
# source — rename to match your shapefile's fields.
childcare_sf <- st_read(PATH_DAYCARE_SHP) %>%
  st_transform(4326) %>%
  mutate(idsch = as.character(License_Nu))

daycare_joined <- daycarecsv %>%
  left_join(
    select(childcare_sf, idsch, geometry, Name_of_Pr, AddressLin),
    by = "idsch"
  ) %>%
  report_join("idsch", "daycare + locations") %>%
  st_as_sf(sf_column_name = "geometry", crs = st_crs(childcare_sf)) %>%
  st_join(
    counties %>% select(county_lower, COUNTYNAME = county_name),
    join = st_within, left = TRUE
  ) %>%
  mutate(
    # Disambiguate facilities that share a name by appending address
    daycare_name = str_to_title(
      ifelse(
        duplicated(Name_of_Pr) | duplicated(Name_of_Pr, fromLast = TRUE),
        paste(Name_of_Pr, AddressLin, sep = " - "),
        Name_of_Pr
      )
    ),
    full_vax_pct_num = readr::parse_number(full_vax_pct)
  ) %>%
  select(-c(city, county, schname, Name_of_Pr, AddressLin))

save(daycare_joined, file = file.path(OUT_DIR, "daycare_vaccine_data.RData"))


# ==== School Vaccine / Enrollment + shapefile ====
schoolcsv <- read_csv(PATH_SCHOOL_MMR) %>%
  mutate(
    school_id_raw = as.character(school_id),
    school_id     = normalize_id(school_id_raw)
  )

# Optional old -> new ID crosswalk. Set PATH_ID_CROSSWALK <- NA to skip.
if (!is.na(PATH_ID_CROSSWALK)) {
  id_map <- read_excel(PATH_ID_CROSSWALK) %>%
    transmute(
      old_id = normalize_id(school_id),
      new_id = normalize_id(new_school_id)
    ) %>%
    filter(!is.na(old_id), old_id != "", !is.na(new_id), new_id != "")
} else {
  id_map <- tibble(old_id = character(), new_id = character())
}

remap_ids <- function(df) {
  df %>%
    left_join(id_map, by = c("school_id" = "old_id")) %>%
    mutate(school_id = coalesce(new_id, school_id)) %>%
    select(-new_id)
}

schoolcsv <- remap_ids(schoolcsv)

# School location shapefile. The id-construction below is the
# STATE-SPECIFIC step: MN concatenates padded org/school codes into
# a single key. Replace this with whatever lets your shapefile share
# a key with your vaccination records.
school_sf <- st_read(PATH_SCHOOL_SHP) %>%
  st_transform(4326) %>%
  mutate(
    ORGTYPE   = str_pad(ORGTYPE,   2, pad = "0"),
    ORGNUMBER = str_pad(ORGNUMBER, 4, pad = "0"),
    SCHNUMBER = str_pad(SCHNUMBER, 3, pad = "0"),
    school_id = paste0(ORGTYPE, ORGNUMBER, SCHNUMBER, "000")
  ) %>%
  remap_ids() %>%
  # In-scope filter (STATE-SPECIFIC codes — see CONFIG)
  filter(
    ORGTYPE %in% ORGTYPE_KEEP,
    SCHNUMBER != "000",
    is.na(GRADERANGE) | toupper(GRADERANGE) != "EC-PK",
    !str_detect(tolower(NAME), "district|library")
  ) %>%
  {
    if ("CLASS" %in% names(.)) {
      filter(., is.na(CLASS) | !(CLASS %in% CLASS_EXCLUDE))
    } else .
  }

# FINAL join — keep only schools with both an MMR record and a location.
# NOTE: inner_join silently drops schools missing from either side. If
# your IDs don't reconcile cleanly, expect facilities to disappear here;
# the count below makes that visible.
school_joined <- inner_join(school_sf, schoolcsv, by = "school_id")
message(sprintf("[join] school MMR + locations: %d schools matched", nrow(school_joined)))

school_joined <- school_joined %>%
  mutate(full_vax_pct_num = as.numeric(stringr::str_extract(full_vax_pct, "[0-9.]+")))

# Standardized school object the app consumes (see OUTPUT CONTRACT).
school_demo_joined <- school_joined %>%
  mutate(
    school_name = str_to_title(
      ifelse(
        duplicated(NAME) | duplicated(NAME, fromLast = TRUE),
        paste(NAME, ADDR, sep = " - "),
        NAME
      )
    )
  ) %>%
  select(
    school_name, PUBPRIV, GRADERANGE, COUNTYNAME, school_id,
    enroll, full_vax, partial_vax, nonmedical, medical, full_vax_pct,
    nonmedical_pct, medical_pct, school_id_raw, full_vax_pct_num,
    total_enrollment = enroll,   # app reads total_enrollment
    geometry, ADDR
  )

save(school_demo_joined, file = file.path(OUT_DIR, "school_vaccine_data.RData"))


# ==== Grade-Level MMR Data ====
mmr_grade <- read_csv(PATH_GRADE_MMR) %>%
  filter(vacctype == "MMR") %>%
  mutate(
    school_id_raw = as.character(school_id),
    school_id     = normalize_id(school_id_raw)
  ) %>%
  remap_ids()

save(mmr_grade, file = file.path(OUT_DIR, "grade_level_vaccine_data.RData"))