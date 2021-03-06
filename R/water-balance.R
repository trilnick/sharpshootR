
# http://hydromad.catchment.org/#bucket
# https://github.com/josephguillaume/hydromad/blob/master/src/bucket.c

## consider implementation as a GRASS t.* routine or t.mapcalc expression


#' @title Monthly Water Balances
#' 
#' @description Perform a monthly water balance by "leaky bucket" model, provided by the `hydromad` package.
#' 
#' @note This function depends on the \href{http://hydromad.catchment.org/}{hydromad package}.
#' 
#' @author D.E. Beaudette
#' 
#' @param AWC available water-holding capacity (mm)
#' 
#' @param PPT time-series of monthly PPT (mm), calendar year ordering
#' 
#' @param PET time-series of monthly PET (mm), calendar year ordering
#' 
#' @param S_init initial fraction of \code{AWC} filled with water
#' 
#' @param starting_month starting month index, 1=January, 9=September
#' 
#' @param rep number of cycles to run water balance
#' 
#' @param keep_last keep only the last iteration of the water balance
#' 
#' 
#' @return a \code{data.frame} with the following elements:
#' 
#' \itemize{
#' \item{PPT: }{monthly PPT values}
#' \item{PET: }{monthly PET values}
#' \item{U: }{monthly U values}
#' \item{S: }{monthly S values}
#' \item{ET: }{monthly ET values}
#' \item{D: }{monthly D values}
#' \item{month: }{month number}
#' \item{mo: }{month label}   
#' }
#' 
#' @examples 
#' 
#' if(requireNamespace('hydromad')) {
#' 
#' # AWC in mm
#' AWC <- 200
#' 
#' # monthly PET and PPT in mm
#' PET <- c(0,0,5,80,90,120,130,140,110,90,20,5)
#' PPT <- c(0, 150, 200, 120, 20, 0, 0, 0, 10, 20, 30, 60)
#' 
#' # run water balance
#' # start with soil AWC "empty"
#' (x.wb <- monthlyWB(AWC, PPT, PET, S_init = 0))
#' 
#' # plot the results
#' par(mar=c(4,4,2,1), bg = 'white')
#' plotWB(WB = x.wb, AWC = AWC)
#' 
#' # compute fraction of AWC filled after the last month of simulation
#' (last.S <- x.wb$S[12] / AWC)
#' 
#' # re-run the water balance with this value
#' (x.wb <- monthlyWB(AWC, PPT, PET, S_init = last.S))
#' 
#' # not much difference
#' par(mar=c(4,4,2,1), bg = 'white')
#' plotWB(WB = x.wb, AWC = AWC)
#' 
#' }
#' 
#' 
#'
monthlyWB <- function(AWC, PPT, PET, S_init = AWC, starting_month = 1, rep = 1, keep_last = FALSE) {
  
  # sanity check: package requirements
  if(!requireNamespace('hydromad'))
    stop('please install the hydromad package', call. = FALSE)
  
  # number of time steps in the original series
  n <- length(PPT)
  
  # re-order monthly data acording to starting month
  if(starting_month == 1) {
    idx <- seq(from=starting_month, to=12, by = 1)
  } else {
    idx <- c(seq(from=starting_month, to=12, by=1), seq(from=1, to=(starting_month - 1), by=1))
  }
  
  # replicate as needed
  idx <- rep(idx, times=rep)
  
  # re-index months as needed
  PPT <- PPT[idx]
  PET <- PET[idx]
  
  # combine into format suitable for simulation
  d <- data.frame(P=PPT, E=PET)
  
  # Sb (total water storage): 250mm depth * 0.33 satiated VWC = 82.5mm
  # fc (field capacity fraction): 250mm depth * 0.24 1/3bar water retention / Sb = 0.73
  # S_0 (intitial moisture content as fraction of Sb): 
  m <- hydromad::hydromad(d, sma = "bucket", routing = NULL)
  m <- update(m, Sb=AWC, fc=1, S_0=S_init, a.ss=0, M=0, etmult=1, a.ei=0)
  res <- predict(m, return_state = TRUE)
  
  res <- data.frame(d, res)
  
  names(res) <- c('PPT', 'PET', 'U', 'S', 'ET')
  res$D <- with(res, ET - PET)
  
  # add month index
  res$month <- idx
  res$mo <- c('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')[idx]
  
  # optionally keep the last cycle
  if(keep_last) {
    keep.idx <- seq(from=nrow(res) - (n-1), to = nrow(res), by = 1)
    res <- res[keep.idx, ]
  }
  
  # done
  return(res)
}



