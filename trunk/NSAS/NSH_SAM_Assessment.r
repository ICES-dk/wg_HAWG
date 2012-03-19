################################################################################
# NSH_SAM Assessment
#
# $Rev: 697 $
# $Date: 2012-02-10 09:52:28 +0100 (vr, 10 feb 2012) $
#
# Author: HAWG model devlopment group
#
# Performs the "Final" assessment for NSAS assessment 
#
# Developed with:
#   - R version 2.13.0
#   - FLCore 2.4
#
# To be done:
#
# Notes: Have fun running this assessment!
#
################################################################################
rm(list=ls()); graphics.off(); start.time <- proc.time()[3]
options(stringsAsFactors=FALSE)
log.msg     <-  function(string) {cat(string);}
log.msg("\nNSH Final Assessment\n=====================\n")
path <- "~/HAWG/trunk/NSAS/"
path <- "D:/Repository/HAWG/HAWGrepository/NSAS/"
try(setwd(path))

### ======================================================================================================
### Define parameters for use in the assessment code here
### ======================================================================================================
output.dir          <-  file.path(".","results")                #Output directory
output.base         <-  file.path(output.dir,"NSH Assessment")  #Output base filename, including directory. Other output filenames are built by appending onto this one
n.retro.years       <-  5                                       #Number of years for which to run the retrospective


### ============================================================================
### Setup assessment
### ============================================================================
#Import externals
library(FLSAM); library(FLEDA)
source(file.path("setupAssessmentObjects.r"))
source(file.path("setupControlObject.r"))
source(file.path("..","_Common","HAWG_Common_module.r"))

### ============================================================================
### Run the assessment
### ============================================================================

  #Perform assessment
  NSH.sam <- FLSAM(NSH,NSH.tun,NSH.ctrl)
  name(NSH.sam) <- "North Sea Herring"

  #Update stock object
  NSH     <- NSH + NSH.sam

  # Save results
  save(NSH,NSH.tun,NSH.ctrl,NSH.sam,file=file.path(output.dir,paste(name(NSH),".RData",sep="")))

