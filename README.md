# Midwest EpiView: Measles

## Table of Contents

- [Project Description](#project-description)
- [Intended Use Cases and Limitations](#intended-use-cases-and-limitations)
- [Repository Structure](#repository-structure)
- [Expected Input Data Structure](#expected-input-data-structure)
- [Running the Dashboard Locally](#running-the-dashboard-locally)
- [Adapting the Dashboard for Another State](#adapting-the-dashboard-for-another-state)
- [Deployment](#deployment)
- [Organization & Funding](#organization--funding)
- [Contact](#contact)
- [License](#license)

## Project Description

The original Midwest EpiView: Measles project is an interactive dashboard for visualizing measles vaccination coverage and historical measles case data across Minnesota. This repository contains the necessary code for adapting this dashboard to different states and different vaccine coverage. 

Midwest EpiView: Measles was developed by the [Midwest Analytics and Disease Modeling Center (MADMC)](https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/) at the University of Minnesota School of Public Health. It is built in **R** using the **Shiny** framework and integrates vaccination, geographic, and historical case data into a set of interactive maps and tables to support exploratory public health analysis and outreach.

Although the dashboard was originally built with Minnesota-specific datasets, the framework can be adapted by other states or jurisdictions using equivalent local data sources.

Key features include:
- County-level MMR vaccination coverage maps
- School-level vaccination coverage visualization
- Child care vaccination coverage visualization
- Grade-level vaccination breakdowns for schools
- Historical measles case visualization by county, year, and age group
- Proximity search tool for identifying nearby facilities below selected vaccination thresholds
- Interactive tables and filtering tools

## Intended Use Cases and Limitations
This dashboard is intended as a data exploration and visualization tool for understanding patterns in measles vaccination coverage and historical measles case counts across Minnesota.

Possible use cases include:
- Public health planning and outreach
- Identifying geographic areas with lower vaccination coverage
- Exploring historical measles trends

Limitations include:
- Vaccination data are based on annual immunization reports submitted by schools and child care facilities and may be incomplete for some locations.
- Grade-level vaccination coverage may be redacted when enrollment is below privacy thresholds.
- Case counts represent reported measles cases by county and year and should not be interpreted as real-time surveillance data.


## Repository Structure

### App Core

| File | Description |
|------|-------------|
| `ui.R` | Defines dashboard layout, navigation tabs, maps, tables, and input controls |
| `server.R` | Coordinates server-side logic and initializes dashboard modules |
| `packages_and_data.R` | Loads required R packages and app-ready datasets |

### Data Cleaning

| File | Description |
|------|-------------|
| `data_wrangling_for_app.R` | Main preprocessing and dataset preparation script |

### Server Code (Shiny modules)

| File | Description |
|------|-------------|
| `county_level_map.R` | County-level vaccination and measles case map logic |
| `submap.R` | School and child care map rendering |
| `grade_details_module.R` | Grade-level vaccination tables and plots |
| `gt_table_module.R` | Summary tables |
| `measles_proximity_map.R` | Proximity search map functionality |
| `measles_proximity_table.R` | Proximity search table output |

### Functions

| File | Description |
|------|-------------|
| `combineSchoolDaycareData.R` | Combines school and child care datasets for proximity analysis |
| `add_point_offset.R` | Applies small coordinate offsets to overlapping map points |

## Expected Input Data Structure

The dashboard expects the following input datasets and fields. When adapting the dashboard, incoming data should be standardized to match this structure.

| Input Dataset | Important Fields Expected | Used For |
|---------------|---------------------------|----------|
| County vaccination data | `county`, `fips`<sup>a</sup>, `full_vax`, `full_vax_pct` | County-level vaccination coverage maps and summary statistics |
| County boundary shapefile | `NAME`, `GEOID`, `geometry` | County map polygons and geographic joins |
| School demographic data *(optional contextual dataset)* | `school_id`, `county_name`, `total_enrollment`, `total_students_of_color_or_american_indian_count`, `total_students_eligible_for_free_or_reduced_priced_meals_count` | County-level demographic aggregation and contextual summaries |
| Historical measles case data | `county`, `year`, `n_cases`, `age_group` | Historical measles case overlays, filtering, and summary tables |
| Child care vaccination data | `idsch`, `schname`, `full_vax`, `full_vax_pct`, `total_enroll`, `medical`<sup>b</sup>, `nonmedical`<sup>c</sup> | Child care vaccination maps, tables, and filtering |
| Child care location shapefile | `license_nu`, `name_of_pr`, `addresslin`, `geometry` | Joining child care vaccination records to mapped facility locations |
| School vaccination data | `school_id`, `schname`, `enroll`, `full_vax`, `partial_vax`, `medical`<sup>b</sup>, `nonmedical`<sup>c</sup>, `full_vax_pct`, `medical_pct`, `nonmedical_pct` | School-level vaccination maps, summaries, and popup displays |
| School ID crosswalk *(optional but recommended)* | `school_id`, `new_school_id` | Reconciling outdated or changed school identifiers across datasets |
| School location shapefile | `ORGTYPE`, `ORGNUMBER`, `SCHNUMBER`, `NAME`, `ADDR`, `COUNTYNAME`, `PUBPRIV`, `GRADERANGE`, `geometry` | Constructing school identifiers and mapping school locations |
| Grade-level vaccination data | `school_id`, `schname`, `disname`<sup>d</sup>, `grade`, `vacctype`, `full_vax`, `full_vax_pct` | Grade-level school vaccination charts and drilldown tables |

<sup>a</sup> FIPS = 2-digit identifier for US states

<sup>b</sup> Medical = Medical exemption from vaccination

<sup>c</sup> Nonmedical = Non medical exemption from vaccination

<sup>d</sup> Disname = School district name

## Running the Dashboard Locally

1. Clone or download the repository.
2. Open the `.Rproj` file in RStudio.
3. Prep data specific to location of interest using the format explained above
4. Run the dashboard:

   ```r
   shiny::runApp()
   ```

## Adapting the Dashboard for Another State

The framework can be adapted to another jurisdiction by following this general workflow:

1. **Obtain required datasets** to add to the app data.
2. **Standardize incoming datasets** to the structure expected by the application (see [Expected Input Data Structure](#expected-input-data-structure)).
3. **Replace input file paths** in the data wrangling module with jurisdiction-specific files.
     - Replace Minnesota shapefiles with local geographic boundary files.
     - Replace Minnesota vaccination datasets with local vaccination data.
     - Replace Minnesota measles case data with local historical case data.
4. **Run the data wrangling module** to clean the data and populate app-ready `.RData` into an App Data folder.
5. **Update labels, titles, and descriptive text** throughout the dashboard.
6. **Validate joins** between vaccination records and geographic datasets.
7. **Run the dashboard locally** for validation.
8. **Deploy** the application.

Most jurisdiction-specific customization occurs in:

- `data_wrangling_for_app.R`
- `packages_and_data.R`
- `ui.R`

## Deployment

The original dashboard was deployed using [ShinyApps.io](https://www.shinyapps.io/).

## Organization & Funding

**Organization**

Midwest Analytics and Disease Modeling Center (MADMC)

**Contributing Authors**

Team members at the University of Minnesota School of Public Health and Minnesota Department of Health

**More information**

<https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/>

**Funding**

This work was supported by cooperative agreement CDC-RFA-FT-23-0069 from the Center for Forecasting and Outbreak Analytics of the U.S. Centers for Disease Control and Prevention (CDC).

Its contents are solely the responsibility of the authors and do not necessarily represent the official views of the CDC.

## Contact

For questions, contact [madmc@umn.edu](mailto:madmc@umn.edu).

## License
MIT License

Copyright (c) 2022 Consortium of Infectious Disease Modeling Hubs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

