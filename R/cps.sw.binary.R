#' Power simulations for cluster-randomized trials: Stepped Wedge Design, Binary Outcome
#'
#' This set of functions utilize iterative simulations to determine 
#' approximate power for stepped wedge cluster-randomized controlled trials. Users 
#' can modify a variety of parameters to suit the simulations to their
#' desired experimental situation.
#' 
#' Runs power simulations for stepped wedge cluster-randomized controlled trials with a binary outcome.
#' 
#' Users must specify the desired number of simulations, number of subjects per 
#' cluster, number of clusters per treatment arm, expected absolute difference 
#' between treatment arms, within-cluster variance, between-cluster variance, 
#' significance level, analytic method, progress updates, and simulated data 
#' set output may also be specified.
#' 
#' 
#' @param nsim Number of datasets to simulate; accepts integer (required).
#' @param nsubjects Number of subjects per cluster; accepts either a scalar (equal cluster sizes) 
#' or a vector of length \code{nclusters} (user-defined size for each cluster) (required).
#' @param nclusters Number of clusters; accepts non-negative integer scalar (required).
#' @param p.ntrt Expected probability of outcome in non-treatment group. Accepts scalar between 0 - 1 (required).
#' @param p.trt Expected probability of outcome in treatment group. Accepts scalar between 0 - 1 (required).
#' @param steps Number of crossover steps; a baseline step (all clusters in non-treatment group) is assumed. 
#' Accepts positive scalar (indicating the total number of steps; clusters per step is obtained by 
#' \code{nclusters / steps}) or a vector of non-negative integers corresponding either to the number 
#' of clusters to be crossed over at each time point (e.g c(2,4,4,2); nclusters = 10) or the cumulative 
#' number of clusters crossed over by a given time point (e.g. c(2,4,8,10); nclusters = 10) (required).
#' @param sigma_b Between-cluster variance; accepts non-negative numeric scalar (indicating equal 
#' between-cluster variances for both treatment groups) or a vector of length 2 specifying treatment-specific 
#' between-cluster variances (required).
#' @param alpha Significance level. Default = 0.05.
#' @param method Analytical method, either Generalized Linear Mixed Effects Model (GLMM) or 
#' Generalized Estimating Equation (GEE). Accepts c('glmm', 'gee') (required); default = 'glmm'.
#' @param quiet When set to FALSE, displays simulation progress and estimated completion time; default is FALSE.
#' @param all.sim.data Option to output list of all simulated datasets; default = FALSE.
#' 
#' @return A list with the following components
#' \describe{
#'   \item{overview}{Character string indicating total number of simulations and simulation type}
#'   \item{nsim}{Number of simulations}
#'   \item{power}{Data frame with columns "Power" (Estimated statistical power), 
#'                "lower.95.ci" (Lower 95% confidence interval bound), 
#'                "upper.95.ci" (Upper 95% confidence interval bound)}
#'   \item{method}{Analytic method used for power estimation}
#'   \item{alpha}{Significance level}
#'   \item{cluster.sizes}{Vector containing user-defined cluster sizes}
#'   \item{n.clusters}{Vector containing user-defined number of clusters}
#'   \item{variance.parms}{Data frame reporting ICC, within & between cluster variances for Treatment/Non-Treatment groups at each time point}
#'   \item{inputs}{Vector containing expected difference between groups based on user inputs}
#'   \item{means}{Data frame containing mean response values for each treatment group at each time point}
#'   \item{crossover.matrix}{Matrix showing cluster crossover at each time point}
#'   \item{model.estimates}{Data frame with columns: 
#'                   "Estimate" (Estimate of treatment effect for a given simulation), 
#'                   "Std.err" (Standard error for treatment effect estimate), 
#'                   "Test.statistic" (z-value (for GLMM) or Wald statistic (for GEE)), 
#'                   "p.value", 
#'                   "sig.val" (Is p-value less than alpha?)}
#'   \item{sim.data}{List of data frames, each containing: 
#'                   "y" (Simulated response value), 
#'                   "trt" (Indicator for treatment group),
#'                   "time.point" (Indicator for step; "t1" = time point 0) 
#'                   "clust" (Indicator for cluster), 
#'                   "period" (Indicator for at which step a cluster crosses over)}
#' }
#' 
#' @author Alexander R. Bogdan
#' 
#' @examples 
#' \dontrun{
#' binary.sw.rct = cps.sw.binary(nsim = 100, nsubjects = 50, nclusters = 30, 
#'                               p.ntrt = 0.1, p.trt = 0.2, steps = 5, 
#'                               sigma_b = 30, alpha = 0.05, method = 'glmm', 
#'                               quiet = FALSE, all.sim.data = FALSE)
#' }
#'
#' @export

