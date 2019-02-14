
# cumulative PPT within a single water year
.cumulativePPT <- function(i) {
  i$cumulative_ppt <- cumsum(ifelse(is.na(i$value), 0, i$value))
  # number of days in summation
  i$n <- nrow(i)
  
  ## TODO: subset to rows of interest
  return(i)
}

# compute cumulative PPT by water year
.prepareCumulativePPT <- function(d) {
  ## NOTE: requires sharpshootR >= 1.4.02
  # re-order just in case
  d <- d[order(d$water_year, d$water_day), ]
  
  # compute cumulative PPT by water year, ordered by water day
  dd <- lapply(split(d, d$water_year), .cumulativePPT)
  dd <- do.call('rbind', dd)
  
  return(dd)
}



# get years and total PPT which are closest to given percentiles of annual PPT
.exemplarYears <- function(d) {
  
  # annual PPT by water year
  ppt.by.wy <- tapply(d$cumulative_ppt, d$water_year, max, na.rm=TRUE)
  # interesting percentiles of annual PPT
  ppt.q <- quantile(ppt.by.wy, probs=c(0.05, 0.25, 0.5, 0.75, 0.95), na.rm = TRUE)
  
  # find exemplars for select percentiles
  ppt.abs.diff <- abs(outer(ppt.by.wy, ppt.q, FUN = "-"))
  ppt.closest.yrs <- apply(ppt.abs.diff, 2, which.min)
  
  # this is a named vector of annual PPT (names are water_year)
  exemplar.data <- ppt.by.wy[ppt.closest.yrs]
  
  return(exemplar.data)
}


## TODO: generalize to other sources of data: SCAN / SNOTEL / Henry / etc.
## TODO: add percentiles-by-water-day method

