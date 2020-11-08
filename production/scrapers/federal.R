source("./R/generic_scraper.R")
source("./R/utilities.R")

federal_pull <- function(x){
    url_list <- list(
        final = "https://www.bop.gov/coronavirus/json/final.json",
        rrc = "https://www.bop.gov/coronavirus/data/rrc.json",
        add = "https://www.bop.gov/coronavirus/data/additional.json",
        loc = "https://www.bop.gov/coronavirus/data/locations.json",
        test = "https://www.bop.gov/coronavirus/json/inmateTestInfo.json"
    )
    
    lapply(url_list, function(z) jsonlite::read_json(z, simplifyVector = TRUE))
}

federal_restruct <- function(x){

    bind_rows(
        full_join(
            as_tibble(x$test$rrcTesting) %>%
                mutate(id = str_extract(facilityName, "\\(([^)]+)\\)")) %>%
                mutate(id = str_remove_all(id, "\\(|\\)")),
        
            as_tibble(x$final$rrcData) %>%
                select(-contractNum) %>%
                mutate(id = str_to_upper(id)),
            by = "id") %>%
            mutate(Name = str_c("RRC - ", id)) %>%
            select(
                Name, completedTest, pendTest, posTest, inmateDeathAmt,
                inmateDeathHcon, inmateRecoveries, inmatePositiveAmt,
                staffPositiveAmt, staffRecoveries, staffDeathAmt),
    
        as_tibble(x$test$bopTesting) %>%
            rename(id = facilityCode) %>%
            full_join(as_tibble(x$final$bopData), by = "id") %>%
            bind_rows(as_tibble(x$final$privateData)) %>%
            left_join(
                as_tibble(x$loc$Locations) %>%
                    select(id = code, Name = nameTitle),
                by = "id"
            ) %>%
            select(-id) %>%
            mutate(inmateDeathHcon = 0)
    )
    
}

federal_extract <- function(x){
    x %>%
        select(
            Name,
            Residents.Confirmed = posTest,
            Staff.Deaths = staffDeathAmt, Residents.Deaths = inmateDeathAmt, 
            Staff.Recovered = staffRecoveries,
            Residents.Recovered = inmateRecoveries,
            Residents.Tested = completedTest,
            Residents.Pending = pendTest)
}

#' Scraper class for general federal COVID data
#' 
#' @name federal_scraper
#' @description Federal data comes from an api that reports information for
#' official federal prisons, private facilities contracted out by federal
#' government, and rrc facilities i.e. recovery rehabilitation centers. RRC
#' data does not have detailed facility data only a city location. Not mentioned
#' here is the location data that is available for all facilities including
#' information on the kind of facility like max or min security and sex of
#' residents. 
#' \describe{
#'   \item{id}{The facility id}
#'   \item{staffPositiveAmt}{staff active cases}
#'   \item{staffRecoveries}{staff recoveries}
#'   \item{staffDeathAmt}{staff deaths}
#'   \item{inmatePositiveAmt}{Residents active cases}
#'   \item{inmateDeathAmt}{residents deaths}
#'   \item{inmateRecoveries}{cumulative residents recovered}
#'   \item{inmateCompletedTest}{Tests adminstered, I think not individuals tested}
#'   \item{inmatePendTest}{Current Pending Cases}
#'   \item{inmatePosTest}{Cumulative Positive Cases}
#' }

federal_scraper <- R6Class(
    "federal_scraper",
    inherit = generic_scraper,
    public = list(
        log = NULL,
        initialize = function(
            log,
            url = "https://www.bop.gov/coronavirus/",
            id = "federal",
            type = "json",
            state = "federal",
            # pull the JSON data directly from the API
            pull_func = federal_pull,
            # restructuring the data means pulling out the data portion of the json
            restruct_func = federal_restruct,
            # Rename the columns to appropriate database names
            extract_func = federal_extract){
            super$initialize(
                url = url, id = id, pull_func = pull_func, type = type,
                restruct_func = restruct_func, extract_func = extract_func,
                log = log, state = state)
        }
    )
)

if(sys.nframe() == 0){
    federal <- federal_scraper$new(log=TRUE)
    federal$raw_data
    federal$pull_raw()
    federal$raw_data
    federal$save_raw()
    federal$restruct_raw()
    federal$restruct_data
    federal$extract_from_raw()
    federal$extract_data
    federal$validate_extract()
    federal$save_extract()
}
