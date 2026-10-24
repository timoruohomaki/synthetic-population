# Create environment to store logger configuration

if (!exists("logger_env", envir = .GlobalEnv)) {
  assign("logger_env", new.env(), envir = .GlobalEnv)
  logger_env$log_dir <- "logs"    # Default log directory
  logger_env$log_file <- "application.log"
  logger_env$log_to_console <- FALSE
  logger_env$initialized <- FALSE
  logger_env$log_level <- "INFO"  # Default level
}

# Define log levels and their hierarchy
LOG_LEVELS <- list(
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4
)

#' Initialize the logger with specific settings
#' 
#' @param log_dir Directory for log files
#' @param log_file Name of the log file (relative to log_dir)
#' @param append Whether to append to an existing log file or create a new one
#' @param log_to_console Whether to also log messages to the console
#' @param level Minimum log level to record (DEBUG, INFO, WARN, ERROR)
#' @return Invisibly returns TRUE on success
initialize_logger <- function(log_dir = "logs",
                              log_file = "application.log", 
                              append = TRUE, 
                              log_to_console = FALSE,
                              level = "INFO") {
  
  # Validate log level
  level <- toupper(level)
  if (!level %in% names(LOG_LEVELS)) {
    warning("Invalid log level specified. Using INFO as default.")
    level <- "INFO"
  }
  
  # Store configuration in environment
  logger_env$log_dir <- log_dir
  logger_env$log_file <- log_file
  logger_env$log_to_console <- log_to_console
  logger_env$log_level <- level
  
  # Create log directory if it doesn't exist
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Create full file path
  full_log_path <- file.path(log_dir, log_file)
  
  # Create or clear the log file if not appending
  if (!append) {
    tryCatch({
      file.create(full_log_path, showWarnings = FALSE)
    }, error = function(e) {
      warning(paste("Could not create log file:", e$message))
    })
  }
  
  # Write header to log file
  log_entry <- paste0(
    "==========================================================\n",
    "Log started at ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
    "R version: ", R.version$version.string, "\n",
    "Platform: ", R.version$platform, "\n",
    "Working directory: ", getwd(), "\n",
    "Log directory: ", normalizePath(log_dir), "\n",
    "Log file: ", log_file, "\n",
    "Log level: ", level, "\n",
    "==========================================================\n"
  )
  
  tryCatch({
    cat(log_entry, file = full_log_path, append = append)
    logger_env$initialized <- TRUE
  }, error = function(e) {
    warning(paste("Could not write to log file:", e$message))
    logger_env$initialized <- FALSE
  })
  
  return(invisible(logger_env$initialized))
}

#' Internal function to write a log entry to file
#' 
#' @param level The log level (INFO, WARN, ERROR, DEBUG)
#' @param message The message to log
#' @return Invisibly returns TRUE on success
log_to_file <- function(level, message) {
  if (!logger_env$initialized) {
    # Initialize with defaults if not already initialized
    initialize_logger()
  }
  
  level <- toupper(level)
  
  # Check if we should log this level
  if (LOG_LEVELS[[level]] < LOG_LEVELS[[logger_env$log_level]]) {
    return(invisible(FALSE))
  }
  
  # Get configuration from environment
  log_dir <- logger_env$log_dir
  log_file <- logger_env$log_file
  full_log_path <- file.path(log_dir, log_file)
  log_to_console <- logger_env$log_to_console
  
  # Format the log entry
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] [%s] %s\n", timestamp, level, message)
  
  # Write to log file
  success <- tryCatch({
    cat(log_entry, file = full_log_path, append = TRUE)
    TRUE
  }, error = function(e) {
    # If we can't write to the log file, output to console regardless of setting
    cat("Error writing to log file:", e$message, "\n")
    cat(log_entry)
    FALSE
  })
  
  # Also log to console if configured
  if (log_to_console && success) {
    cat(log_entry)
  }
  
  return(invisible(success))
}

#' Log a debug message
#' 
#' @param message The message to log
#' @return Invisibly returns TRUE on success
log_debug <- function(message) {
  log_to_file("DEBUG", message)
}