### ============================================================================
### Plots
### ============================================================================
#Setup plots
pdf(file.path(output.dir,paste(name(NSH.sam),".pdf",sep="")))
png(file.path(output.dir,"figures - %02d.png"),units = "px", height=800,width=672, bg = "white")
  ### ============================================================================
  ### Input data
  ### ============================================================================

  #-Read in the TACs
  TACs          <- read.csv(file.path(".","data","historic data","TAC-historic.csv"))
  TAC.plot.dat  <- data.frame(year=rep(TACs$year,each=2)+c(-0.5,0.5),TAC=rep(rowSums(TACs[,c("Agreed_A","Bycatch_B")],na.rm=T),each=2))
  catch         <- as.data.frame(NSH@catch[,ac(TACs$year)]/1e3)
  plot(0,0,pch=NA,xlab="Year",ylab="Catch",xlim=range(c(catch$year,TAC.plot.dat$year)),ylim=range(c(0,TAC.plot.dat$TAC,catch$data)),cex.lab=1.2,cex.axis=1.1,font=2)
  rect(catch$year-0.5,0,catch$year+0.5,catch$data,col="grey")
  lines(TAC.plot.dat,lwd=3)
  legend("topright",legend=c("Catch","TAC"),lwd=c(1,5),lty=c(NA,1),pch=c(22,NA),col="black",pt.bg="grey",pt.cex=c(2),box.lty=0)
  box()
  title(main=paste(NSH@name,"Catch and TAC"))

  # Plot the overlay of tuning series
  print(overlayTimeseries(lapply(NSH.tun,index),nyrs=10,ages=0:1))
  print(overlayTimeseries(FLQuants(IBTS0=NSH.tun[["IBTS0"]]@index,IBTSQ1=NSH.tun[["IBTS-Q1"]]@index),nyrs=20,ages=0:1))
  
  # Plot the overlay by year and age
  print(surveyTimeseries(NSH.tun))

  #Plot survey index versus each other
    tmp.tun <- NSH.tun; dmns <- dimnames(tmp.tun[["IBTS0"]]@index); tmp.tun[["IBTS0"]] <- FLIndex(FLQuant(NA,dimnames=list(age=1,year=ac(an(dmns$year)+1),unit=dmns$unit,season=dmns$season,area=dmns$area,iter=dmns$iter)))
    tmp.tun[["IBTS0"]]@index <- FLQuant(NSH.tun[["IBTS0"]]@index@.Data,dimnames=list(age=1,year=ac(an(dmns$year)+1),unit=dmns$unit,season=dmns$season,area=dmns$area,iter=dmns$iter))
  #plot(tmp.tun,type="pairwise")
  plot(NSH.tun[["HERAS"]],type="internal")

  # Plot the proportion of catch and weight in numbers and weight to see if the catch is representative for the stock build-up
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@catch.n)),groups="age",main="Proportion of Catch numbers at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@stock.wt)),groups="age",main="Proportion of Stock weight at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@catch.wt)),groups="age",main="Proportion of Catch weight at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))

  # Plot the proportion of catch in numbers in the indices to see if the indices are having specific yearclass trends
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH.tun[["HERAS"]]@index)),groups="age",main="Proportion of Acoustic index at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))

  # Plot the proportion of natural mortality
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@m)),groups="age",main="Proportion of natural at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))

  # Plot the time series of weight in the stock and catch in the stock
  timeseries(window(NSH,1975,range(NSH)["maxyear"]),slot="stock.wt")
  timeseries(window(NSH,1975,range(NSH)["maxyear"]),slot="catch.wt")
  timeseries(window(NSH,2000,range(NSH)["maxyear"]),slot="harvest")
  timeseries(window(NSH,1990,range(NSH)["maxyear"]),slot="mat")
  timeseries(window(NSH,1990,range(NSH)["maxyear"]),slot="m",ylim=c(0,1.2))

  # Plot the time series of the surveys
  timeseries(NSH.tun[["SCAI"]],slot="index")
  timeseries(NSH.tun[["IBTS-Q1"]],slot="index")
  timeseries(NSH.tun[["IBTS0"]],slot="index")

  #Time series of west by cohort
  west.by.cohort      <- as.data.frame(FLCohort(window(NSH@stock.wt,1980,range(NSH)["maxyear"])))
  west.by.cohort      <- subset(west.by.cohort,!is.na(west.by.cohort$data))
  west.by.cohort$year <- west.by.cohort$age + west.by.cohort$cohort
  west.cohort.plot    <- xyplot(data~year,data=west.by.cohort,
                                groups=cohort,
                                auto.key=list(space="right",points=FALSE,lines=TRUE,type="b"),
                                type="b",
                                xlab="Year",ylab="Weight in the stock (kg)",
                                main=paste(NSH@name,"Weight in the stock by cohort"),
                                par.settings=list(superpose.symbol=list(pch=as.character(unique(west.by.cohort$cohort)%%10),cex=1.25)),
                                panel=function(...) {
                                  panel.grid(h=-1,v=-1)
                                  panel.xyplot(...)
                                })
  print(west.cohort.plot)

  ### ============================================================================
  ### Model fit
  ### ============================================================================

  #Survey fits
  residual.diagnostics(NSH.sam)

  # Plot the harvest pattern at age as a proportion over time & the stock.n as proportion over time
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@harvest)),groups="age",main="Proportion of harvest pressure at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))
  print(stacked.area.plot(data~year| unit, as.data.frame(pay(NSH@stock.n)),groups="age",main="Proportion of Stock numbers at age",ylim=c(-0.01,1.01),xlab="years",col=gray(9:0/9)))

  #Plot result
  print(plot(NSH.sam))

  #Plot uncertainties as a function of time
  CV.yrs <- ssb(NSH.sam)$year
  CV.dat <- cbind(SSB=ssb(NSH.sam)$CV,
                     Fbar=fbar(NSH.sam)$CV,Rec=rec(NSH.sam)$CV)
  matplot(CV.yrs,CV.dat,type="l",ylim=range(pretty(c(0,CV.dat))),yaxs="i",
      xlab="Year",ylab="CV of estimate",main="Uncertainties of key parameters")
  legend("topleft",legend=colnames(CV.dat),lty=1:5,col=1:6,bty="n")

  #Plot catchabilities values
  catch <- catchabilities(NSH.sam)
  print(xyplot(value+ubnd+lbnd ~ age | fleet,catch,
            scale=list(alternating=FALSE,y=list(relation="free")),as.table=TRUE,
            type="l",lwd=c(2,1,1),col=c("black","grey","grey"),
            subset=fleet %in% c("HERAS"),
            main="Survey catchability parameters",ylab="Catchability",xlab="Age"))

  #Plot obs_variance (weightings)
  obv <- obs.var(NSH.sam)
  obv$str <- paste(obv$fleet,ifelse(is.na(obv$age),"",obv$age))
  obv <- obv[order(obv$value),]
  bp <- barplot(obv$value,ylab="Observation Variance",
         main="Observation variances by data source",col=factor(obv$fleet))
  axis(1,at=bp,labels=obv$str,las=3,lty=0,mgp=c(0,0,0))
  legend("topleft",levels(obv$fleet),pch=15,col=1:nlevels(obv$fleet),pt.cex=1.5)

  plot(obv$value,obv$CV,xlab="Observation variance",ylab="CV of estimate",log="x",
    pch=16,col=obv$fleet,main="Observation variance vs uncertainty")
  text(obv$value,obv$CV,obv$str,pos=4,cex=0.75,xpd=NA)

  #Plot fishery selectivity pattern over time
  sel.pat <- merge(f(NSH.sam),fbar(NSH.sam),
               by="year",suffixes=c(".f",".fbar"))
  sel.pat$sel <- sel.pat$value.f/sel.pat$value.fbar
  sel.pat$age <- as.numeric(as.character(sel.pat$age))
  print(xyplot(sel ~ age|sprintf("%i's",floor((year+2)/5)*5),sel.pat,
           groups=year,type="l",as.table=TRUE,
           scale=list(alternating=FALSE),
           main="Selectivity of the Fishery by Pentad",xlab="Age",ylab="F/Fbar"))

  #Plot correlation matrix
  cor.plot(NSH.sam)

  #Plot otholith
  #plot.otolith(NSH.sam,n=10000) #Warning, this takes very long!
    
  ### ============================================================================
  ### Management
  ### ============================================================================

  #A plot on the agreed management plan with the estimated Fbar in 2010
  plot(x=c(0,0.8,1.5,2.5),y=c(0.1,0.1,0.25,0.25),type="l",ylim=c(0,0.4),lwd=2,xlab="SSB in million tonnes",ylab="Fbar",cex.lab=1.3,main="Management plan North Sea Herring")
  abline(v=0.8,col="red",lwd=2,lty=2)
  abline(v=1.3,col="blue",lwd=2,lty=2)
  abline(v=1.5,col="darkgreen",lwd=2,lty=2)
  text(0.8,0,labels=expression(B[lim]),col="red",cex=1.3,pos=2)
  text(1.3,0,labels=expression(B[pa]),col="blue",cex=1.3,pos=2)
  text(1.5,0,labels=expression(B[trigger]),col="darkgreen",cex=1.3,pos=4)

  points(y=fbar(NSH[,ac(2002:2011)]), x=(ssb(NSH[,ac(2002:2011)])/1e6),pch=19)
  lines(y=fbar(NSH[,ac(2002:2011)]),  x=(ssb(NSH[,ac(2002:2011)])/1e6))
  text(y=fbar(NSH[,ac(2002:2011)]),   x=(ssb(NSH[,ac(2002:2011)])/1e6),labels=ac(2002:2011),pos=3,cex=0.7)


### ======================================================================================================
### Document Assessment
### ======================================================================================================
log.msg("GENERATING DOCUMENTATION...\n")
#Document the run with alternative table numbering and a reduced width
old.opt           <- options("width","scipen")
options("width"=old.opt$width,"scipen"=old.opt$scipen)

#And finally, write the results out in the lowestoft VPA format for further analysis eg MFDP
#writeFLStock(NSH,output.file=output.base)

#And for incorporation into the standard graphs
#writeFLStock(NSH,file.path(output.dir,"hawg_her-47d3.sum"),type="ICAsum")
#The YPR curves based on the same values as the projection - therefore use WBSS.proj
#writeStandardOutput(NSH,NSH.sr,NSH.retro,recImY=NSH.ica@survivors[1,1],nyrs.=3,output.base,Blim=0.8e6,Bpa=1.3e6,Flim=NULL,Fpa=0.25,Bmsy=NULL,Fmsy=NULL)

### ============================================================================
### Finish
### ============================================================================
dev.off()
log.msg(paste("COMPLETE IN",sprintf("%0.1f",round(proc.time()[3]-start.time,1)),"s.\n\n"))

