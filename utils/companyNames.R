# Latin Word Extractor
# This script extracts Latin words from a dictionary webpage

# Function to parse the dictionary content and extract Latin words
extract_latin_words <- function(text) {
  # Split the text into lines
  lines <- unlist(strsplit(text, "\n"))
  
  # Initialize empty vector for Latin words
  latin_words <- c()
  
  # Pattern to identify dictionary entries (word followed by colon)
  pattern <- "^([^:]+):"
  
  # Process each line
  for (line in lines) {
    # Skip lines that don't contain a colon or are section headers
    if (!grepl(":", line) || grepl("^\\[ \\]", line)) {
      next
    }
    
    # Extract the word before the colon
    match <- regexpr(pattern, line, perl = TRUE)
    if (match > 0) {
      word_length <- attr(match, "match.length") - 1  # Subtract 1 to exclude the colon
      word <- substr(line, match, match + word_length - 1)
      
      # Trim whitespace
      word <- trimws(word)
      
      # Skip empty words or section headers
      if (nchar(word) > 0 && !grepl("^\\[ \\]", word)) {
        # Handle cases where there might be multiple words separated by commas or "/"
        # Only take the first word in these cases
        if (grepl("[,/]", word)) {
          word <- trimws(unlist(strsplit(word, "[,/]"))[1])
        }
        
        # Add to our list if it's a valid word
        if (nchar(word) > 0) {
          latin_words <- c(latin_words, word)
        }
      }
    }
  }
  
  # Return unique words (remove duplicates)
  return(unique(latin_words))
}

# URL of the Latin dictionary
url <- "https://personal.math.ubc.ca/~cass/frivs/latin/latin-dict-full.html"

# Download the webpage content
# In a real environment, you'd use this:
# webpage <- readLines(url, warn = FALSE)
# content <- paste(webpage, collapse = "\n")

# For this example, we'll simulate with a small sample from the actual content
# In reality, you'd parse the actual HTML content from the URL

# Read the webpage using the 'rvest' package
if (!require("rvest")) {
  install.packages("rvest")
  library(rvest)
}

# Fetch and parse the webpage
webpage <- read_html(url)
content <- html_text(webpage)

# Extract Latin words
latin_words <- extract_latin_words(content)

# Display the first 20 words (or fewer if there are less than 20)
cat("First few Latin words extracted:\n")
print(head(latin_words, 20))

# Count the total number of words extracted
cat(paste("\nTotal Latin words extracted:", length(latin_words), "\n"))

# Save the words to a CSV file
write.csv(latin_words, "latin_words.csv", row.names = FALSE)

cat("Latin words have been saved to 'latin_words.csv'\n")

# Alternatively, if you want to work with the array in R:
# Create a data frame
latin_df <- data.frame(word = latin_words)

# You can now work with this data frame for further analysis
# For example, to find words starting with 'a':
a_words <- latin_df[grep("^a", latin_df$word), ]
cat(paste("\nNumber of words starting with 'a':", nrow(a_words), "\n"))

# Return the array of Latin words
return(latin_words)
