#taken from https://www.pauloldham.net/importing-excel-data-into-r-updated/

readxl_online <- function(url, type = NULL, ...) {
    test <- stringr::str_detect(url, "[.]xls|[.]zip")
    if (test == FALSE) {
        print(message("Expecting file extension of type .xlsx, .xls or .zip. Check the URL or the data source for the correct file extension and use the type argument"))
    }
    # test for individual file extensions for xls use look forward, xls not
    # followed by x
    t1 <- stringr::str_detect(url, "[.]xlsx")
    t2 <- stringr::str_detect(url, "[.]xls(?!x)")
    tz <- stringr::str_detect(url, "[.]zip")
    if (t1 == TRUE) {
        type = ".xlsx"
    }
    if (t2 == TRUE) {
        type = ".xls"
    }
    if (tz == TRUE) {
        httr::GET(url, write_disk("tmp.zip", overwrite = TRUE))
        tmp <- unzip("tmp.zip")
        # On osx more than one file name is returned, select first element.
        df <- readxl::read_excel(tmp[[1]])
        return(df)
    }
    if (!is.null(type)) {
        type = type
        
    }
    df <- httr::GET(url, write_disk(paste0("tmp", type), overwrite = TRUE))
    df <- readxl::read_excel(paste0("tmp", type))
    #file.remove('tmp.xls')
}
