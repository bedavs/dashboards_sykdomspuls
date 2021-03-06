% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Analyses.R
\name{CalculateTrainPredictYearPattern}
\alias{CalculateTrainPredictYearPattern}
\title{Determining which years of training data will be used}
\usage{
CalculateTrainPredictYearPattern(yearMin, yearMax, numPerYear1 = 1)
}
\arguments{
\item{yearMin}{The first year of data}

\item{yearMax}{The last year of data}

\item{numPerYear1}{5 years of training data should
only be used for 1 subsequent year of outbreak detection
for the last \code{numPerYear1} years}
}
\value{
A list containing a sequence of training years and prediction years
}
\description{
For a year to be "predicted" (i.e. have outbreaks detected)
it must use 5 years of training data. This function calculates
which years of training data are assigned to detect outbreaks.
}
\details{
For reasons of efficiency, we change the training data set on January 1st.
That is, an entire year (or more) of outbreaks are detected off a fixed
set of training data.

The current algorithm that we use sets the first 5 years of data as training data
for the first 6 years of outbreak detection. We then fix our 5 years of training data
and use it for sequences of 2 years of outbreak detection.

When it approaches the current year, we want better calculations, so
we can specify that 5 years of training data should
only be used for 1 subsequent year of outbreak detection
through the \code{numPerYear1} parameter.
}
\examples{
sykdomspuls::CalculateTrainPredictYearPattern(2000, 2015, 1)

sykdomspuls::CalculateTrainPredictYearPattern(2000, 2015, 3)
}
