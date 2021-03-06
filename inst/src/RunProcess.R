fhi::DashboardInitialiseOpinionated("sykdomspuls")

suppressMessages(library(data.table))
suppressMessages(library(foreach))
suppressMessages(library(doSNOW))
suppressMessages(library(iterators))

if (!dir.exists(fhi::DashboardFolder("results", "externalapi"))) dir.create(fhi::DashboardFolder("results", "externalapi"))
if (!dir.exists(fhi::DashboardFolder("results", LatestRawID()))) dir.create(fhi::DashboardFolder("results", LatestRawID()))
if (!dir.exists(fhi::DashboardFolder("data_raw", "normomo"))) dir.create(fhi::DashboardFolder("data_raw", "normomo"))

SaveRDS(ConvertConfigForAPI(), fhi::DashboardFolder("results", "config.RDS"))
SaveRDS(ConvertConfigForAPI(), fhi::DashboardFolder("data_app", "config.RDS"))
SaveRDS(ConvertConfigForAPI(), fhi::DashboardFolder("results", "externalapi/config.RDS"))

if (!UpdateData()) {
  fhi::DashboardMsg("Have not run analyses and exiting")
  q(save = "no", status = 21)
}
DeleteOldDatasets()

# if (!fhi::DashboardIsDev()) {
fhi::DashboardMsg("Registering cluster", newLine = T)
cl <- makeCluster(parallel::detectCores())
registerDoSNOW(cl)
# }

for (i in 1:nrow(sykdomspuls::CONFIG$SYNDROMES)) {
  conf <- sykdomspuls::CONFIG$SYNDROMES[i]
  fhi::DashboardMsg(conf$tag)

  stackAndData <- sykdomspuls::StackAndEfficientDataForAnalysis(conf = conf)
  data <- stackAndData$data
  stack <- stackAndData$analyses

  if (i == 1) {
    fhi::DashboardMsg("Initializing progress bar")
    PBInitialize(n = nrow(stack) * nrow(sykdomspuls::CONFIG$SYNDROMES))
  }

  fhi::DashboardMsg("Setting keys for binary search")
  setkeyv(data, c("location", "age"))

  res <- foreach(analysisIter = StackIterator(stack, data, PBIncrement), .noexport = c("data")) %dopar% {
    if (!fhi::DashboardIsDev()) {
      library(data.table)
    }

    exceptionalFunction <- function(err) {
      fhi::DashboardMsg(err, syscallsDepth = 10, newLine = T)
      fhi::DashboardMsg(analysisIter$stack, newLine = T)
    }

    analysesStack <- analysisIter$stack
    analysisData <- analysisIter$data
    # x <- analysisIter$nextElem()
    # analysesStack <- x$stack
    # analysisData <- x$data

    retval <- tryCatch(
      sykdomspuls::RunOneAnalysis(analysesStack = analysesStack, analysisData = analysisData),
      error = exceptionalFunction
    )

    retval
  }
  res <- rbindlist(res)

  # adding in extra information
  AddLocationName(res)
  AddCounty(res)

  # cleaning on small municipalities
  res[location %in% CONFIG$smallMunicips & age != "Totalt", n := 0 ]
  res[location %in% CONFIG$smallMunicips & age != "Totalt", threshold2 := 5 ]
  res[location %in% CONFIG$smallMunicips & age != "Totalt", threshold4 := 10 ]

  fhi::DashboardMsg("Saving files", newLine = T)
  for (f in unique(res$file)) {
    fhi::DashboardMsg(sprintf("Saving file %s", f))
    saveRDS(res[file == f], file = fhi::DashboardFolder("results", sprintf("%s/%s", LatestRawID(), f)))
  }

  rm("res", "data", "stackAndData")
}

# if (!fhi::DashboardIsDev()) {
fhi::DashboardMsg("Stopping cluster", newLine = T)
stopCluster(cl)
# }

# Append all the syndromes together
ResultsAggregateApply()

## GENERATE LIST OF OUTBREAKS
fhi::DashboardMsg("Generate list of outbreaks")
GenerateOutbreakListInternal()
GenerateOutbreakListInternal(
  saveFiles = fhi::DashboardFolder("results", "externalapi/outbreaks.RDS"),
  useType = TRUE
)
GenerateOutbreakListExternal()

fhi::DashboardMsg("Send data to DB")
SaveShinyAppDataToDB()

# Done with analyses
fhi::DashboardMsg("Done with all analyses")

CreateLatestDoneFile()
cat("done", file = "/data_app/sykdomspuls/done.txt")

## SENDING OUT EMAILS
EmailNotificationOfNewResults()

fhi::DashboardMsg("Finished analyses and exiting")
if (!fhi::DashboardIsDev()) quit(save = "no", status = 0)

# dk = readRDS(fhi::DashboardFolder("results", "resYearLineMunicip.RDS"))
