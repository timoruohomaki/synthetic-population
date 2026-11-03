# Step 8: e-mail addresses and phone numbers ---------------------------------
#
# E-mail addresses use the domains reserved for documentation (RFC 2606), so
# no message can ever reach a real person. Finland has no phone number range
# reserved for fiction, so phone numbers use the mobile area codes 047 and 048
# that Traficom keeps in reserve (not granted to any operator). Check the
# Traficom list now and then: reserved codes can be granted in the future.
#
# What you'll learn:
#   - cleaning text: tolower(), chartr() and regular expressions with gsub()
#   - making values unique: duplicated() and numbering repeats
#   - formatting numbers as zero-padded strings with sprintf()

#' Letters that are common in Finnish names, mapped to plain ASCII.
ascii_name <- function(x) {
  # \u escapes keep this working whatever the encoding of your R session:
  # äöåáàâéèêëíïóôúüýæøšžčç -> aoaaaaeeeeiioouuyaoszcc
  from <- "\u00e4\u00f6\u00e5\u00e1\u00e0\u00e2\u00e9\u00e8\u00ea\u00eb\u00ed\u00ef\u00f3\u00f4\u00fa\u00fc\u00fd\u00e6\u00f8\u0161\u017e\u010d\u00e7"
  x <- chartr(enc2utf8(from), "aoaaaaeeeeiioouuyaoszcc", enc2utf8(tolower(x)))
  x <- gsub("[^a-z0-9-]+", "", x)   # drop spaces, apostrophes and anything else
  gsub("^-+|-+$", "", x)
}

#' "first.last@domain", with a running number when the name repeats:
#' matti.virtanen@example.com, matti.virtanen2@example.com, ...
make_email <- function(first_name, last_name, domains) {
  local <- paste(ascii_name(first_name), ascii_name(last_name), sep = ".")
  local <- gsub("^\\.|\\.$", "", local)
  local[local == ""] <- "person"
  domain <- sample(unlist(domains), length(local), replace = TRUE)
  address <- paste0(local, "@", domain)
  nth <- rank_within(address)   # 1, 2, 3 ... for repeats of the same address
  suffix <- ifelse(nth == 1, "", as.character(nth))
  paste0(local, suffix, "@", domain)
}

#' Mobile numbers like "047 1234567"; prefixes are drawn by weight.
#' Returned unique: the 7-digit part is redrawn for any duplicate.
make_phone <- function(n, prefixes) {
  p <- unlist(prefixes)
  prefix <- sample(names(p), n, replace = TRUE, prob = p)
  phone <- paste(prefix, sprintf("%07d", sample.int(1e7, n, replace = TRUE) - 1L))
  for (attempt in 1:20) {
    dup <- duplicated(phone)
    if (!any(dup)) return(phone)
    phone[dup] <- paste(prefix[dup], sprintf("%07d", sample.int(1e7, sum(dup), replace = TRUE) - 1L))
  }
  abort("Could not make ", fmt_int(n), " unique phone numbers; add prefixes in config.yaml")
}
