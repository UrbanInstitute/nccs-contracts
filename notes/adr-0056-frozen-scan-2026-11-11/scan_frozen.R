# Full scan of every frozen harmonized CORE file (ADR 0056 follow-up 1).
# A damaged cell is a number that is not zero and is smaller than 1e-300 in size:
# a whole number stored as 64-bit that was read back as a decimal number.
suppressMessages({library(data.table); library(arrow); library(parallel)})
files <- sort(list.files("mirror/frozen", recursive=TRUE, full.names=TRUE)); files <- files[!grepl("_dd\\.csv$", files)]
is_damaged_text <- function(v) grepl("^-?[0-9.]+[eE]-3[0-9]{2}$", v)
scan_one <- function(f) tryCatch({
  if (grepl("parquet$", f)) { x <- as.data.table(read_parquet(f)); bad <- sapply(x, function(v) if (is.double(v)) sum(v != 0 & abs(v) < 1e-300, na.rm=TRUE) else 0L)
  } else { x <- fread(f, colClasses="character", showProgress=FALSE); bad <- sapply(x, function(v) sum(is_damaged_text(v))) }
  bad <- bad[bad > 0]
  list(file=data.table(file=sub("mirror/frozen/","",f), bytes=file.size(f), rows=nrow(x), columns=ncol(x), damaged_columns=length(bad), damaged_cells=sum(bad), most_rows_damaged_in_one_column=if(length(bad)) max(bad) else 0L, error=""),
       cols=if(length(bad)) data.table(file=sub("mirror/frozen/","",f), column=names(bad), damaged_rows=as.integer(bad), rows=nrow(x)) else NULL)
}, error=function(e) list(file=data.table(file=sub("mirror/frozen/","",f), bytes=file.size(f), rows=NA_integer_, columns=NA_integer_, damaged_columns=NA_integer_, damaged_cells=NA_real_, most_rows_damaged_in_one_column=NA_integer_, error=conditionMessage(e)), cols=NULL))
res <- mclapply(files[order(-file.size(files))], scan_one, mc.cores=6, mc.preschedule=FALSE)
bad_workers <- sum(!sapply(res, is.list)); if (bad_workers) stop(bad_workers, " files returned no result")
fwrite(rbindlist(lapply(res, `[[`, "file"))[order(file)], "~/scan/frozen_scan_by_file.csv")
fwrite(rbindlist(lapply(res, `[[`, "cols")), "~/scan/frozen_scan_by_column.csv")
cat("files scanned:", length(res), "of", length(files), "\n")
