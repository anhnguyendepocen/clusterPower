#' Power calculations for simple cluster randomized trials, continuous outcome
#'
#' Compute the power of a simple cluster randomized trial with a continuous outcome,
#' or determine parameters to obtain a target power.
#'
#' Exactly one of \code{alpha}, \code{power}, \code{nclusters}, \code{nsubjects},
#'   \code{cv}, \code{d}, \code{icc}, and \code{vart}  must be passed as \code{NA}.
#'   Note that \code{alpha}, \code{power}, and \code{cv} have non-\code{NA}
#'   defaults, so if those are the parameters of interest they must be
#'   explicitly passed as \code{NA}.
#'   
#' If \code{nsubjects} is a vector the values, \code{nclusters} and \code{cv} will be recalculated
#'    using the values in \code{nsubjects}. If \code{nsubjects} is a vector and \code{method} is
#'    "taylor", the exact relative efficiency will be calculated as described in
#'    van Breukelen et al (2007).
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
#' @param nsubjects The mean of the cluster sizes, or a vector of cluster sizes for one arm.
#' @param cv The coefficient of variation of the cluster sizes. When \code{cv} = 0,
#'   the clusters all have the same size.
#' @param d The difference in condition means.
#' @param icc The intraclass correlation.
#' @param vart The total variation of the outcome (the sum of within- and between-cluster variation).
#' @param method The method for calculating variance inflation due to unequal cluster
#'   sizes. Either a method based on Taylor approximation of relative efficiency 
#'   ("taylor"), or weighting by cluster size ("weighted")
#' @param tol Numerical tolerance used in root finding. The default provides
#'   at least four significant digits.
#' @return The computed argument.
#' @examples 
#' # Find the number of clusters per condition needed for a trial with alpha = .05, 
#' # power = 0.8, 10 observations per cluster, no variation in cluster size, a difference 
#' # of 1 unit,  icc = 0.1 and   a variance of five units.
#' crtpwr.2mean(nsubjects=10 ,d=1, icc=.1, vart=5)
#' # 
#' # The result, showimg nclusters of greater than 15, suggests 16 clusters per 
#' # condition should be used.
#' @references Eldridge SM, Ukoumunne OC, Carlin JB. (2009) The Intra-Cluster Correlation
#'   Coefficient in Cluster Randomized Trials: A Review of Definitions. Int Stat Rev. 
#'   77: 378-394.
#' @references Eldridge SM, Ashby D, Kerry S. (2006) Sample size for cluster randomized
#'   trials: effect of coefficient of variation of cluster size and analysis method.
#'   Int J Epidemiol. 35(5):1292-300.
#' @references van Breukelen GJP, Candel MJJM, Berger MPF. (2007) Relative efficiency of
#'   unequal versus equal cluster sizes in cluster randomized and multicentre trials.
#'   Statist Med. 26:2589-2603.  
#' @export

crtpwr.2mean <- function(alpha = 0.05, power = 0.80, nclusters = NA,
                         nsubjects = NA, cv = 0,
                         d = NA, icc = NA,
                         vart = NA,
                         method = c("taylor", "weighted"),
                         tol = .Machine$double.eps^0.25){
  
  method <- match.arg(method)
  
  # if nsubjects is a vector, 
  if(length(nsubjects) > 1){
    nvec <- nsubjects
    nsubjects <- mean(nvec)
    nsd <- stats::sd(nvec)
    cv <- nsd/nsubjects
    nclusters <- length(nvec)
  }
  
  if(!is.na(nclusters) && nclusters <= 1) {
    stop("'nclusters' must be greater than 1.")
  }

  
  # list of needed inputs
  needlist <- list(alpha, power, nclusters, nsubjects, cv, d, icc, vart)
  neednames <- c("alpha", "power", "nclusters", "nsubjects", "cv", "d", "icc", "vart")
  needind <- which(unlist(lapply(needlist, is.na)))
  # check to see that exactly one needed param is NA
  
  if (length(needind) != 1) {
    neederror = "Exactly one of 'alpha', 'power', 'nclusters', 'nsubjects', 'cv', 'd', 'icc' and 'vart' must be NA."
    stop(neederror)
  } 
  
  target <- neednames[needind]
  
  # evaluate power
  pwr <- quote({
  
    # variance inflation
    # if nvec exists, calcuate exact relative efficiency
    if (exists("nvec")) {
      if(method == "taylor"){
        a <- (1 - icc)/icc
        DEFF <- 1 + (nsubjects - 1)*icc
        RE <- ((nsubjects + a)/nsubjects)*(sum((nvec/(nvec+a)))/nclusters) # exact relative efficiency
        VIF <- DEFF*RE
      } else{
        VIF <- 1 + ((cv^2 + 1)*nsubjects - 1)*icc
      }
    } else if(!is.na(nsubjects)){
      if(method == "taylor"){
        DEFF <- 1 + (nsubjects - 1)*icc
        L <- nsubjects*icc/DEFF
        REt <- 1/(1 - cv^2*L*(1 - L)) # taylor approximation
        VIF <- DEFF*REt
      } else {
        VIF <- 1 + ((cv^2 + 1)*nsubjects - 1)*icc
      }
    }
    
    tcrit <- qt(alpha/2, 2*(nclusters - 1), lower.tail = FALSE)
    
    ncp <- sqrt(nclusters*nsubjects/(2*VIF)) * abs(d)/sqrt(vart)
    
    pt(tcrit, 2*(nclusters - 1), ncp, lower.tail = FALSE) #+ pt(-tcrit, 2*(nclusters - 1), ncp, lower.tail = TRUE)
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
  
  # calculate cv
  if (is.na(cv)) {
    cv <- stats::uniroot(function(cv) eval(pwr) - power,
                  interval = c(1e-10, 1e+07),
                  tol = tol, extendInt = "downX")$root
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
                   interval = c(1e-07, 1 - 1e-07),
                   tol = tol)$root
  }
  
  # calculate vart
  if (is.na(vart)) {
    vart <- stats::uniroot(function(vart) eval(pwr) - power,
                    interval = c(1e-07, 1e+07),
                    tol = tol, extendInt = "downX")$root
  }
  
  structure(get(target), names = target)
  
  # method <- paste("Clustered two-sample t-test power calculation: ", target, sep = "")
  # note <- "'nclusters' is the number of clusters in each group and 'nsubjects' is the number of individuals in each cluster."
  # structure(list(alpha = alpha, power = power, nclusters = nclusters, nsubjects = nsubjects, cv = cv, d = d,
  #                icc = icc, vart = vart, note = note, method = method),
  #           class = "power.htest")
  
}
