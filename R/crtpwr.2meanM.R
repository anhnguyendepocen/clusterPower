#' Power calculations for simple cluster randomized trials with matching, continuous outcome
#'
#' Compute the power of a simple cluster randomized trial with a continuous outcome with cluster-level matching,
#' or determine parameters to obtain a target power.
#'
#' Exactly one of \code{alpha}, \code{power}, \code{nclusters}, \code{nsubjects},
#'   \code{d}, \code{icc}, \code{vart}, \code{rho_m}  must be passed as \code{NA}.
#'   Note that \code{alpha} and \code{power} have non-\code{NA}
#'   defaults, so if those are the parameters of interest they must be
#'   explicitly passed as \code{NA}.
#'   
#' If \code{nsubjects} is a vector the values, \code{nclusters} will be recalculated
#'    using the values in \code{nsubjects}. 
#'
#' @section Note:
#'   This function was inspired by work from Stephane Champely (pwr.t.test) and
#'   Peter Dalgaard (power.t.test). As with those functions, 'uniroot' is used to
#'   solve power equation for unknowns, so you may see
#'   errors from it, notably about inability to bracket the root when
#'   invalid arguments are given.
#'
#' @section Authors:
#' Jonathan Moyer (\email{jon.moyer@@gmail.com}), Ken Kleinman (\email{ken.kleinman@@gmail.com})
#'
#' @param alpha The level of significance of the test, the probability of a
#'   Type I error.
#' @param power The power of the test, 1 minus the probability of a Type II
#'   error.
#' @param nclusters The number of clusters per condition. It must be greater than 1.
#' @param nsubjects The mean of the cluster sizes.
#' @param d The difference in condition means.
#' @param icc The intraclass correlation.
#' @param vart The total variation of the outcome (the sum of within- and between-cluster variation).
#' @param rho_m The correlation in the outcome between matched clusters. 
#' @param tol Numerical tolerance used in root finding. The default provides
#'   at least four significant digits.
#' @return The computed argument.
#' @examples 
#' # Find the number of clusters per condition needed for a trial with alpha = .05, 
#' # power = 0.8, 10 observations per cluster, matching correlation of 0.7, 
#' # a difference of 1 unit,  icc = 0.1 and a variance of five units.
#' crtpwr.2meanM(nsubjects=10 ,rho_m=0.7,d=1, icc=.1, vart=5)
#' # 
#' # The result, showimg nclusters of greater than 11, suggests 12 clusters per
#' # condition should be used.
#' @references Crespi CM. (2016) Improved Designs for Cluster Randomized Trials. Annu Rev Public Health. 
#'   37:1-16.
#' @export

crtpwr.2meanM <- function(alpha = 0.05, power = 0.80, nclusters = NA,
                          nsubjects = NA, d = NA, icc = NA,
                          vart = NA, rho_m = NA,
                          tol = .Machine$double.eps^0.25){
  
  if(!is.na(nclusters) && nclusters <= 1) {
    stop("'nclusters' must be greater than 1.")
  }
  
  # list of needed inputs
  needlist <- list(alpha, power, nclusters, nsubjects, d, icc, vart, rho_m)
  neednames <- c("alpha", "power", "nclusters", "nsubjects", "d", "icc", "vart", "rho_m")
  needind <- which(unlist(lapply(needlist, is.na)))
  
  # check to see that exactly one needed param is NA
  if (length(needind) != 1) {
    neederror = "Exactly one of 'alpha', 'power', 'nclusters', 'nsubjects', 'd', 'icc', 'vart', and 'rho_m' must be NA."
    stop(neederror)
  } 
  
  target <- neednames[needind]
  
  # evaluate power
  pwr <- quote({
    
    # design effect
    DEFF <- 1 + (nsubjects - 1)*icc - nsubjects*rho_m*icc
    
    tcrit <- qt(alpha/2, nclusters - 1, lower.tail = FALSE)
    
    ncp <- sqrt(nclusters*nsubjects/(2*DEFF)) * abs(d)/sqrt(vart)
    
    pt(tcrit, nclusters - 1, ncp, lower.tail = FALSE)
  })
  
  # calculate alpha
  if (is.na(alpha)) {
    alpha <- stats::uniroot(function(alpha) eval(pwr) - power,
                            interval = c(1e-10, 1 - 1e-10),
                            tol = tol)$root
  }
  
  # calculate power
  if (is.na(power)) {
    power <- eval(pwr)
  }
  
  # calculate nclusters
  if (is.na(nclusters)) {
    nclusters <- stats::uniroot(function(nclusters) eval(pwr) - power,
                        interval = c(2 + 1e-10, 1e+07),
                        tol = tol, extendInt = "upX")$root
  }
  
  # calculate nsubjects
  if (is.na(nsubjects)) {
    nsubjects <- stats::uniroot(function(nsubjects) eval(pwr) - power,
                        interval = c(2 + 1e-10, 1e+07),
                        tol = tol, extendInt = "upX")$root
  }
  
  # calculate d
  if (is.na(d)) {
    d <- stats::uniroot(function(d) eval(pwr) - power,
                        interval = c(1e-07, 1e+07),
                        tol = tol, extendInt = "upX")$root
  }
  
  # calculate icc
  if (is.na(icc)){
    icc <- stats::uniroot(function(icc) eval(pwr) - power,
                          interval = c(1e-07, 1- 1e-07),
                          tol = tol)$root
  }
  
  # calculate vart
  if (is.na(vart)) {
    vart <- stats::uniroot(function(vart) eval(pwr) - power,
                           interval = c(1e-07, 1e+07),
                           tol = tol, extendInt = "downX")$root
  }
  
  # calculate rho_m
  if (is.na(rho_m)){
    rho_m <- stats::uniroot(function(rho_m) eval(pwr) - power,
                          interval = c(1e-07, 1- 1e-07),
                          tol = tol)$root
  }
  
  structure(get(target), names = target)
  
}