#' @title Visualize Monthly Water Balance
#' 
#' @description This function offers one possible visualization for the results of \code{monthlyWB}.
#' 
#' @author D.E. Beaudette
#' 
#' @param WB output from \code{monthlyWB}
#' 
#' @param AWC available water-holding capacity (mm)
#' 
#' @param fig.title a title
#'
#' @param sw.col color for soil water
#' 
#' @param surplus.col color for surplus water
#' 
#' @param et.col color for ET
#' 
#' @param deficit.col color for deficit
#' 
#' @param pch plotting character for points (default: 22)
#' 
#' @param pt.cex character expansion factor for points (default: 1)
#' 
#' @param lwd line width (default: 1)
#' 
#' @keywords hplots
#' 
plotWB <- function(WB, AWC, fig.title='', sw.col='#377EB8', surplus.col='#4DAF4A', et.col='#E41A1C', deficit.col='#FF7F00', pch = 22, pt.cex = 1, lwd = 1) {
  
  # number of time steps, usually months
  n <- nrow(WB)
  
  # left-side vertical scales
  # y.axt <- pretty(c(AWC + WB$U, WB$PPT, 0 - WB$PET), n = 15)
  y.min <- min(- WB$PET)
  y.max <- max(AWC + WB$U)
  
  # max for PPT|AWC
  ppt.awc.max <- max(AWC + WB$U)
  
  # specific axis
  # surplus.axis <- pretty(WB$U, n = 5)
  ppt.axis <- pretty(c(0, ppt.awc.max), n = 5)
  pet.axis <- pretty(WB$PET, n = 5)
  
  # remove '0' from surplus and pet axes
  pet.axis <- pet.axis[pet.axis != 0]
  # surplus.axis <- surplus.axis[surplus.axis != 0]

  # init barplot x-axis
  bp <- barplot(AWC + WB$S, plot=FALSE)
  bp <- as.vector(bp)
  
  # init canvas
  plot(1, 1, type='n', ylim=c(y.min, y.max), xlim=c(0, max(bp)),  axes=FALSE, ylab='', xlab='')
  
  # segments(x0=0, y0=y.axt, x1=max(bp), y1=y.axt, lty=2, col=grey(0.45))
  
  # plot surplus
  barplot(AWC + WB$U, axes=FALSE, ylab='', xlab='', col=surplus.col, border=NA, add=TRUE)
  
  # overlay AWC with white to erase surplus within AWC
  barplot(rep(AWC, times=n), axes=FALSE, col=par('bg'), border=NA, add=TRUE)
  
  # overlay soil water
  barplot(WB$S, axes=FALSE, col=sw.col, border=NA, add=TRUE)
  
  # utilization of soil water
  # barplot(WB$u_i, axes=FALSE, col='orange', border=NA, add=TRUE)
  
  # add deficit
  barplot((0 - WB$E) + WB$D, axes=FALSE, col=deficit.col, border=NA, add=TRUE)
  
  # overlay actual ET
  barplot(0 - WB$E, axes=FALSE, col=et.col, border=NA, add=TRUE)
  
  # annotate AWC
  rect(xleft = 0.2, ybottom = 0, xright = n + (n * 0.2), ytop = AWC)
  
  # left-hand axes
  combined.at <- c(-pet.axis, ppt.axis)
  combined.lab <- c(pet.axis, ppt.axis)
  axis(side = 2, las=1, at = combined.at, labels = combined.lab, cex.axis=0.85, line=-0.5)
  
  # # right-hand axis
  # axis(side = 4, las=1, at = AWC+surplus.axis, labels = surplus.axis, cex.axis=0.85, line=-1)
  
  # annotate left-hand axes
  # positive side
  # mtext(text = 'PPT | Soil Water', side = 2, line = 2.25, at=10, adj=0, cex=0.85, font=2)
  # mtext(text = 'Surplus', side = 4, line = 2.25, at=y.max, adj=1, cex=0.85, font=2)
  # negative side
  mtext(text = 'PET | ET | Deficit | Soil Water | Surplus     (mm)', side = 2, line = 2.25, cex=0.85, font=2)
  
  # annotate AWC
  text(x=0, y=AWC/2, labels = sprintf("AWC: %smm", AWC), srt=90, cex=0.85, font=1)
  
  # month axis
  axis(side = 1, at = bp, labels = WB$mo, line=0, tick = FALSE, font=2)
  
  # add PPT and PET series
  lines(bp, WB$PPT, type='l', col=par('fg'), lwd = lwd)
  points(bp, WB$PPT, col=par('bg'), bg=par('fg'), pch = pch, cex = pt.cex)
  lines(bp, 0 - WB$PET, type='l', col=par('fg'), lwd = lwd)
  points(bp, 0 - WB$PET, col=par('bg'), bg=par('fg'), pch = pch, cex = pt.cex)
  
  # legend
  legend(x=max(bp), y=y.max, horiz = TRUE, legend=c('Soil Water', 'Surplus', 'ET', 'Deficit'), col=c(sw.col, surplus.col, et.col, deficit.col), pch = 15, bty='n', pt.cex = 1.5, xpd=NA, cex=1.125, xjust = 1, yjust=0)
  
  # title
  mtext(fig.title, side = 3, adj=0, at=-0.5, cex=1.5, font=2)
  
}


