source("./R/generic_scraper.R")
source("./R/utilities.R")

california_population_pull <- function(x){
    stop_defunct_scraper(x)
}

california_population_restruct <- function(x, exp_date = Sys.Date()){
    
    # Read date from top-left corner of page 
    date <- x %>% 
        magick::image_read_pdf(pages = 1) %>% 
        magick::image_crop("400x100+100+250") %>% 
        magick::image_ocr() %>% 
        lubridate::mdy()
    
    error_on_date(date, exp_date)
    
    magick::image_read_pdf(x, pages = 2) %>% 
        ExtractTable()
}

california_population_extract <- function(x){
    col_name_mat <- matrix(c(
        "Institutions", "X0", "Name", 
        "Felon/ Other", "X1", "Residents.Population", 
        "Design Capacity", "X2", "Capacity.Drop", 
        "Percent Occupied", "X3", "Percent.Occupied.Drop", 
        "Staffed Capacity", "X4", "Staffed.Capacity.Drop"
    ), ncol = 3, nrow = 5, byrow = TRUE)
    
    colnames(col_name_mat) <- c("check", "raw", "clean")
    col_name_df <- as_tibble(col_name_mat)
    
    df_ <- as.data.frame(x)
    
    check_names_extractable(df_, col_name_df)
    
    rename_extractable(df_, col_name_df) %>% 
        as_tibble() %>% 
        filter(!Name %in% c("Institutions", "Male Institutions", "Female Institutions")) %>% 
        filter(!str_detect(Name, "(?i)Total")) %>% 
        mutate_at(vars(-Name), string_to_clean_numeric) %>%
        select(-ends_with(".Drop")) %>% 
        
        # CA reports population for men and women separately for mixed facilities
        # Sum these at the facility-level 
        group_by(Name) %>% 
        summarise(Residents.Population = sum(Residents.Population)) %>% 
        ungroup() %>% 
        
        clean_scraped_df() 
}

#' Scraper class for California population data 
#' 
#' @name california_population_scraper
#' @description CDCR posts weekly population reports in PDF form. In addition to 
#' facility-level population, these reports also report Design Capacity, Percent
#' Occupied, and Staffed Capacity, which are not scraped for now. These reports are 
#' posted on Thursdays (with data as of midnight the previous night) and archived. 
#' \describe{
#'   \item{Felon/Other}{Residents.Population}
#'   \item{Design Capacity}{}
#'   \item{Percent Occupied}{}
#'   \item{Staffed Capacity}{}
#' }

california_population_scraper <- R6Class(
    "california_population_scraper",
    inherit = generic_scraper,
    public = list(
        log = NULL,
        initialize = function(
            log,
            url = "https://www.cdcr.ca.gov/research/population-reports-2/",
            id = "california_population",
            type = "pdf",
            state = "CA",
            jurisdiction = "state",
            pull_func = california_population_pull,
            restruct_func = california_population_restruct,
            extract_func = california_population_extract){
            super$initialize(
                url = url, id = id, pull_func = pull_func, type = type,
                restruct_func = restruct_func, extract_func = extract_func,
                log = log, state = state, jurisdiction  = jurisdiction)
        }
    )
)

if(sys.nframe() == 0){
    california_population <- california_population_scraper$new(log=TRUE)
    california_population$raw_data
    california_population$pull_raw()
    california_population$raw_data
    california_population$save_raw()
    california_population$restruct_raw()
    california_population$restruct_data
    california_population$extract_from_raw()
    california_population$extract_data
    california_population$validate_extract()
    california_population$save_extract()
}
