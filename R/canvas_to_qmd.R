#' Check if required packages are installed
#'
#' This function checks if all required packages are installed and stops execution if any are missing.
#'
#' @return None. Stops execution if any packages are missing.
check_dependencies <- function() {
  required_packages <- c("dplyr", "ggplot2", "httr", "openai", "rcanvas", "rvest", "stringr", "jsonlite")
  missing_packages <- setdiff(required_packages, rownames(installed.packages()))
  if (length(missing_packages) > 0) {
    stop(paste("The following packages are missing:", paste(missing_packages, collapse = ", ")))
  }
  # load required packages
  lapply(required_packages, require, character.only = TRUE)
}

#' Validate input arguments
#'
#' This function validates the input arguments to ensure they are of the correct type and format.
#'
#' @param course_id A single integer representing the course ID.
#' @param template A single character string representing the file path to the template file.
#' @param target_dir A single character string representing the target directory.
#' @return None. Stops execution if any input arguments are invalid.
validate_inputs <- function(course_id, template, target_dir) {
  if (is.null(course_id) || !is.numeric(course_id) || length(course_id) != 1 || course_id != as.integer(course_id)) {
    stop("course_id must be a single integer.")
  }
  if (is.null(template) || !is.character(template) || length(template) != 1) {
    stop("template must be a single character string (file path).")
  }
  if (is.null(target_dir) || !is.character(target_dir) || length(target_dir) != 1) {
    stop("target_dir must be a single character string.")
  }
  if (!dir.exists(target_dir)) {
    stop("target_dir does not exist.")
  }
  if (!file.exists(template)) {
    stop("template file does not exist.")
  }
}

#' Retrieve Canvas page content
#'
#' This function retrieves the JSON content of a Canvas page using httr and the Canvas API.
#'
#' @param course_id A single integer representing the course ID.
#' @param canvas_token A single character string representing the Canvas API token.
#' @param page_url A single character string representing the page URL.
#' @return A list containing the JSON content of the Canvas page.
get_canvas_page_content <- function(course_id, canvas_token, page_url) {
  canvas_url <- "https://wakeforest.instructure.com/api/v1"
  file_url <- paste0(canvas_url, "/", file.path("courses", course_id, "pages", page_url))
  page_content <- httr::GET(
    file_url,
    httr::add_headers(Authorization = paste("Bearer", canvas_token))
  )
  if (http_error(page_content)) {
    stop(paste("Failed to retrieve page content:", file_url, "Status:", status_code(page_content)))
  }
  page_content_json <- jsonlite::fromJSON(content(page_content, "text"))
  return(page_content_json)
}

#' Convert HTML to Quarto using OpenAI
#'
#' This function converts HTML content to Quarto markdown using the OpenAI API.
#'
#' @param html_content An object of class `html` representing the HTML content to convert.
#' @param template_content A single character string representing the content of the template file.
#' @return A single character string representing the converted Quarto markdown.
convert_html_to_quarto <- function(html_content, template_content) {
  prompt <- paste("Convert the following HTML to QMD (Quarto markdown) following the conventions used in the given template. Only return the QMD content, including the yaml frontmatter, you convert from the HTML given, without any extra text, explanations, or code fencing:", "\n\nQMD template:\n", template_content, "\n\nHTML:\n", as.character(html_content), "\n\nRemember to follow the conventions, such as `:::` div fences instead of tables, used in the template when converting the HTML to markdown.")
  tryCatch(
    {
      response <- openai::create_chat_completion(
        model = "gpt-3.5-turbo",
        messages = list(
          list(
            role = "user",
            content = prompt
          )
        )
      )
      if (is.null(response) || !is.list(response) || length(response$choices) == 0) {
        stop("Invalid response from OpenAI API.")
      }
      markdown_output <- response$choices$message.content
      message("OpenAI API call successful.")
      return(markdown_output)
    },
    error = function(e) {
      stop(paste("Error during OpenAI API call:", e$message))
    }
  )
}

#' Write markdown content to a file
#'
#' This function writes the markdown content to a file, checking if the file exists and only overwriting if force = TRUE.
#'
#' @param markdown_output A single character string representing the markdown content to write.
#' @param title A single character string representing the title of the page.
#' @param target_dir A single character string representing the target directory.
#' @param force A logical value indicating whether to overwrite the file if it exists.
#' @return None. Writes the markdown content to a file.
write_markdown_file <- function(markdown_output, title, target_dir, force = FALSE) {
  file_name <- str_remove(title, ".*?,\\s") |>
    str_replace_all("(\\d+)/(\\d+)", "plan-2024-\\2-\\1.qmd")
  file_path <- file.path(target_dir, file_name)

  if (file.exists(file_path) && !force) {
    stop(paste("File already exists:", file_path, "Use force = TRUE to overwrite."))
  }

  writeLines(markdown_output, file_path)
  message(paste("Markdown written to:", file_path))
}

#' Main function to convert Canvas pages to Quarto
#'
#' This function orchestrates the entire process of retrieving Canvas pages, converting them to Quarto markdown, and writing them to files.
#'
#' @param course_id A single integer representing the course ID.
#' @param template A single character string representing the file path to the template file.
#' @param page_url A single character string representing the page URL.
#' @param force A logical value indicating whether to overwrite existing files.
#' @param target_dir A single character string representing the target directory.
#' @param ... Additional arguments passed to other functions.
#' @return None. Writes Quarto markdown files to the target directory.
canvas_to_qmd <- function(course_id, template, page_url, force = FALSE, target_dir = ".", ...) {
  # Check dependencies
  check_dependencies()

  # Validate inputs
  validate_inputs(course_id, template, target_dir)

  # Get Canvas API token
  canvas_token <- Sys.getenv("CANVAS_API_KEY")
  if (canvas_token == "") {
    stop("CANVAS_API_KEY environment variable not set.")
  }

  # Read template file
  template_content <- paste(readLines(template), collapse = "\n")

  # Get page content
  page_content_json <- get_canvas_page_content(course_id, canvas_token, page_url)

  # Get page title and body
  title <- page_content_json$title
  html_content <- rvest::read_html(page_content_json$body)

  # Convert HTML to Quarto
  markdown_output <- convert_html_to_quarto(html_content, template_content)

  # Write markdown to file
  write_markdown_file(markdown_output, title, target_dir, force)
}

# Example usage (you would replace these with your actual values)
# course_pages <- get_course_items(65434, "pages")
# canvas_to_qmd(
#   course_id = 65434,
#   template = "_D.qmd",
#   page_url = course_pages$url[10],
#   force = FALSE,
#   target_dir = "."
# )
