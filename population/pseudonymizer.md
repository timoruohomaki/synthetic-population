# GDPR Pseudonymizer for R

A robust, production-grade library for GDPR-compliant pseudonymization in R.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Example](#basic-example)
  - [Handling SSID and Other Sensitive Identifiers](#handling-ssid-and-other-sensitive-identifiers)
  - [Working with Multiple Datasets](#working-with-multiple-datasets)
  - [Saving and Loading Mapping Information](#saving-and-loading-mapping-information)
- [API Reference](#api-reference)
  - [create_pseudonymizer()](#create_pseudonymizer)
  - [hash()](#hash)
  - [encrypt()](#encrypt)
  - [decrypt()](#decrypt)
  - [randomize_ids()](#randomize_ids)
  - [pseudonymize_dataframe()](#pseudonymize_dataframe)
  - [save_mappings()](#save_mappings)
  - [load_mappings()](#load_mappings)
- [GDPR Compliance Notes](#gdpr-compliance-notes)
- [Performance Considerations](#performance-considerations)
- [License](#license)

## Overview

This library provides a comprehensive solution for pseudonymizing personal data in accordance with the EU General Data Protection Regulation (GDPR). It implements multiple pseudonymization techniques suitable for different types of personal data, balancing the need for data utility with privacy protection.

## Features

- **Multiple pseudonymization methods**:
  - One-way hashing: For identifiers that don't need to be reversed
  - Encryption: For data that may need to be reversed by authorized persons
  - Random IDs: For consistent pseudonymization across datasets
  
- **GDPR-compliant functionality**:
  - Secure key management using cryptographically strong methods
  - Mappings storage with password protection
  - Support for both pseudonymization and anonymization techniques
  
- **Production-ready design**:
  - Clean functional architecture
  - Robust error handling
  - Proper handling of NA values
  - Secure file operations for mappings

## Installation

```r
# Install required packages
install.packages(c("openssl", "digest", "uuid", "R6"))

# Source the pseudonymizer file
source("pseudonymize.R")
```

## Usage

### Basic Example

```r
# Load the pseudonymizer function
source("pseudonymize.R")

# Create a pseudonymizer instance
pseudonymizer <- create_pseudonymizer(store_mappings = TRUE)

# Example dataset with sensitive information
df <- data.frame(
  id = 1:5,
  name = c("John Doe", "Jane Smith", "Alice Johnson", "Bob Williams", "Eva Brown"),
  email = c("john@example.com", "jane@example.com", "alice@example.com", 
            "bob@example.com", "eva@example.com"),
  age = c(32, 28, 45, 37, 51),
  address = c("123 Main St", "456 Oak Ave", "789 Pine Rd", "101 Elm Blvd", "202 Cedar Ln"),
  income = c(52000, 78000, 65000, 48000, 95000),
  stringsAsFactors = FALSE
)

# Pseudonymize the data frame
pseudonymized_df <- pseudonymizer$pseudonymize_dataframe(
  df,
  columns = list(
    "name" = "hash",         # One-way pseudonymization
    "email" = "encrypt",     # Reversible pseudonymization
    "address" = "encrypt",   # Reversible pseudonymization
    "income" = "randomize"   # Consistent IDs for income ranges
  )
)

# View the pseudonymized data
print(pseudonymized_df)
```

### Handling SSID and Other Sensitive Identifiers

```r
# Load the pseudonymizer
source("pseudonymize.R")
pseudonymizer <- create_pseudonymizer(store_mappings = TRUE)

# Example dataset with sensitive information including SSID
df <- data.frame(
  id = 1:5,
  ssid = c("123-45-6789", "234-56-7890", "345-67-8901", "456-78-9012", "567-89-0123"),
  name = c("John Doe", "Jane Smith", "Alice Johnson", "Bob Williams", "Eva Brown"),
  email = c("john@example.com", "jane@example.com", "alice@example.com", 
            "bob@example.com", "eva@example.com"),
  age = c(32, 28, 45, 37, 51),
  address = c("123 Main St", "456 Oak Ave", "789 Pine Rd", "101 Elm Blvd", "202 Cedar Ln"),
  income = c(52000, 78000, 65000, 48000, 95000),
  stringsAsFactors = FALSE
)

# Pseudonymize the data frame
pseudonymized_df <- pseudonymizer$pseudonymize_dataframe(
  df,
  columns = list(
    "ssid" = "hash",         # One-way pseudonymization for SSID
    "name" = "hash",         # One-way pseudonymization
    "email" = "encrypt",     # Reversible pseudonymization
    "address" = "encrypt",   # Reversible pseudonymization
    "income" = "randomize"   # Consistent IDs for income ranges
  )
)

# View the pseudonymized data
print(pseudonymized_df)

# Example of how the SSID is protected
cat("Original SSID format: ", df$ssid[1], "\n")
cat("Pseudonymized SSID: ", pseudonymized_df$ssid[1], "\n")

# Demonstration of how the SSID can be consistently pseudonymized
# Create a new record with the same SSID
new_record <- data.frame(
  id = 6,
  ssid = "123-45-6789", # Same SSID as first record
  name = "John Doe Jr.",
  email = "johnjr@example.com",
  age = 25,
  address = "789 Side St",
  income = 42000,
  stringsAsFactors = FALSE
)

# Pseudonymize the new record
pseudonymized_new <- pseudonymizer$pseudonymize_dataframe(
  new_record,
  columns = list(
    "ssid" = "hash",
    "name" = "hash",
    "email" = "encrypt",
    "address" = "encrypt",
    "income" = "randomize"
  )
)

# Check if the pseudonymized SSID is the same for the same original SSID
cat("Does the same SSID produce the same pseudonym? ", 
    pseudonymized_df$ssid[1] == pseudonymized_new$ssid[1], "\n")
```

### Working with Multiple Datasets

```r
# Create another dataset with SSID and medical information
medical_data <- data.frame(
  ssid = c("123-45-6789", "234-56-7890", "345-67-8901"),
  diagnosis = c("Hypertension", "Diabetes", "Asthma"),
  medication = c("Lisinopril", "Metformin", "Albuterol"),
  stringsAsFactors = FALSE
)

# Pseudonymize the medical data using the same pseudonymizer
pseudonymized_medical <- pseudonymizer$pseudonymize_dataframe(
  medical_data,
  columns = list(
    "ssid" = "hash",
    "diagnosis" = "encrypt",
    "medication" = "encrypt"
  )
)

# Now we can join the datasets using the pseudonymized SSID
# This allows analysis without exposing the actual SSID
library(dplyr)

# Join the pseudonymized datasets
joined_data <- inner_join(
  pseudonymized_df %>% select(id, ssid, age),
  pseudonymized_medical %>% select(ssid, diagnosis, medication),
  by = "ssid"
)

# Show the joined data - we can analyze without exposing real identifiers
print(joined_data)

# Example of decrypting an encrypted field (like diagnosis) if necessary
decrypted_diagnosis <- pseudonymizer$decrypt(pseudonymized_medical$diagnosis)
print(data.frame(
  pseudonym = pseudonymized_medical$diagnosis,
  original = decrypted_diagnosis
))
```

### Saving and Loading Mapping Information

```r
# Save mappings for later re-identification (if needed)
pseudonymizer$save_mappings("secure_mappings.dat", password = "strong-password-here")

# Later, in another script or session, load the same mappings
restored_pseudonymizer <- create_pseudonymizer(
  key_file = "secure_mappings.dat", 
  key_password = "strong-password-here",
  store_mappings = TRUE
)

# This will produce the same pseudonyms for the same inputs
original_hashed_ssid <- pseudonymizer$hash(df$ssid[1])
restored_hashed_ssid <- restored_pseudonymizer$hash(df$ssid[1])

# Should be TRUE - same pseudonym is produced
identical(original_hashed_ssid, restored_hashed_ssid)
```

## API Reference

### create_pseudonymizer()

Creates a new pseudonymizer instance.

```r
pseudonymizer <- create_pseudonymizer(
  seed = NULL,             # Optional seed for reproducible pseudonymization
  store_mappings = FALSE,  # Whether to store original-to-pseudonym mappings
  key_file = NULL,         # Path to a file containing previously used keys
  key_password = NULL      # Password to decrypt the key file
)
```

**Returns**: A list of functions for pseudonymizing data.

### hash()

Performs one-way pseudonymization using cryptographic hashing.

```r
pseudonymizer$hash(
  data,                    # Vector of data to be hashed
  prefix = "H_"            # Optional prefix for the hashed values
)
```

**Returns**: Vector of hashed values.

### encrypt()

Performs reversible pseudonymization using encryption.

```r
pseudonymizer$encrypt(
  data,                    # Vector of data to be encrypted
  prefix = "E_"            # Optional prefix for the encrypted values
)
```

**Returns**: Vector of encrypted values.

### decrypt()

Decrypts previously encrypted data.

```r
pseudonymizer$decrypt(
  encrypted_data,          # Vector of encrypted data
  prefix = "E_"            # Optional prefix to remove
)
```

**Returns**: Vector of decrypted values.

### randomize_ids()

Generates random IDs for pseudonymization.

```r
pseudonymizer$randomize_ids(
  data,                    # Vector of data to be pseudonymized
  prefix = "ID_",          # Optional prefix for the generated IDs
  consistent = TRUE        # Whether to use the same ID for same input values
)
```

**Returns**: Vector of random IDs.

### pseudonymize_dataframe()

Pseudonymizes multiple columns in a data frame.

```r
pseudonymizer$pseudonymize_dataframe(
  df,                      # Data frame to pseudonymize
  columns                  # Named list with column names and pseudonymization methods
)
```

**Returns**: Pseudonymized data frame.

### save_mappings()

Saves mappings to a secure file.

```r
pseudonymizer$save_mappings(
  file_path,               # Path to save the mapping file
  password                 # Password to encrypt the mapping file
)
```

**Returns**: Logical indicating success.

### load_mappings()

Loads mappings from a secure file.

```r
pseudonymizer$load_mappings(
  file_path,               # Path to the mapping file
  password                 # Password to decrypt the mapping file
)
```

**Returns**: Logical indicating success.

## GDPR Compliance Notes

This library implements several GDPR-recommended pseudonymization techniques:

1. **Article 4(5) Pseudonymization**: Processing personal data in such a way that it can no longer be attributed to a specific data subject without additional information.

2. **Article 25 Data Protection by Design**: Implements technical measures to meet the requirements of GDPR and protect the rights of data subjects.

3. **Article 32 Security of Processing**: Uses state-of-the-art encryption and hashing to ensure appropriate security.

4. **Article 89 Safeguards for Research**: Provides methods suitable for scientific research, statistical purposes, and archiving in the public interest.

### Best Practices for GDPR Compliance

- **Key Management**: Store encryption keys separately from pseudonymized data.
- **Access Control**: Limit access to mapping files and keys to authorized personnel.
- **Documentation**: Document your pseudonymization process as part of your GDPR compliance.
- **Data Minimization**: Consider whether you need to store mappings at all, or if one-way pseudonymization is sufficient.
- **Risk Assessment**: Conduct a risk assessment to determine the appropriate pseudonymization method for each data category.

## Performance Considerations

The library is designed to be efficient for typical data analysis workloads. However, for very large datasets:

- Consider pseudonymizing data in chunks.
- For repeated operations, save the pseudonymizer to avoid regenerating keys.
- The `randomize_ids()` method with `consistent = TRUE` can be slower for large datasets with many unique values.

## License

[MIT License]

Copyright (c) [Year] [Your Organization]

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
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
