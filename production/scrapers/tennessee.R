source("./R/generic_scraper.R")
source("./R/utilities.R")

tennessee_pull <- function(x){
    get_src_by_attr(
        x, "a", attr = "href", attr_regex = "TDOCInmatesCOVID19.pdf$")
}

tennessee_restruct <- function(x){
    extract <- tabulizer::extract_tables(x)
}

tennessee_extract <- function(x){
    
    col_name_mat <- matrix(c(
        "Name", "V1", "By Location",
        "Residents.Tadmin", "V2", "#Tested",
        "Residents.Active", "V3", "#Positive",
        "Residents.Negative", "V4", "#Negative",
        "Residents.Pending", "V5", "Pending",
        "Residents.Recovered", "V6", "Recovered",
        "Residents.Deaths", "V7", "Deaths"
    ), ncol = 3, nrow = 7, byrow = TRUE)
    
    colnames(col_name_mat) <- c("clean", "raw", "check")
    col_name_df <- as_tibble(col_name_mat)
    
    tab1 <- x[[1]][4:nrow(x[[1]]),]
    # remove columns that are all empty
    df_ <- as.data.frame(tab1[,apply(tab1, 2, function(x) !all(x == ""))])
    
    check_names_extractable(df_, col_name_df)
    fac_df <- rename_extractable(df_, col_name_df) %>%
        filter(!str_detect(Name, "(?i)region|managed|location|total")) %>%
        filter(Name != "") %>%
        clean_scraped_df() %>%
        as_tibble() %>% 
        mutate(Residents.Deaths = ifelse(
            is.na(Residents.Deaths), 0, Residents.Deaths)) 
    
    col_name_mat2 <- matrix(c(
        "Name", "V1", "TESTING NUMBERS",
        "Staff.Confirmed", "V2", "# Positive COVID-19 Tests",
        "Staff.Recovered", "V3", "# Positive Return To Work",
        "Staff.Deaths", "V4", "Deaths"
    ), ncol = 3, nrow = 4, byrow = TRUE)
    
    colnames(col_name_mat2) <- c("clean", "raw", "check")
    col_name_df2 <- as_tibble(col_name_mat2)
    
    tab2 <- as.data.frame(t(x[[2]]))
    
    check_names_extractable(tab2, col_name_df2)
    rename_extractable(tab2, col_name_df2) %>%
        filter(!str_detect(Name, "(?i)testing|total")) %>%
        clean_scraped_df() %>%
        as_tibble() %>%
        full_join(fac_df, by = "Name") %>%
        mutate(Residents.Confirmed = Residents.Active + Residents.Deaths +
                   Residents.Recovered)
}

#' Scraper class for general Tennessee COVID data
#' 
#' @name tennessee_scraper
#' @description Data is pulled from a pdf at a static location that is
#' updated. We need to find better documentation on what variables mean.
#' \describe{
#'   \item{Location}{The facility name}
#'   \item{Residents Tested}{Tests administred not actually residents tested}
#'   \item{Residents Positive}{Seems to be active rather than cumulative positive}
#'   \item{Residents Negative}{Negative tests not residents negative}
#'   \item{Residents Pending}{Residents currently pending}
#'   \item{Residents Recovered}{Residents recovered}
#'   \item{Residents Deaths}{Residents deaths}
#'   \item{Staff confirmed}{cant tell if cumulative}
#'   \item{Staff returned to work}{seems to be recovered}
#'   \item{Staff Deaths}{Staff deaths}
#' }

tennessee_scraper <- R6Class(
    "tennessee_scraper",
    inherit = generic_scraper,
    public = list(
        log = NULL,
        initialize = function(
            log,
            url = "https://www.tn.gov/correction.html",
            id = "tennessee",
            type = "pdf",
            state = "TN",
            jurisdiction = "state",
            # pull the JSON data directly from the API
            pull_func = tennessee_pull,
            # restructuring the data means pulling out the data portion of the json
            restruct_func = tennessee_restruct,
            # Rename the columns to appropriate database names
            extract_func = tennessee_extract){
            super$initialize(
                url = url, id = id, pull_func = pull_func, type = type,
                restruct_func = restruct_func, extract_func = extract_func,
                log = log, state = state, jurisdiction = jurisdiction)
        }
    )
)

if(sys.nframe() == 0){
    tennessee <- tennessee_scraper$new(log=TRUE)
    tennessee$raw_data
    tennessee$pull_raw()
    tennessee$raw_data
    tennessee$save_raw()
    tennessee$restruct_raw()
    tennessee$restruct_data
    tennessee$extract_from_raw()
    tennessee$extract_data
    tennessee$validate_extract()
    tennessee$save_extract()
}