#' Log an informational message
#' 
#' @param message The message to log
#' @return Invisibly returns TRUE on success
log_info <- function(message) {
  log_to_file("INFO", message)
}

#' Log a warning message
#' 
#' @param message The message to log
#' @return Invisibly returns TRUE on success
log_warn <- function(message) {
  log_to_file("WARN", message)
}

#' Log an error message
#' 
#' @param message The message to log
#' @return Invisibly returns TRUE on success
log_error <- function(message) {
  log_to_file("ERROR", message)
}

#' Set whether to also log messages to the console
#' 
#' @param enabled TRUE to enable console logging, FALSE to disable
#' @return Invisibly returns the previous setting
set_console_logging <- function(enabled = TRUE) {
  previous <- logger_env$log_to_console
  logger_env$log_to_console <- enabled
  return(invisible(previous))
}

#' Change the log file
#' 
#' @param log_file Name of the new log file (relative to current log_dir)
#' @param append Whether to append to an existing log file or create a new one
#' @return Invisibly returns the previous log file path
set_log_file <- function(log_file, append = TRUE) {
  previous <- logger_env$log_file
  logger_env$log_file <- log_file
  
  # Get current log directory
  log_dir <- logger_env$log_dir
  full_log_path <- file.path(log_dir, log_file)
  
  # Create or clear the log file if not appending
  if (!append) {
    tryCatch({
      file.create(full_log_path, showWarnings = FALSE)
    }, error = function(e) {
      warning(paste("Could not create log file:", e$message))
    })
  }
  
  return(invisible(previous))
}

#' Change the log directory
#' 
#' @param log_dir Path to the new log directory
#' @return Invisibly returns the previous log directory
set_log_dir <- function(log_dir) {
  previous <- logger_env$log_dir
  logger_env$log_dir <- log_dir
  
  # Create log directory if it doesn't exist
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  return(invisible(previous))
}

#' Set the complete log path (both directory and file)
#' 
#' @param log_path Full path to the log file
#' @param append Whether to append to an existing log file or create a new one
#' @return Invisibly returns a list with previous log_dir and log_file
set_log_path <- function(log_path, append = TRUE) {
  previous <- list(
    log_dir = logger_env$log_dir,
    log_file = logger_env$log_file
  )
  
  # Split path into directory and filename
  log_dir <- dirname(log_path)
  log_file <- basename(log_path)
  
  # Update both settings
  logger_env$log_dir <- log_dir
  logger_env$log_file <- log_file
  
  # Create directory if needed
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Create or clear the log file if not appending
  if (!append) {
    tryCatch({
      file.create(log_path, showWarnings = FALSE)
    }, error = function(e) {
      warning(paste("Could not create log file:", e$message))
    })
  }
  
  return(invisible(previous))
}

#' Set the minimum log level 
#' 
#' @param level New minimum log level (DEBUG, INFO, WARN, ERROR)
#' @return Invisibly returns the previous log level
set_log_level <- function(level) {
  level <- toupper(level)
  if (!level %in% names(LOG_LEVELS)) {
    warning("Invalid log level specified. Not changing current level.")
    return(invisible(logger_env$log_level))
  }
  
  previous <- logger_env$log_level
  logger_env$log_level <- level
  
  return(invisible(previous))
}

#' Close the logger and perform any cleanup
#' 
#' @return Invisibly returns TRUE
close_logger <- function() {
  if (logger_env$initialized) {
    tryCatch({
      log_info("Logger closed")
    }, error = function(e) {
      # Ignore errors when closing
    })
  }
  
  return(invisible(TRUE))
}

#' Get the current full log path
#' 
#' @return The full path to the current log file
get_log_path <- function() {
  file.path(logger_env$log_dir, logger_env$log_file)
}

#' Flush any buffered log messages to disk
#' 
#' @return Invisibly returns TRUE
flush_logger <- function() {
  # In this implementation, logs are written immediately
  # so no additional flushing is needed
  return(invisible(TRUE))
}