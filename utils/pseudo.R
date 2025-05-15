#' @title Pseudonymization Functions for GDPR Compliance
#' @description A comprehensive set of functions for pseudonymizing personal data under GDPR
#' @author Your Organization
#' @version 1.0.0

# Required packages - install them if not already available
required_pkgs <- c("openssl", "digest", "uuid", "R6")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  message("Installing required packages: ", paste(missing_pkgs, collapse = ", "))
  install.packages(missing_pkgs)
}

#' Create a pseudonymizer for GDPR-compliant data processing
#'
#' @param seed Optional seed for reproducible pseudonymization
#' @param store_mappings Whether to store original-to-pseudonym mappings
#' @param key_file Path to a file containing previously used keys (optional)
#' @param key_password Password to decrypt the key file (if provided)
#'
#' @return A list of functions for pseudonymizing data
#' @export
create_pseudonymizer <- function(seed = NULL, store_mappings = FALSE, 
                                 key_file = NULL, key_password = NULL) {
  # Use R6 internally but expose only function interface
  PseudonymizeData <- R6::R6Class(
    "PseudonymizeData",
    
    public = list(
      salt = NULL,
      key = NULL,
      iv = NULL,
      mappings = NULL,
      
      initialize = function(seed = NULL, store_mappings = FALSE) {
        if (!is.null(seed)) {
          set.seed(seed)
        }
        
        self$salt <- openssl::rand_bytes(32)
        self$key <- openssl::rand_bytes(32)
        self$iv <- openssl::rand_bytes(16)
        
        if (store_mappings) {
          self$mappings <- list()
        }
      },
      
      hash = function(data, prefix = "H_") {
        if (!is.vector(data)) {
          stop("Data must be a vector")
        }
        
        na_indices <- is.na(data)
        result <- character(length(data))
        
        if (all(na_indices)) {
          return(rep(NA_character_, length(data)))
        }
        
        data_to_hash <- data[!na_indices]
        hashed <- sapply(data_to_hash, function(x) {
          hash_val <- digest::hmac(as.character(x), key = self$salt, algo = "sha256")
          paste0(prefix, hash_val)
        })
        
        result[!na_indices] <- hashed
        result[na_indices] <- NA_character_
        
        if (!is.null(self$mappings)) {
          field_name <- deparse(substitute(data))
          if (!field_name %in% names(self$mappings)) {
            self$mappings[[field_name]] <- data.frame(
              original = data[!na_indices],
              pseudonym = hashed,
              stringsAsFactors = FALSE
            )
          } else {
            new_mappings <- data.frame(
              original = data[!na_indices],
              pseudonym = hashed,
              stringsAsFactors = FALSE
            )
            self$mappings[[field_name]] <- rbind(
              self$mappings[[field_name]],
              new_mappings[!new_mappings$original %in% self$mappings[[field_name]]$original, ]
            )
          }
        }
        
        return(result)
      },
      
      encrypt = function(data, prefix = "E_") {
        if (!is.vector(data)) {
          stop("Data must be a vector")
        }
        
        na_indices <- is.na(data)
        result <- character(length(data))
        
        if (all(na_indices)) {
          return(rep(NA_character_, length(data)))
        }
        
        data_to_encrypt <- as.character(data[!na_indices])
        encrypted <- sapply(data_to_encrypt, function(x) {
          enc <- openssl::aes_cbc_encrypt(charToRaw(x), key = self$key, iv = self$iv)
          paste0(prefix, openssl::base64_encode(enc))
        })
        
        result[!na_indices] <- encrypted
        result[na_indices] <- NA_character_
        
        if (!is.null(self$mappings)) {
          field_name <- deparse(substitute(data))
          if (!field_name %in% names(self$mappings)) {
            self$mappings[[field_name]] <- data.frame(
              original = data[!na_indices],
              pseudonym = encrypted,
              stringsAsFactors = FALSE
            )
          } else {
            new_mappings <- data.frame(
              original = data[!na_indices],
              pseudonym = encrypted,
              stringsAsFactors = FALSE
            )
            self$mappings[[field_name]] <- rbind(
              self$mappings[[field_name]],
              new_mappings[!new_mappings$original %in% self$mappings[[field_name]]$original, ]
            )
          }
        }
        
        return(result)
      },
      
      decrypt = function(encrypted_data, prefix = "E_") {
        if (!is.vector(encrypted_data)) {
          stop("Data must be a vector")
        }
        
        na_indices <- is.na(encrypted_data)
        result <- character(length(encrypted_data))
        
        if (all(na_indices)) {
          return(rep(NA_character_, length(encrypted_data)))
        }
        
        data_to_decrypt <- encrypted_data[!na_indices]
        
        if (!is.null(prefix) && prefix != "") {
          has_prefix <- startsWith(data_to_decrypt, prefix)
          if (any(has_prefix)) {
            data_to_decrypt[has_prefix] <- substring(data_to_decrypt[has_prefix], nchar(prefix) + 1)
          }
        }
        
        decrypted <- sapply(data_to_decrypt, function(x) {
          tryCatch({
            enc <- openssl::base64_decode(x)
            rawToChar(openssl::aes_cbc_decrypt(enc, key = self$key, iv = self$iv))
          }, error = function(e) {
            warning("Failed to decrypt value: ", x)
            NA_character_
          })
        })
        
        result[!na_indices] <- decrypted
        result[na_indices] <- NA_character_
        
        return(result)
      },
      
      randomize_ids = function(data, prefix = "ID_", consistent = TRUE) {
        if (!is.vector(data)) {
          stop("Data must be a vector")
        }
        
        na_indices <- is.na(data)
        result <- character(length(data))
        
        if (all(na_indices)) {
          return(rep(NA_character_, length(data)))
        }
        
        if (consistent) {
          unique_vals <- unique(data[!na_indices])
          id_map <- setNames(
            paste0(prefix, sprintf("%04d", seq_along(unique_vals))),
            unique_vals
          )
          result[!na_indices] <- id_map[as.character(data[!na_indices])]
        } else {
          result[!na_indices] <- paste0(prefix, sapply(seq_along(data[!na_indices]), 
                                                       function(x) uuid::UUIDgenerate()))
        }
        
        result[na_indices] <- NA_character_
        
        if (!is.null(self$mappings) && consistent) {
          field_name <- deparse(substitute(data))
          if (!field_name %in% names(self$mappings)) {
            self$mappings[[field_name]] <- data.frame(
              original = names(id_map),
              pseudonym = unname(id_map),
              stringsAsFactors = FALSE
            )
          } else {
            new_mappings <- data.frame(
              original = names(id_map),
              pseudonym = unname(id_map),
              stringsAsFactors = FALSE
            )
            self$mappings[[field_name]] <- rbind(
              self$mappings[[field_name]],
              new_mappings[!new_mappings$original %in% self$mappings[[field_name]]$original, ]
            )
          }
        }
        
        return(result)
      },
      
      save_mappings = function(file_path, password) {
        if (is.null(self$mappings)) {
          stop("No mappings are being stored. Initialize with store_mappings = TRUE.")
        }
        
        serialized <- serialize(self$mappings, NULL)
        password_key <- openssl::sha256(charToRaw(password))
        encrypted <- openssl::aes_cbc_encrypt(serialized, key = password_key, iv = self$iv)
        
        con <- file(file_path, "wb")
        on.exit(close(con))
        
        # Write header with version and IV
        writeBin(as.raw(c(0x01, 0x00)), con) # Version 1.0
        writeBin(self$iv, con)
        writeBin(encrypted, con)
        
        # Also save the keys
        key_data <- list(
          salt = self$salt,
          key = self$key,
          iv = self$iv
        )
        
        serialized_keys <- serialize(key_data, NULL)
        encrypted_keys <- openssl::aes_cbc_encrypt(serialized_keys, key = password_key, iv = self$iv)
        
        key_file <- paste0(file_path, ".keys")
        key_con <- file(key_file, "wb")
        on.exit(close(key_con), add = TRUE)
        
        writeBin(as.raw(c(0x01, 0x00)), key_con) # Version 1.0
        writeBin(self$iv, key_con)
        writeBin(encrypted_keys, key_con)
        
        return(TRUE)
      },
      
      load_mappings = function(file_path, password) {
        if (!file.exists(file_path)) {
          stop("Mapping file does not exist: ", file_path)
        }
        
        con <- file(file_path, "rb")
        on.exit(close(con))
        
        version <- readBin(con, "raw", n = 2)
        if (!identical(version, as.raw(c(0x01, 0x00)))) {
          stop("Unsupported mapping file version")
        }
        
        iv <- readBin(con, "raw", n = 16)
        encrypted <- readBin(con, "raw", n = file.info(file_path)$size - 18)
        
        password_key <- openssl::sha256(charToRaw(password))
        tryCatch({
          decrypted <- openssl::aes_cbc_decrypt(encrypted, key = password_key, iv = iv)
          self$mappings <- unserialize(decrypted)
          self$iv <- iv
          
          # Try to load the keys
          key_file <- paste0(file_path, ".keys")
          if (file.exists(key_file)) {
            key_con <- file(key_file, "rb")
            on.exit(close(key_con), add = TRUE)
            
            key_version <- readBin(key_con, "raw", n = 2)
            if (!identical(key_version, as.raw(c(0x01, 0x00)))) {
              warning("Unsupported key file version, not loading keys")
              return(TRUE)
            }
            
            key_iv <- readBin(key_con, "raw", n = 16)
            key_encrypted <- readBin(key_con, "raw", n = file.info(key_file)$size - 18)
            
            key_decrypted <- openssl::aes_cbc_decrypt(key_encrypted, key = password_key, iv = key_iv)
            key_data <- unserialize(key_decrypted)
            
            self$salt <- key_data$salt
            self$key <- key_data$key
            self$iv <- key_data$iv
          }
          
          return(TRUE)
        }, error = function(e) {
          stop("Failed to decrypt mappings. Is the password correct?")
        })
      },
      
      pseudonymize_dataframe = function(df, columns) {
        if (!is.data.frame(df)) {
          stop("Input must be a data frame")
        }
        
        if (!is.list(columns) || is.null(names(columns))) {
          stop("Columns must be a named list")
        }
        
        result <- df
        
        for (col_name in names(columns)) {
          if (!col_name %in% names(df)) {
            warning("Column not found in data frame: ", col_name)
            next
          }
          
          method <- columns[[col_name]]
          if (method == "hash") {
            result[[col_name]] <- self$hash(df[[col_name]])
          } else if (method == "encrypt") {
            result[[col_name]] <- self$encrypt(df[[col_name]])
          } else if (method == "randomize") {
            result[[col_name]] <- self$randomize_ids(df[[col_name]])
          } else {
            warning("Unknown pseudonymization method: ", method)
          }
        }
        
        return(result)
      }
    )
  )
  
  # Initialize the internal pseudonymizer
  pseudonymizer <- PseudonymizeData$new(seed = seed, store_mappings = store_mappings)
  
  # Load previous keys if specified
  if (!is.null(key_file) && file.exists(key_file) && !is.null(key_password)) {
    tryCatch({
      pseudonymizer$load_mappings(key_file, key_password)
    }, error = function(e) {
      warning("Failed to load keys: ", e$message)
    })
  }
  
  # Return a list of functions that delegate to the pseudonymizer
  return(list(
    hash = function(data, prefix = "H_") {
      pseudonymizer$hash(data, prefix)
    },
    
    encrypt = function(data, prefix = "E_") {
      pseudonymizer$encrypt(data, prefix)
    },
    
    decrypt = function(encrypted_data, prefix = "E_") {
      pseudonymizer$decrypt(encrypted_data, prefix)
    },
    
    randomize_ids = function(data, prefix = "ID_", consistent = TRUE) {
      pseudonymizer$randomize_ids(data, prefix, consistent)
    },
    
    pseudonymize_dataframe = function(df, columns) {
      pseudonymizer$pseudonymize_dataframe(df, columns)
    },
    
    save_mappings = function(file_path, password) {
      pseudonymizer$save_mappings(file_path, password)
    },
    
    load_mappings = function(file_path, password) {
      pseudonymizer$load_mappings(file_path, password)
    }
  ))
}