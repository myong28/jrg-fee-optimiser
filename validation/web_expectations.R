# Expected results for the web app's three presets, solved with lpSolve.
# Mirrors the JS model exactly: no goal-seeking targets, lexicographic stages.
# Reads the site's exact baked-in inputs (official 2026 statutory rates from
# the Department of Education's "Indexed rates - amounts for 2026").

library(data.table)
library(lpSolve)

# Resolve the inputs file relative to this script so the repo can be moved.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
this_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[1]))) else "."
base <- fread(file.path(this_dir, "site_inputs_2026_statutory.csv"))
setorder(base, id)
base[, jrg_rev_pct := jrgRevPct]

# effective caps for the presets (paper caps on, default protections, no
# single-increase cap): the CSV's paperCap already encodes the per-field rules
base[, cap := pmin(14900, paperCap, U0)]

K <- nrow(base)
qm <- base$q / 1e6   # scale to $m
totG <- sum(qm * base$G0)
totR <- sum(qm * base$U0)

# Variables: S(1:K), G(K+1:2K), P(2K+1:3K), A(3K+1:4K), H(4K+1)
solve_preset <- function(revMode, gMult, rMult, priorities,
                         Rmin = NULL, Rmax = NULL) {
  nv <- 4 * K + 1
  iS <- 1:K; iG <- (K + 1):(2 * K); iP <- (2 * K + 1):(3 * K)
  iA <- (3 * K + 1):(4 * K); iH <- 4 * K + 1
  A <- list(); dir <- c(); rhs <- c()
  add <- function(row, d, r) {
    A[[length(A) + 1]] <<- row; dir <<- c(dir, d); rhs <<- c(rhs, r)
  }
  # field revenue
  for (i in 1:K) {
    row <- rep(0, nv); row[iS[i]] <- 1; row[iG[i]] <- 1
    if (revMode == "fixed") add(row, "=", base$U0[i])
    else { add(row, ">=", Rmin[i]); add(row, "<=", Rmax[i]) }
  }
  # aggregates
  row <- rep(0, nv); row[iG] <- qm; add(row, "=", totG * gMult)
  if (revMode != "fixed") {
    row <- rep(0, nv); row[iS] <- qm; row[iG] <- qm; add(row, "=", totR * rMult)
  }
  # caps
  for (i in 1:K) { row <- rep(0, nv); row[iS[i]] <- 1; add(row, "<=", base$cap[i]) }
  # P >= S - S0 ; A >= S - S0 ; A >= S0 - S ; S - H <= S0
  for (i in 1:K) {
    row <- rep(0, nv); row[iP[i]] <- 1; row[iS[i]] <- -1; add(row, ">=", -base$S0[i])
    row <- rep(0, nv); row[iA[i]] <- 1; row[iS[i]] <- -1; add(row, ">=", -base$S0[i])
    row <- rep(0, nv); row[iA[i]] <- 1; row[iS[i]] <- 1; add(row, ">=", base$S0[i])
    row <- rep(0, nv); row[iS[i]] <- 1; row[iH] <- -1; add(row, "<=", base$S0[i])
  }
  objs <- list(
    maxInc = { o <- rep(0, nv); o[iH] <- 1; o },
    wInc = { o <- rep(0, nv); o[iP] <- qm; o },
    wMove = { o <- rep(0, nv); o[iA] <- qm; o }
  )
  mat <- do.call(rbind, A)
  zs <- c()
  for (p in priorities) {
    obj <- objs[[p]]
    sol <- lp("min", obj, mat, dir, rhs)
    if (sol$status != 0) stop("infeasible at stage ", p)
    z <- sol$objval
    zs <- c(zs, z)
    mat <- rbind(mat, obj); dir <- c(dir, "<="); rhs <- c(rhs, z * (1 + 1e-6) + 1e-4)
  }
  x <- sol$solution
  S <- x[iS]; G <- x[iG]
  list(S = S, G = G,
       studentSpend = sum(qm * S), govSpend = sum(qm * G),
       revenue = sum(qm * (S + G)),
       maxFee = max(S), maxInc = max(S - base$S0), maxCut = min(S - base$S0),
       nUp = sum(S - base$S0 > 0.5), nDown = sum(S - base$S0 < -0.5),
       stageVals = zs)
}

# Preset A: strict neutrality; minimise largest increase, then movement
pA <- solve_preset("fixed", 1, 1, c("maxInc", "wMove"))
# Preset B: JRG giveback bounds, revenue -2%, gov fixed; min weighted increases, then movement
Rmin <- ifelse(base$jrg_rev_pct > 0, base$U0 * 0.95, base$U0)
Rmax <- ifelse(base$jrg_rev_pct > 0, base$U0,
               base$U0 * (1 + pmin(0.125 * abs(base$jrg_rev_pct), 0.03)))
pB <- solve_preset("bounded", 1, 0.98, c("wInc", "maxInc", "wMove"), Rmin, Rmax)
# Preset C: gov +3%, field revenue fixed; min weighted increases, then movement
pC <- solve_preset("fixed", 1.03, 1, c("wInc", "maxInc", "wMove"))

fmt <- function(p) sprintf(
  '{"studentSpend":%.4f,"govSpend":%.4f,"revenue":%.4f,"maxFee":%.2f,"maxInc":%.2f,"maxCut":%.2f,"nUp":%d,"nDown":%d,"stage1":%.4f,"stage2":%.4f,"stage3":%.4f,"S":[%s]}',
  p$studentSpend, p$govSpend, p$revenue, p$maxFee, p$maxInc, p$maxCut,
  p$nUp, p$nDown, p$stageVals[1], p$stageVals[2], ifelse(length(p$stageVals)>2, p$stageVals[3], -1),
  paste(sprintf("%.2f", p$S), collapse = ","))

cat('{"A":', fmt(pA), ',"B":', fmt(pB), ',"C":', fmt(pC), '}\n', sep = "")
