# singularity run --app Rscript init/singularity-r.simg production/post_run.R
rm(list=ls())
library(tidyverse)
source("./R/utilities.R")

# Sync raw, extracted, and log files 
sync_remote_files(TRUE)
Sys.sleep(2*60)

# Generate and sync diagnostics 
generate_diagnostics()
sync_diagnostic_files()

# Write latest csv 
write_latest_data()
