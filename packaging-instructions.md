
# Creating an R Package from Your Project

## Prerequisites

First, make sure you have the necessary tools installed:

```r
install.packages(c("devtools", "roxygen2", "testthat", "knitr", "rmarkdown"))
```

## Step 1: Set up the Package Structure

Use `devtools` to create a basic package structure:

```r
library(devtools)
create_package("path/to/your/packagename")
```

This creates a directory with the standard R package structure:

```
packagename/
├── DESCRIPTION
├── NAMESPACE
├── R/
├── man/
└── tests/
```

## Step 2: Move Your Existing Code

1. Move your R functions into the `R/` directory, organizing them into files by functionality (keeping each file under 100 lines)
2. For your RData dataset, create a `data/` directory and save it there:

```r
dir.create("data")
save(your_dataset, file = "data/your_dataset.rdata")
```

## Step 3: Document Your Code with roxygen2

Add roxygen2 comments before each function:

```r
#' Function Title
#' 
#' @description A detailed description of what the function does.
#' 
#' @param param1 Description of parameter 1
#' @param param2 Description of parameter 2
#' 
#' @return Description of the return value
#' 
#' @examples
#' your_function(param1 = "example", param2 = 42)
#' 
#' @export
your_function <- function(param1, param2) {
  # Function body
}
```

Document your dataset:

```r
#' Your Dataset Title
#'
#' @description Detailed description of your dataset
#'
#' @format A data frame with X rows and Y columns:
#' \describe{
#'   \item{column1}{Description of column1}
#'   \item{column2}{Description of column2}
#' }
#'
#' @source Where did this data come from (if applicable)
"your_dataset"
```

## Step 4: Create Package Documentation

Create a package-level documentation file named `R/packagename-package.R`:

```r
#' @keywords internal
"_PACKAGE"

#' @importFrom stats function1 function2
#' @importFrom utils function3
NULL
```

## Step 5: Update DESCRIPTION File

Edit the DESCRIPTION file with your package information:

```
Package: packagename
Title: Brief Title in Title Case
Version: 0.1.0
Authors@R: person("Your", "Name", email = "your.email@example.com", role = c("aut", "cre"))
Description: A paragraph that describes what your package does. Try to be 
    specific and detailed. This should be at least one full sentence but 
    preferably 3-5 sentences.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.3
Depends: 
    R (>= 3.5.0)
Imports:
    dplyr,
    ggplot2
Suggests:
    testthat (>= 3.0.0),
    knitr,
    rmarkdown
Config/testthat/edition: 3
```

## Step 6: Create a README and Vignettes

Create a README.Rmd file with markdown:

```r
use_readme_rmd()
```

Create vignettes (detailed guides) for your package:

```r
use_vignette("introduction")
```

## Step 7: Add License Information

```r
use_mit_license("Your Name")
```

## Step 8: Generate Documentation and Check the Package

```r
# Generate documentation from roxygen comments
document()

# Check if your package has any issues
check()
```

## Step 9: Build the Package

```r
# Build the package
build()
```

This creates a `.tar.gz` file that you can share with colleagues.

## Step 10: Installation Instructions for Colleagues

Your colleagues can install your package using:

```r
# Using devtools
devtools::install_local("path/to/packagename_0.1.0.tar.gz")

# Or directly from your shared directory/Git repository
devtools::install_github("yourusername/packagename")

# Install from GitLab
devtools::install_gitlab("username/packagename")

# Install from locally hosted GitLab
devtools::install_gitlab("username/packagename", host = "gitlab.your-company.com")

# Install from GitLab with privacy token
devtools::install_gitlab("username/packagename", auth_token = "your_personal_access_token")
```

## Additional Best Practices

1. Use `use_test()` to create unit tests for your functions
2. Create a GitHub repository for versioning and collaboration
3. Set up continuous integration with GitHub Actions using `use_github_action()`
4. Consider including locale-specific handling for numeric formats since you mentioned working with locales where the thousand separator is "." and decimal separator is ","

## System Dependencies on RStudio Server

 Depending on your RStudio Server setup, you might need system-level dependencies installed. If you're not the server administrator, you might need to request these installations:

```r
# On Ubuntu/Debian systems:
sudo apt-get install build-essential libcurl4-openssl-dev libssl-dev libxml2-dev

# On Red Hat/CentOS/Fedora systems:
sudo yum install openssl-devel libcurl-devel libxml2-devel
```

**Git Integration:** RStudio Server has built-in Git integration, making it easy to work with Git repositories just like in desktop RStudio.
Package Building Tools: All necessary tools for package development (document(), check(), build(), etc.) work identically on RStudio Server.
User Permissions: Make sure your RStudio Server user has sufficient permissions to write to the relevant directories for package development.
Resource Limitations: Be aware that your RStudio Server might have configured resource limitations that could affect memory-intensive package operations.
Shared Environment: If you're using a shared RStudio Server instance, be mindful of package dependencies that might affect other users.

One advantage of developing packages on RStudio Server is that it provides a consistent environment across teams, which can help avoid "works on my machine" problems when creating and distributing packages to colleagues.


