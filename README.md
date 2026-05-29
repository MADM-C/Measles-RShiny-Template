Midwest EpiView: Measles Dashboard
----------------------------------

Table of Contents
-
Project Description

Intended Use Cases and Limitations

To run the dashboard locally

Project Structure

Organization Information

Additional Information

License

--------------------
Project Description 
- 
Midwest EpiView: Measles is an interactive dashboard developed by the Midwest Analytics and Disease Modeling Center (MADMC) to visualize measles vaccination coverage and historical measles case data across Minnesota.

The dashboard integrates public datasets from the Minnesota Department of Health (MDH), the Minnesota Department of Education (MDE), and the Minnesota Geospatial Commons to provide geographic insight into vaccination coverage and potential outbreak risk.

Key features include:

• County-level MMR vaccination coverage mapping

• Facility-level vaccination data for schools and child care centers

• Grade-level vaccination coverage for schools

• Historical measles case visualization by county, year, and age group

• A proximity search tool to identify nearby facilities with lower vaccination coverage

The application is built in R using the Shiny framework and combines spatial data, vaccination records, and demographic information to support exploratory public health analysis.

The codebase includes scripts for cleaning and standardizing vaccination data, linking vaccination records to geographic shapefiles, and generating datasets used by the dashboard.

--------------------


Intended Use Cases and Limitations
---------
This dashboard is intended as a data exploration and visualization tool for understanding patterns in measles vaccination coverage and historical measles case counts across Minnesota.

Possible use cases include:
-
• Public health planning and outreach

• Identifying geographic areas with lower vaccination coverage

• Exploring historical measles trends

• Demonstrating the importance of herd immunity thresholds

Limitations include:
-
• Vaccination data are based on annual immunization reports submitted by schools and child care facilities and may be incomplete for some locations.

• Grade-level vaccination coverage may be redacted when enrollment is below privacy thresholds.

• Case counts represent reported measles cases by county and year and should not be interpreted as real-time surveillance data.

This tool is intended for exploratory and educational use, not clinical or operational decision-making.
Installation and Run Guide

------------------------------
To run the dashboard locally:
--

1. Clone the repository

2. Install required R packages

3. Prepare app data according to specifications

4. Run the application

--------------------

Project Structure
-----------------
The repository contains the Shiny application code along with scripts used to prepare and organize the datasets used by the dashboard.

Key files include:
--
ui.R -> Defines the user interface for the Shiny dashboard, including navigation tabs, maps, tables, and input controls.

server.R -> Coordinates server-side logic and initializes the dashboard modules.

packages_and_data.R -> Loads required R packages and the preprocessed datasets used by the dashboard.

data_wrangling_for_app.R -> Script used to clean, standardize, and merge vaccination datasets with geographic shapefiles before creating the .RData objects used by the app.
 
Shiny Modules: The application uses modular Shiny components to organize major dashboard features.
--

county_level_map.R -> Creates the county-level vaccination coverage map and overlays historical measles cases.

submap.R -> Displays school and child care vaccination coverage within a selected county.

grade_details_module.R -> Generates grade-level vaccination tables and plots for individual schools.

gt_table_module.R -> Creates summary tables for vaccination coverage and historical measles cases.

measles_proximity_map.R -> Implements the proximity search tool to identify nearby facilities with lower vaccination coverage.

measles_proximity_table.R -> Displays facilities identified by the proximity search tool.
 
Utility Scripts
--

add_point_offset.R -> Applies a micro-offset to facility coordinates to prevent overlapping map markers.

combineSchoolDaycareData.R -> Combines school and child care datasets used by the proximity analysis module.
 
Project Configuration
--

renv/ -: Manages project-specific package versions for reproducibility.

renv.lock -> Defines the exact package versions required to reproduce the environment.

.Rprofile -> Automatically activates the renv environment when the project is opened.
Public Measles Dashboard.Rproj
RStudio project configuration file.
 
Deployment 
--

www/ -> Folder for static assets used by the Shiny application (e.g., logos or images) that will appear .

Documentation
--

README.md -> Project overview and instructions for installing and running the dashboard.


--------------------

Organization Information
-- 

Organization: 
Midwest Analytics and Disease Modeling Center (MADMC)
University of Minnesota School of Public Health

Contributing Authors:
Midwest Analytics and Disease Modeling Center research team

More information:
https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/

--------------------


Funding:
--

This work was supported by cooperative agreement CDC-RFA-FT-23-0069 from the Center for Forecasting and Outbreak Analytics of the U.S. Centers for Disease Control and Prevention (CDC).

Its contents are solely the responsibility of the authors and do not necessarily represent the official views of the CDC.

Contact:
madmc@umn.edu

--------------------

License
-- 
MIT License

Copyright (c) 2022 Consortium of Infectious Disease Modeling Hubs

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
