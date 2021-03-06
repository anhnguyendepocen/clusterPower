% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/crtpwr.2meanM.R
\name{crtpwr.2meanM}
\alias{crtpwr.2meanM}
\title{Power calculations for simple cluster randomized trials with matching, continuous outcome}
\usage{
crtpwr.2meanM(alpha = 0.05, power = 0.8, nclusters = NA, nsubjects = NA,
  d = NA, icc = NA, vart = NA, rho_m = NA,
  tol = .Machine$double.eps^0.25)
}
\arguments{
\item{alpha}{The level of significance of the test, the probability of a
Type I error.}

\item{power}{The power of the test, 1 minus the probability of a Type II
error.}

\item{nclusters}{The number of clusters per condition. It must be greater than 1.}

\item{nsubjects}{The mean of the cluster sizes.}

\item{d}{The difference in condition means.}

\item{icc}{The intraclass correlation.}

\item{vart}{The total variation of the outcome (the sum of within- and between-cluster variation).}

\item{rho_m}{The correlation in the outcome between matched clusters.}

\item{tol}{Numerical tolerance used in root finding. The default provides
at least four significant digits.}
}
\value{
The computed argument.
}
\description{
Compute the power of a simple cluster randomized trial with a continuous outcome with cluster-level matching,
or determine parameters to obtain a target power.
}
\details{
Exactly one of \code{alpha}, \code{power}, \code{nclusters}, \code{nsubjects},
  \code{d}, \code{icc}, \code{vart}, \code{rho_m}  must be passed as \code{NA}.
  Note that \code{alpha} and \code{power} have non-\code{NA}
  defaults, so if those are the parameters of interest they must be
  explicitly passed as \code{NA}.
  
If \code{nsubjects} is a vector the values, \code{nclusters} will be recalculated
   using the values in \code{nsubjects}.
}
\section{Note}{

  This function was inspired by work from Stephane Champely (pwr.t.test) and
  Peter Dalgaard (power.t.test). As with those functions, 'uniroot' is used to
  solve power equation for unknowns, so you may see
  errors from it, notably about inability to bracket the root when
  invalid arguments are given.
}

\section{Authors}{

Jonathan Moyer (\email{jon.moyer@gmail.com}), Ken Kleinman (\email{ken.kleinman@gmail.com})
}

\examples{
# Find the number of clusters per condition needed for a trial with alpha = .05, 
# power = 0.8, 10 observations per cluster, matching correlation of 0.7, 
# a difference of 1 unit,  icc = 0.1 and a variance of five units.
crtpwr.2meanM(nsubjects=10 ,rho_m=0.7,d=1, icc=.1, vart=5)
# 
# The result, showimg nclusters of greater than 11, suggests 12 clusters per
# condition should be used.
}
\references{
Crespi CM. (2016) Improved Designs for Cluster Randomized Trials. Annu Rev Public Health. 
  37:1-16.
}