# ugh, terrible name
# percentiles of cumulative precipitation plot
# x: result from CDECquery for now, will need to generalize to other sources
# this.year: current year
# method: exemplar|daily
# ...: further arguments to plot()
PCP_plot <- function(x, this.year=2019, method='exemplar', q.color='RoyalBlue', c.color='firebrick', ...) {
  
  # water year range
  wy.range <- range(x$water_year)
  
  # prepare data for plotting / extract summaries
  xx <- .prepareCumulativePPT(x)
  e <- .exemplarYears(xx)
  
  # convenience objects for plotting 
  exemplar.yrs <- as.numeric(names(e))
  this.year.data <- xx[xx$water_year == this.year, ]
  
  # current year positional elements
  # last real date in series
  mrd <- as.character(max(this.year.data$datetime, na.rm = TRUE))
  # last water date in series
  mwd <- max(this.year.data$water_day, na.rm = TRUE)
  # last cumulative PPT in series
  mcp <- max(this.year.data$cumulative_ppt, na.rm = TRUE)
  
  this.wd.data <- xx$cumulative_ppt[xx$water_day == mwd]
  this.wd.data.q <- quantile(this.wd.data, probs = c(0.05, 0.25, 0.5, 0.75, 0.95), na.rm = TRUE)
  
  # reasonable axis in "real" dates
  date.axis <- data.frame(d=seq.Date(from=as.Date('2000-10-01'), to=as.Date('2001-09-30'), by = '2 weeks'))
  
  # integrate water year / day
  wyd <- waterDayYear(date.axis$d)
  date.axis$wr <- wyd$wy
  date.axis$wd <- wyd$wd
  
  # generic labeling of months and days
  date.axis$lab <- format(date.axis$d, "%d\n%b")
  
  # horizontal grid lines
  y.grid <- pretty(xx$cumulative_ppt, n = 10)
  
  # keep track of water years, label x-axis with this
  xlab.text <- sprintf("Water Years %s - %s", wy.range[1], wy.range[2])
  
  # all data, establish plot area
  plot(cumulative_ppt ~ water_day, data=xx, col=grey(0.9), type='n', axes=FALSE, xlim=c(0, 370), xlab=xlab.text, ... )
  # plot(cumulative_ppt ~ water_day, data=xx, col=grey(0.9), type='n', axes=FALSE, xlim=c(-5, 370), xlab=xlab.text)
  
  # grid
  abline(h=y.grid, v=date.axis$wd, col='lightgray', lty=3)
  
  # exemplar years based on quantiles
  # q05
  lines(cumulative_ppt ~ water_day, data=xx[xx$water_year == exemplar.yrs[1], ], lwd=1, lty=3, col=q.color, type='l')
  # q25
  lines(cumulative_ppt ~ water_day, data=xx[xx$water_year == exemplar.yrs[2], ], lwd=1, lty=2, col=q.color, type='l')
  # q50
  lines(cumulative_ppt ~ water_day, data=xx[xx$water_year == exemplar.yrs[3], ], lwd=2, lty=1, col=q.color, type='l')
  # q75
  lines(cumulative_ppt ~ water_day, data=xx[xx$water_year == exemplar.yrs[4], ], lwd=1, lty=2, col=q.color, type='l')
  # q95
  lines(cumulative_ppt ~ water_day, data=xx[xx$water_year == exemplar.yrs[5], ], lwd=1, lty=3, col=q.color, type='l')
  
  # current year
  lines(cumulative_ppt ~ water_day, data=this.year.data, lwd=2, col=c.color, type='l')
  
  # add axes
  axis(side=1, at = date.axis$wd, labels = date.axis$lab, cex.axis=0.55, las=1)
  axis(side=2, las=1, at = y.grid, cex.axis=0.75)
  
  # annotate exemplar years
  text(x = 365, y=e, labels = as.character(exemplar.yrs), pos=4, cex=0.75, font=3)
  text(x = 365, y=e, labels = as.character(round(e)), pos=3, cex=0.65, font=2)
  
  # add percentiles for current water day via boxplot
  # create data needed by bxp()
  bxp.data <- list(stats=matrix(this.wd.data.q, ncol=1), n=length(this.wd.data), out=NULL, group=1, names="")
  # add to current plot
  bxp(bxp.data, at=5, add=TRUE, show.names=FALSE, outline = FALSE, axes = FALSE, boxwex=10, border=c.color)
  # annotate with customized quantiles
  text(x=5, y=this.wd.data.q, labels = names(this.wd.data.q), cex=0.65, pos=2, col=c.color)
  
  # annotate current year
  points(x=mwd, y=mcp, pch=22, bg=c.color)
  text(x=5, y=mcp, labels = round(mcp, 1), col=c.color, font=2, cex=0.75, pos=4)
  
  # TODO: condition on mwd: not helpful if < ~ 20 ?
  if(mwd > 25) {
    # helper lines
    segments(x0 = 25, y0 = mcp, x1 = mwd, y1 = mcp, col = alpha(c.color, 0.5))
    segments(x0 = mwd, y0 = mcp, x1 = mwd, y1 = 1, col = alpha(c.color, 0.5))
    
    # annotate current (real) date
    text(x=mwd, y=0, labels = mrd, font=2, cex=0.75, col=c.color)  
  }
  
  # basic legend
  legend('top', legend = c('Historic', 'Current'), pt.bg = c(q.color, c.color), pch = 22, bty='n', pt.cex=1.25, cex=0.75, title='Water Day/Year', horiz = TRUE)
  
  # TODO: return information used to make figure
}


## alternative approach: percentiles by water day, over all water years
## NOT monotonic functions

# # TODO: would be nice to know number of years
# # TODO: filtering on number of days in summation?
# # percentiles over all years, by water day
# .PPT_pctiles <- function(i) {
#   res <- quantile(i$cumulative_ppt, probs=c(0.05, 0.25, 0.5, 0.75, 0.95), na.rm = TRUE)
#   return(res)
# }
# 
# ## not quite right, leap years aren't adequately handled     
# xx <- ddply(x, 'water_year', .fun=.cumulativePPT)
# xxx <- ddply(xx, 'water_day', .fun=.PPT_pctiles)  
# 
# zz <- subset(xx, subset=water_year == 2019)
# zzz <- ddply(zz, 'water_day', .fun=.PPT_pctiles)  
# 
# # almost right
# matplot(xxx[1:365, 1], xxx[1:365, -1], type='l', col='RoyalBlue', 
#         lwd=c(1,1,2,1,1), lty=c(3,2,1,2,3), 
#         las=1, xlab='Water Day', ylab='Cumulative PPT (inches)', 
#         main='Sonora Ranger Station (SOR)\n1981--2019')
# 
# matlines(zzz[1:365, 1], zzz[1:365, 4], lwd=2, col='firebrick')

