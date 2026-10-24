# ccms-synth dashboard - Shiny app entry point.
# Run from the ccms-synth project root: shiny::runApp("dashboard")
# Database: env var CCMS_DB, else ../output/ccms_synth.sqlite relative to this folder.

REQUIRED_PKGS <- c(shiny = "1.7.0", bslib = "0.5.0", plotly = "4.10.0", DT = "0.27",
                   data.table = "1.14.0", DBI = "1.1.0", RSQLite = "2.2.0", yaml = "2.3.0")
for (p in names(REQUIRED_PKGS)) {
  if (!requireNamespace(p, quietly = TRUE) || utils::packageVersion(p) < REQUIRED_PKGS[[p]]) {
    stop(sprintf("Package '%s' (>= %s) is required: install.packages('%s')", p, REQUIRED_PKGS[[p]], p), call. = FALSE)
  }
}
suppressPackageStartupMessages(library(data.table))

app_dir <- getwd()
for (f in sort(list.files(file.path(app_dir, "R"), pattern = "\\.R$", full.names = TRUE))) source(f, local = TRUE)
cfg <- yaml::read_yaml(file.path(app_dir, "config.yaml"))

# Load once per R process; a failure becomes an error page instead of a crash.
DATA <- tryCatch(load_dashboard_data(find_database(app_dir)), error = function(e) e)

theme <- bslib::bs_theme(version = 5, bg = "#f9f9f7", fg = "#0b0b0b", primary = "#2a78d6",
  base_font = bslib::font_collection("system-ui", "-apple-system", "Segoe UI", "sans-serif"),
  "card-border-color" = "rgba(11,11,11,0.10)") |>
  bslib::bs_add_rules("table.dataTable td, table.dataTable th { white-space: nowrap; }
                       .bslib-value-box .value-box-value { font-variant-numeric: tabular-nums; }")

error_ui <- function(e) {
  bslib::page_fillable(theme = theme, bslib::card(bslib::card_header("Dashboard cannot start"),
    shiny::p(conditionMessage(e)),
    shiny::p("Generate the data from the ccms-synth folder with ", shiny::code("Rscript run.R"),
             " or point ", shiny::code("CCMS_DB"), " at an existing ccms_synth.sqlite.")))
}

ui <- if (inherits(DATA, "error")) error_ui(DATA) else bslib::page_navbar(
  title = cfg$title, theme = theme, fillable = FALSE,
  sidebar = bslib::sidebar(width = 300, filters_ui("filters", DATA)),
  bslib::nav_panel("Overview", overview_ui("overview")),
  bslib::nav_panel("Caseload inventory", inventory_ui("inventory")),
  bslib::nav_panel("Dispositions", dispositions_ui("dispositions")),
  bslib::nav_panel("Pending & exceptions", aging_ui("aging")),
  bslib::nav_panel("Delay & caseflow", delay_ui("delay")),
  bslib::nav_panel("Judges & resources", resources_ui("resources")),
  bslib::nav_panel("Projection", projection_ui("projection")),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::tags$small(class = "text-muted", "Synthetic data – not real court records")))

server <- function(input, output, session) {
  if (inherits(DATA, "error")) return(invisible(NULL))
  f <- filters_server("filters", DATA)
  overview_server("overview", DATA, f, cfg)
  inventory_server("inventory", DATA, f, cfg)
  dispositions_server("dispositions", DATA, f, cfg)
  aging_server("aging", DATA, f, cfg)
  delay_server("delay", DATA, f, cfg)
  resources_server("resources", DATA, f, cfg)
  projection_server("projection", DATA, f, cfg)
}

shiny::shinyApp(ui, server)
