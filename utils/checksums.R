
#### CALCULATE CONTROL CHARACTER ####

calculate_finnish_pid_control <- function(birth_date, individual_number) {
  # Input validation
  if (is.null(birth_date) || is.null(individual_number)) {
    stop("Birth date and individual number must not be NULL")
  }
  
  # Handle Date object or character string
  if (inherits(birth_date, "Date")) {
    birth_date_str <- format(birth_date, "%d%m%y")
  } else if (is.character(birth_date)) {
    # Try to parse the date if it's in YYYY-MM-DD format
    tryCatch({
      parsed_date <- as.Date(birth_date, format = "%Y-%m-%d")
      birth_date_str <- format(parsed_date, "%d%m%y")
    }, error = function(e) {
      stop("Invalid birth date format. Expected 'YYYY-MM-DD'")
    })
  } else {
    stop("Birth date must be a Date object or character string in format 'YYYY-MM-DD'")
  }
  
  # Clean and validate individual number
  ind_num <- gsub("[^0-9]", "", individual_number)
  
  if (nchar(ind_num) != 3) {
    stop("Individual number must contain exactly 3 digits")
  }
  
  # Convert to numeric for calculation
  combined_num <- as.numeric(paste0(birth_date_str, ind_num))
  
  # Calculate the remainder when divided by 31
  remainder <- combined_num %% 31
  
  # Map the remainder to a control character using the valid characters
  control_chars <- "0123456789ABCDEFHJKLMNPRSTUVWXY"
  
  # Remainder is 0-based index into the control characters string
  # Add 1 for 1-based indexing in R
  control_char <- substr(control_chars, remainder + 1, remainder + 1)
  
  return(control_char)
}


#### VALIDATE PID ####

validate_finnish_pid <- function(pin) {
  # Basic format check
  if (!grepl("^\\d{6}[\\-+ABCDEFYXWVU]\\d{3}[0-9A-Z]$", pin)) {
    return(FALSE)
  }
  
  # Extract parts of the PIN
  date_part <- substr(pin, 1, 6)
  separator <- substr(pin, 7, 7)
  individual_part <- substr(pin, 8, 10)
  control_char_given <- substr(pin, 11, 11)
  
  # Parse date based on separator
  year_prefix <- switch(separator,
                        "-" = "19",
                        "+" = "18",
                        "A" = "20",
                        "B" = "20",
                        "C" = "20",
                        "D" = "20",
                        "E" = "20",
                        "F" = "20",
                        "Y" = "19",
                        "X" = "19",
                        "W" = "19",
                        "V" = "19",
                        "U" = "19",
                        "19") # Default to 19 for any unhandled separators
  
  day <- as.integer(substr(date_part, 1, 2))
  month <- as.integer(substr(date_part, 3, 4))
  year <- as.integer(paste0(year_prefix, substr(date_part, 5, 6)))
  
  # Check if the date is valid
  tryCatch({
    date_obj <- as.Date(sprintf("%04d-%02d-%02d", year, month, day))
    if (is.na(date_obj)) {
      return(FALSE)
    }
  }, error = function(e) {
    return(FALSE)
  })
  
  # Special handling to reconvert date to required format
  birth_date_str <- sprintf("%04d-%02d-%02d", year, month, day)
  
  # Calculate the expected control character
  expected_control_char <- calculate_finnish_pid_control(birth_date_str, individual_part)
  
  # Compare with the provided control character
  return(control_char_given == expected_control_char)
}

### GENERATE PID ####

generate_finnish_pid <- function(birth_date, individual_number, century = "-") {
  # Input validation
  if (is.null(birth_date) || is.null(individual_number)) {
    stop("Birth date and individual number must not be NULL")
  }
  
  # Handle Date object or character string
  if (inherits(birth_date, "Date")) {
    birth_date_str <- format(birth_date, "%d%m%y")
    full_year <- as.integer(format(birth_date, "%Y"))
  } else if (is.character(birth_date)) {
    # Try to parse the date if it's in YYYY-MM-DD format
    tryCatch({
      parsed_date <- as.Date(birth_date, format = "%Y-%m-%d")
      birth_date_str <- format(parsed_date, "%d%m%y")
      full_year <- as.integer(format(parsed_date, "%Y"))
    }, error = function(e) {
      stop("Invalid birth date format. Expected 'YYYY-MM-DD'")
    })
  } else {
    stop("Birth date must be a Date object or character string in format 'YYYY-MM-DD'")
  }
  
  # Clean and validate individual number
  ind_num <- gsub("[^0-9]", "", individual_number)
  
  if (nchar(ind_num) != 3) {
    stop("Individual number must contain exactly 3 digits")
  }
  
  # Validate and auto-determine century if not provided
  valid_centuries <- c("+", "-", "A", "B", "C", "D", "E", "F", "Y", "X", "W", "V", "U")
  
  if (!century %in% valid_centuries) {
    stop("Invalid century separator. Must be one of: ", 
         paste(valid_centuries, collapse = ", "))
  }
  
  # Auto-determine century if default is used
  if (century == "-" && full_year < 1900) {
    century <- "+"
  } else if (century == "-" && full_year >= 2000) {
    century <- "A"
  }
  
  # Calculate control character
  control_char <- calculate_finnish_pid_control(birth_date, ind_num)
  
  # Construct the complete PID
  pid <- paste0(birth_date_str, century, ind_num, control_char)
  
  return(pid)
}