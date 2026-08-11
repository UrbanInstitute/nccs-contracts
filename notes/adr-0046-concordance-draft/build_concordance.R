## Compose a three-way variable concordance:
##   NODC F9_* e-file names <-> SOI raw extract names <-> nccs-data-core
##   snake_case names <-> legacy NCCS CORE names.
## Pivot key: the raw SOI extract variable name (lowercased).

library(data.table)

core_xw_dir <- Sys.getenv("CORE_XW_DIR", "../../../nccs-data-core/data/crosswalks")
nodc_vfinal <- Sys.getenv("NODC_VFINAL_CSV",
  "SOI-EXTRACT-CROSSWALKS-2012-2024-EZ-PC-VFINAL.CSV")  # pinned SHA in README
out_csv     <- "core-variable-concordance-DRAFT.csv"  # run from this directory

## ---- NODC side: one row per (soi raw variant, form) -> F9_* -------------
nodc <- fread(nodc_vfinal, colClasses = "character")

yr_cols <- grep("^YEAR\\.", names(nodc), value = TRUE)
long <- melt(nodc,
             id.vars = c("ID", "SOI.VAR", "EFILE.VAR", "LABEL", "DESC", "VSCOPE"),
             measure.vars = yr_cols,
             variable.name = "year_form", value.name = "soi_raw")
long <- long[soi_raw != ""]
long[, form := toupper(sub(".*\\.", "", year_form))]   # EZ / PC
long[, year := as.integer(sub("YEAR\\.([0-9]{4}).*", "\\1", year_form))]
long[, soi_raw_lc := tolower(soi_raw)]

nodc_map <- long[, .(
  nodc_efile_var = EFILE.VAR[1],
  nodc_label     = LABEL[1],
  nodc_vscope    = VSCOPE[1],
  years          = paste0(min(year), "-", max(year))
), by = .(soi_raw_lc, form)]

## ---- core side: soi raw -> snake_case, per form -------------------------
core990 <- fread(file.path(core_xw_dir, "soi_990_crosswalk_FINAL.csv"),
                 colClasses = "character")
coreez  <- fread(file.path(core_xw_dir, "soi_990ez_crosswalk_FINAL.csv"),
                 colClasses = "character")
core990[, `:=`(soi_raw_lc = tolower(source_var), form = "PC")]
coreez[,  `:=`(soi_raw_lc = tolower(source_var), form = "EZ")]
core <- rbind(
  core990[, .(soi_raw_lc, form, core_harmonized_name = harmonized_name,
              core_description = description, core_years = years_present)],
  coreez[,  .(soi_raw_lc, form, core_harmonized_name = harmonized_name,
              core_description = description, core_years = years_present)]
)
## Collapse year-split crosswalk rows: the ADR promises ONE row per
## (raw SOI variable, form). Same variable must map to the same
## harmonized name across splits -- stop if not.
split_check <- core[, uniqueN(core_harmonized_name), by = .(soi_raw_lc, form)]
stopifnot(all(split_check$V1 == 1L))
core <- core[, .(
  core_harmonized_name = core_harmonized_name[1],
  core_description     = core_description[1],
  core_years           = paste(sort(unique(unlist(
                           strsplit(core_years, ";")))), collapse = ";")
), by = .(soi_raw_lc, form)]

## ---- join on (raw soi name, form) ---------------------------------------
cc <- merge(core, nodc_map, by = c("soi_raw_lc", "form"), all = TRUE)

## ---- legacy side: attach legacy CORE names via core harmonized name -----
leg <- fread(file.path(core_xw_dir, "legacy_pz_crosswalk_FINAL.csv"),
             colClasses = "character")
leg <- leg[harmonized_name != ""]
leg_map <- leg[, .(
  legacy_core_names = paste(sort(unique(source_column)), collapse = ";"),
  legacy_years      = paste(sort(unique(years_present)), collapse = ";")
), by = .(core_harmonized_name = harmonized_name)]

cc <- merge(cc, leg_map, by = "core_harmonized_name", all.x = TRUE)

setcolorder(cc, c("soi_raw_lc", "form", "core_harmonized_name",
                  "nodc_efile_var", "legacy_core_names",
                  "nodc_vscope", "nodc_label", "core_description",
                  "core_years", "years", "legacy_years"))
setnames(cc, c("soi_raw_lc", "years"),
             c("soi_source_var", "nodc_years"))
setorder(cc, form, soi_source_var, na.last = TRUE)

fwrite(cc, out_csv)

## ---- coverage summary ----------------------------------------------------
stopifnot(!anyDuplicated(cc[, .(soi_source_var, form)]))  # ADR shape gate
cat("rows:", nrow(cc), "\n")
cat("matched all three (soi+core+nodc+legacy):",
    cc[!is.na(core_harmonized_name) & !is.na(nodc_efile_var) &
       !is.na(legacy_core_names), .N], "\n")
cat("core+nodc matched:",
    cc[!is.na(core_harmonized_name) & !is.na(nodc_efile_var), .N], "\n")
cat("core only (no NODC match):",
    cc[!is.na(core_harmonized_name) & is.na(nodc_efile_var), .N], "\n")
cat("nodc only (no core match):",
    cc[is.na(core_harmonized_name) & !is.na(nodc_efile_var), .N], "\n")