cps.sw.binary = function(nsim = NULL, nsubjects = NULL, nclusters = NULL, p.ntrt = NULL, 
                         p.trt = NULL, steps = NULL, sigma_b = NULL, alpha = 0.05, 
                         method = 'glmm', quiet = FALSE, all.sim.data = FALSE){
  
  # Create vectors to collect iteration-specific values
  est.vector = NULL
  se.vector = NULL
  stat.vector = NULL
  pval.vector = NULL
  lmer.icc.vector = NULL
  simulated.datasets = list()
  
  # Set start.time for progress iterator & initialize progress bar
  start.time = Sys.time()
  prog.bar =  progress::progress_bar$new(format = "(:spin) [:bar] :percent eta :eta", 
                                         total = nsim, clear = FALSE, width = 100)
  prog.bar$tick(0)
  
  # Create wholenumber function
  is.wholenumber = function(x, tol = .Machine$double.eps^0.5)  abs(x - round(x)) < tol
  
  # Define expit function
  expit = function(x)  1 / (1 + exp(-x))
  
  # Validate NSIM, NSUBJECTS, NCLUSTERS, DIFFERENCE
  sim.data.arg.list = list(nsim, nclusters, nsubjects)
  sim.data.args = unlist(lapply(sim.data.arg.list, is.null))
  if(sum(sim.data.args) > 0){
    stop("NSIM, NCLUSTERS, NSUBJECTS & DIFFERENCE must all be specified. Please review your input values.")
  }
  min1.warning = " must be an integer greater than or equal to 1"
  if(!is.wholenumber(nsim) || nsim < 1){
    stop(paste0("NSIM", min1.warning))
  }
  if(!is.wholenumber(nclusters) || nclusters < 1){
    stop(paste0("NCLUSTERS", min1.warning))
  }
  if(!is.wholenumber(nsubjects) || nsubjects < 1){
    stop(paste0("NSUBJECTS", min1.warning))
  }
  if(length(nclusters) != 1){
    stop("NCLUSTERS must be a scalar (Total number of clusters)")
  }
  # Set sample sizes for each cluster (if not already specified)
  if(length(nsubjects) == 1){
    nsubjects[1:nclusters] = nsubjects
  }
  if(!length(nsubjects) %in% c(1, nclusters)){
    stop("NSUBJECTS must either be a scalar (indicating equal cluster sizes) or a vector of length NCLUSTERS (specifying cluster sizes for each cluster).")
  }
  
  # Validate P.NTRT & P.TRT
  min0.warning = " must be a numeric value between 0 - 1"
  if(p.ntrt < 0 || p.ntrt > 1){
    stop("P.NTRT", min0.warning)
  }
  if(p.trt < 0 || p.trt > 1){
    stop("P.TRT", min0.warning)
  }
  
  # Validate STEPS
  if(!is.wholenumber(steps) || steps < 0){
    stop("All values supplied to STEPS must be non-negative integers")
  }
  if(length(steps) > 1){
    if(sum(steps) != nclusters && max(steps) != nclusters){
      stop("Total number of clusters specified by STEPS must either sum to NCLUSTERS or increase monotonically such that max(STEPS) == NCLUSTERS")
    }
  }
  if(length(steps) == 1){
    crossover.ind = 1:steps
    step.increment = nclusters / steps
    step.index = seq(from = step.increment, to = nclusters, by = step.increment)
    ### Need to figure out how to allocate clusters when nclusters %% steps != 0
  }
  # Create indexing vector for when SUM(STEPS) == NCLUSTERS
  if(sum(steps) == nclusters){
    step.index = sapply(1:length(steps), function(x) sum(steps[0:x]))
    crossover.ind = 1:length(steps)
  }
  if(max(steps) == nclusters){
    crossover.ind = 1:length(steps)
    step.index = steps
  }
  
  # Create vector to store group means at each time point
  values.vector = cbind(c(rep(0, length(step.index) * 2)))
  
  # Validate SIGMA_B
  sigma_b.warning = " must be a scalar (equal between-cluster variance for both treatment and non-treatment groups) 
  or a vector of length 2, specifying unique between-cluster variances for the treatment and non-treatment groups."
  if(!is.numeric(sigma_b) || any(sigma_b < 0)){
    stop("All values supplied to SIGMA_B must be numeric values >= 0")
  }
  if(!length(sigma_b) %in% c(1, 2)){
    stop("SIGMA_B", sigma_b.warning)
  }
  # Set SIGMA_B (if not already set)
  # Note: If user-defined, SIGMA_B[2] is additive
  if(length(sigma_b) == 2){
    sigma_b[2] = sigma_b[1] + sigma_b[2]
  }
  if(length(sigma_b) == 1){
    sigma_b[2] = sigma_b
  }
  
  # Validate ALPHA, METHOD, QUIET, ALL.SIM.DATA
  if(!is.numeric(alpha) || alpha < 0 || alpha > 1){
    stop("ALPHA", min0.warning)
  }
  if(!is.element(method, c('glmm', 'gee'))){
    stop("METHOD must be either 'glmm' (Generalized Linear Mixed Model)
         or 'gee'(Generalized Estimating Equation)")
  }
  if(!is.logical(quiet)){
    stop("QUIET must be either TRUE (No progress information shown) or FALSE (Progress information shown)")
  }
  if(!is.logical(all.sim.data)){
    stop("ALL.SIM.DATA must be either TRUE (Output all simulated data sets) or FALSE (No simulated data output")
  }
  
  # Calculate ICC1 (sigma_b / (sigma_b + pi^2/3))
  icc1 = mean(sapply(1:2, function(x) sigma_b[x] / (sigma_b[x] + pi^2 / 3)))
  
  # Create indicators for CLUSTER, STEP (period) & CROSSOVER (trt)
  clust = unlist(lapply(1:nclusters, function(x) rep(x, length.out = nsubjects[x])))
  period = NULL
  k = 1 # iterator
  for(i in 1:nclusters){
    if((i - 1) %in% step.index){
      k = k + 1
    }
    period = append(period, rep(crossover.ind[k], length.out = nsubjects[i]))
  }
  d = data.frame(period = period, clust = clust)
  
  # Create crossover indicators and melt output columns into single column
  for(j in 1:(length(crossover.ind) + 1)){
    d[[paste0("t", j)]] = ifelse(j > d[, 'period'], 1, 0)
  }
  sim.dat = tidyr::gather(d, key = 'time.point', value = 'trt', c(colnames(d)[-c(1,2)]))
  sim.dat['y'] = 0
  
  # Calculate log odds for each group
  logit.p.ntrt = log(p.ntrt / (1 - p.ntrt))
  logit.p.trt = log(p.trt / (1 - p.trt))
  
  
  ## Create simulation & analysis loop
  for (i in 1:nsim){
    # Create vectors of cluster effects
    ntrt.cluster.effects = stats::rnorm(nclusters, mean = 0, sd = sqrt(sigma_b[1]))
    trt.cluster.effects = stats::rnorm(nclusters, mean = 0, sd = sqrt(sigma_b[2]))
    
    # Add subject specific effects & cluster effects
    for(j in 1:nclusters){
      # Assign non-treatment subject & cluster effects 
      sim.dat['y'] = ifelse(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 0, 
                            stats::rbinom(sum(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 0), 1, 
                                   expit(logit.p.ntrt + 
                                         ntrt.cluster.effects[j] + 
                                         stats::rnorm(sum(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 0)))),
                            sim.dat[, 'y'])
      # Assign treatment subject & cluster effects
      sim.dat['y'] = ifelse(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 1, 
                            stats::rbinom(sum(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 1), 1, 
                                   expit(logit.p.trt + 
                                         trt.cluster.effects[j] + 
                                         stats::rnorm(sum(sim.dat[, 'clust'] == j & sim.dat[, 'trt'] == 1)))),
                            sim.dat[, 'y'])
    }
    
    # Calculate LMER.ICC (lmer: sigma_b / (sigma_b + sigma))
    lmer.mod = lme4::lmer(y ~ trt + time.point + (1|clust), data = sim.dat)
    lmer.vcov = as.data.frame(lme4::VarCorr(lmer.mod))[, 4]
    lmer.icc.vector =  append(lmer.icc.vector, lmer.vcov[1] / (lmer.vcov[1] + lmer.vcov[2]))
    
    # Calculate mean values for each group at each time point, for a given simulation
    iter.values = cbind(stats::aggregate(y ~ trt + time.point, data = sim.dat, mean)[, 3])
    values.vector = values.vector + iter.values
    
    # Store simulated data sets if ALL.SIM.DATA == TRUE 
    if(all.sim.data == TRUE){
      simulated.datasets = append(simulated.datasets, list(sim.dat))
    }
    
    # Fit GLMM (lmer)
    if(method == 'glmm'){
      my.mod = lme4::glmer(y ~ trt + time.point + (1|clust), data = sim.dat, family = stats::binomial(link = 'logit'))
      glmm.values = summary(my.mod)$coefficient
      est.vector = append(est.vector, glmm.values['trt', 'Estimate'])
      se.vector = append(se.vector, glmm.values['trt', 'Std. Error'])
      stat.vector = append(stat.vector, glmm.values['trt', 'z value'])
      pval.vector = append(pval.vector, glmm.values['trt', 'Pr(>|z|)'])
    }
    
    # Fit GEE (geeglm)
    if(method == 'gee'){
      sim.dat = dplyr::arrange(sim.dat, clust)
      my.mod = geepack::geeglm(y ~ trt + time.point, data = sim.dat,
                               family = stats::binomial(link = 'logit'), 
                               id = clust, corstr = "exchangeable")
      gee.values = summary(my.mod)$coefficients
      est.vector = append(est.vector, gee.values['trt', 'Estimate'])
      se.vector = append(se.vector, gee.values['trt', 'Std.err'])
      stat.vector = append(stat.vector, gee.values['trt', 'Wald'])
      pval.vector = append(pval.vector, gee.values['trt', 'Pr(>|W|)'])
    }
    
    # Update progress information
    if(quiet == FALSE){
      if(i == 1){
        avg.iter.time = as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
        time.est = avg.iter.time * (nsim - 1) / 60
        hr.est = time.est %/% 60
        min.est = round(time.est %% 60, 0)
        message(paste0('Begin simulations :: Start Time: ', Sys.time(), 
                       ' :: Estimated completion time: ', hr.est, 'Hr:', min.est, 'Min'))
      }
      # Iterate progress bar
      prog.bar$update(i / nsim)
      Sys.sleep(1/100)
      
      if(i == nsim){
        total.est = as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
        hr.est = total.est %/% 3600
        min.est = total.est %/% 60
        sec.est = round(total.est %% 60, 0)
        message(paste0("Simulations Complete! Time Completed: ", Sys.time(), 
                       "\nTotal Runtime: ", hr.est, 'Hr:', min.est, 'Min:', sec.est, 'Sec'))
      }
    }
  }
  
  ## Output objects
  # Create object containing summary statement
  summary.message = paste0("Monte Carlo Power Estimation based on ", nsim, " Simulations: Stepped Wedge Design, Binary Outcome")
  
  # Create method object
  long.method = switch(method, glmm = 'Generalized Linear Mixed Model', 
                       gee = 'Generalized Estimating Equation')
  
  # Store simulation output in data frame
  cps.model.est = data.frame(Estimate = as.vector(unlist(est.vector)),
                             Std.err = as.vector(unlist(se.vector)),
                             Test.statistic = as.vector(unlist(stat.vector)),
                             p.value = as.vector(unlist(pval.vector)))
  cps.model.est[, 'sig.val'] = ifelse(cps.model.est[, 'p.value'] < alpha, 1, 0)
  
  # Calculate and store power estimate & confidence intervals
  pval.power = sum(cps.model.est[, 'sig.val']) / nrow(cps.model.est)
  power.parms = data.frame(Power = round(pval.power, 3),
                           Lower.95.CI = round(pval.power - abs(stats::qnorm(alpha / 2)) * sqrt((pval.power * (1 - pval.power)) / nsim), 3),
                           Upper.95.CI = round(pval.power + abs(stats::qnorm(alpha / 2)) * sqrt((pval.power * (1 - pval.power)) / nsim), 3))
  
  # Create object containing treatment & time-specific differences
  values.vector = values.vector / nsim
  group.means = data.frame(Time.point = c(0, rep(1:(length(step.index) - 1), each = 2), length(step.index)), 
                           Treatment = c(0, rep(c(0, 1), length.out = (length(step.index) - 1) * 2), 1), 
                           Values = round(values.vector, 3))
  
  # Create object containing expected treatment and non-treatment probabilities
  group.probs = data.frame("Outcome.Probabilities" = c("Non.Treatment" = p.ntrt, "Treatment" = p.trt))
  
  # Create object containing cluster sizes
  cluster.sizes = nsubjects
  
  # Create object containing number of clusters
  n.clusters = t(data.frame("Non.Treatment" = c("n.clust" = nclusters[1]), "Treatment" = c("n.clust" = nclusters[2])))
  
  # Create object containing estimated ICC values
  ICC = round(t(data.frame('P_h' = c('ICC' = icc1), 
                           'lmer' = c('ICC' = mean(lmer.icc.vector)))), 3)
  
  # Create object containing variance parameters for each group at each time point
  var.parms = t(data.frame('Non.Treatment' = c('sigma_b' = sigma_b[1]), 
                           'Treatment' = c('sigma_b' = sigma_b[2])))
  
  # Create crossover matrix output object
  crossover.mat = apply(as.matrix(c(0, step.index)), 1, 
                        function(x) c(rep(1, length.out = x), rep(0, length.out = nclusters - x)))
  
  # Create list containing all output (class 'crtpwr') and return
  complete.output = structure(list("overview" = summary.message, "nsim" = nsim, "power" = power.parms, "method" = long.method, "alpha" = alpha,
                                   "cluster.sizes" = cluster.sizes, "n.clusters" = n.clusters, "variance.parms" = var.parms,
                                   "inputs" = group.probs, "means" = group.means, "icc" = ICC, "model.estimates" = cps.model.est, "sim.data" = simulated.datasets, 
                                   "crossover.matrix" = crossover.mat),
                              class = 'crtpwr')
  
  return(complete.output)
  }
