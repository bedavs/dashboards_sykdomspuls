context("CleanData")
test_that("Basic Oslo", {
  library(data.table)
  d <- vector("list", 7)
  for (i in 0:6) {
    d[[i + 1]] <- data.table(
      age = c("0-4", "5-14", "15-19", "20-29", "30-64", "65+", "Ukjent"),
      date = data.table::as.IDate(as.Date("2006-01-23") + i),
      Kontaktype = c("Legekontakt"),
      Praksis = c("Fastlege"),
      influensa = c(100),
      gastro = c(100),
      respiratoryinternal = c(100),
      respiratoryexternal = c(100),
      lungebetennelse = c(100),
      bronkitt = c(100),
      consult = c(500),
      municip = c("municip0301")
    )
  }
  d <- rbindlist(d)

  ValidateDataRaw(d)


  population <- data.table(
    year = 2006,
    municip = "municip0301",
    age = c("0-4", "5-14", "15-19", "20-29", "30-64", "65+", "Totalt"),
    pop = c(100, 100, 100, 100, 100, 100, 600)
  )

  hellidager <- data.table(
    Dato = data.table::as.IDate(seq(as.Date("2006-01-23"), as.Date("2006-01-29"), by = 1)),
    HelligdagIndikator = 0
  )

  res <- CleanData(d,
    syndrome = "influensa",
    population = population,
    hellidager = hellidager,
    testIfHelligdagIndikatorFileIsOutdated = FALSE,
    removeMunicipsWithoutConsults = TRUE
  )
  res <- res[location %in% unique(d$municip)]

  expectedRes <- data.table(expand.grid(
    date = data.table::as.IDate(seq(as.Date("2006-01-23"), as.Date("2006-01-29"), by = 1)),
    age = c("0-4", "5-14", "15-19", "20-29", "30-64", "65+", "Totalt"),
    stringsAsFactors = FALSE
  ))
  expectedRes[, location := "municip0301"]

  expectedRes[, n := 100]
  expectedRes[age == "Totalt", n := 700]

  expectedRes[, consultWithInfluensa := 500]
  expectedRes[age == "Totalt", consultWithInfluensa := 3500]
  expectedRes[, consultWithoutInfluensa := consultWithInfluensa - n]
  expectedRes[, pop := 100]
  expectedRes[age == "Totalt", pop := 600]
  expectedRes[, county := "county03"]
  expectedRes[, HelligdagIndikator := 0]
  expectedRes[, granularityGeo := "municip"]
  setcolorder(expectedRes, VARS$REQ_DATA_CLEAN)
  setkey(expectedRes, location, age, date)
  setkey(res, location, age, date)

  res[, pop := 1]
  expectedRes[, pop := 1]

  testthat::expect_equal(res, expectedRes)
})


test_that("Sandefjord joining together", {
  library(data.table)
  d <- GenFakeDataRaw("municip0710")

  res <- CleanData(d,
    syndrome = "influensa",
    testIfHelligdagIndikatorFileIsOutdated = FALSE,
    removeMunicipsWithoutConsults = TRUE
  )
  res <- res[granularityGeo == "municip"]

  testthat::expect_equal(unique(res$location), "municip0710")
})
