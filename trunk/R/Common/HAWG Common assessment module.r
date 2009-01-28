######################################################################################################
# HAWG Herring Generic Stock Assessment Script
#
# Version 1.1 28/01/2009 11:52:50
#
# Author: Mark Payne
# DIFRES, Charlottenlund, DK
#
# Generic Stock Assessment Script for use with the FLICA method, producing the standard set of outputs
# employed by the HAWG working group.
#
# Developed with:
#   - R version 2.8.0
#   - FLCore 1.99-111
#   - FLICA, version 1.4-3
#   - FLAssess, version 1.99-102
#   - FLSTF, version 1.99-1
#
# Changes:
# V 1.10 - Added error checking and default options
# V 1.00 - Creation of common assessment module
#
# To be done:
#
# Notes:
#
####################################################################################################

### ======================================================================================================
### Functions
### ======================================================================================================
FnPrint     <-  function(string) {
	cat(string)
	flush.console()
}

### ======================================================================================================
### Set defaults and check that the required objects are properly defined
### ======================================================================================================
if(!exists("n.retro.yrs")) n.retro.yrs  <-  3               #Number of years for which to run the retrospective
if(!exists("filename"))    filename     <-  file.path("..","Output","Assessment results") #Output base filename, including directory
if(!exists("table.fmt.str")) table.fmt.str  <-  "TABLE %i."   #The table number formatting string for the ica.out file
if(!exists("stck")) stop("An FLStock object called 'stck' is missing and needs to be defined for use in the assessment.")
if(!exists("idxs")) stop("An FLIndices object called 'idxs' is missing and needs to be defined for use in the assessment.")
if(!exists("ctrl")) stop("An FLICA.control object called 'ctrl' is missing and needs to be defined for use in the assessment.")

### ======================================================================================================
### Perform the assessment
### ======================================================================================================
FnPrint("PERFORMING ASSESSMENT...\n")
#Now perform the asssessment
ica.obj   <-  FLICA(stck,idxs,ctrl)
 
#Update the stock object with the results of the assessment
stck <-  stck + ica.obj
 
### ======================================================================================================
### Summary Plots
### ======================================================================================================
FnPrint("GENERATING SUMMARY PLOTS ...\n")

#Make stock summary plots (ie SSB, Fbar, recs)
summary.data <- FLQuants(SSB=ssb(stck),"Mean F"=fbar(stck),Recruits=rec(stck))
summary.plot <-xyplot(data~year|qname,data=as.data.frame(summary.data),
                  prepanel=function(...) {list(ylim=range(pretty(c(0,list(...)$y))))},
                  main=list("Stock Summary Plot",cex=0.9),
                  col="black",
                  ylab="",
                  layout=c(1,3),
                  type="l",
                  panel=function(...) {
                    panel.grid(h=-1,v=-1)
                    panel.xyplot(...)
                  },
                  scales=list(alternating=1,abbreviate=TRUE,y=list(relation="free",rot=0)))
print(summary.plot)

#Now generate the diagnostic plots
diagnostics(ica.obj) 
 
#Bubble plots of the index residuals
bubble.plot <- bubbles(factor(as.character(age))~year|qname,data=ica.obj@index.res,
                  layout=c(1,length(ica.obj@index.res)),
                  main=list("Index Residuals Bubble Plot",cex=0.9),
                  prepanel=function(...){
                            arg <- list(...)
                            ylims  <- levels(arg$y)
                            yats   <- unique(as.numeric(arg$y))
                            list(ylim=ylims,yat=yats)
                  },
                  ylab="age",
                  as.table=TRUE,
                  scale=list(alternating=1,rot=0,y=list(relation="free")))
print(bubble.plot)

#Shade plot of index residuals
shade.plot <- levelplot(data~year*factor(as.character(age))|qname,data=as.data.frame(ica.obj@index.res),
                  main=list("Index Residuals Shade Plot",cex=0.9),
                  layout=c(1,length(ica.obj@index.res)),
                  at=seq(-2,2,length.out=101),
                  col.regions=colorRampPalette(c("Green","White","Blue"))(100),
                  prepanel=function(...){
                            arg <- list(...)
                            ylims  <- levels(arg$y)
                            yats   <- unique(as.numeric(arg$y[arg$subscripts]))
                            list(ylim=ylims,yat=yats)
                  },
                  pretty=TRUE,
                  ylab="age",
                  as.table=TRUE,
                  scale=list(alternating=1,rot=0,y=list(relation="free")))
print(shade.plot)
                                                   
#Generate an "otolith" plot showing the uncertainty distribution
plot.otolith(stck,ica.obj)
 
### ======================================================================================================
### Retrospective analysises
### ======================================================================================================
FnPrint("GENERATING RETROSPECTIVE ANALYSES...\n")
#Generate a retrospective analysis
retro.stck <- retro(stck,idxs,ctrl,retro=n.retro.yrs)
retro.ssbs  <- do.call(FLQuants,lapply(retro.stck,ssb))
retro.fbar  <- do.call(FLQuants,lapply(retro.stck,fbar))
retro.recs  <- do.call(FLQuants,lapply(retro.stck,rec))
retro.dat   <- rbind(cbind(value="SSB",as.data.frame(retro.ssbs)),
                      cbind(value="Recruits",as.data.frame(retro.recs)),
                      cbind(value="Mean F",as.data.frame(retro.fbar)))
retro.plot<-xyplot(data~year|value,data=retro.dat,
                main=list("Retrospective Summary Plot",cex=0.9),
                groups=qname,
                prepanel=function(...) {list(ylim=range(pretty(c(0,list(...)$y))))},
                layout=c(1,3),
                ylab="",
                type="l",
                as.table=TRUE,
                lwd=c(rep(1,length(retro.stck)-1),3),
                col="black",
                panel=function(...) {
                    panel.grid(h=-1,v=-1)
                    panel.xyplot(...)
                },
                scales=list(alternating=1,y=list(relation="free",rot=0)))
plot(retro.plot)
 
#Retrospective cohort plot
flc.dat      <- as.data.frame(lapply(retro.stck,function(x) FLCohort(x@stock.n)))
cohort.retro <- xyplot(data~age|factor(cohort),data=flc.dat,
                    main=list("Cohort Retrospective plot",cex=0.9),
                    as.table=TRUE,
                    groups=cname,
                    type="l",
                    ylim=10^range(pretty(log10(flc.dat$data))),
                    ylab="Stock numbers",
                    lwd=c(rep(1,length(retro.stck)-1),1),
                    col="black",
                    scales=list(alternating=1,y=list(log=TRUE,rot=0,at=10^seq(min(pretty(log10(flc.dat$data))),max(pretty(log10(flc.dat$data))),by=1))))
print(cohort.retro)

#Retrospective plot by ages
age.retro <- xyplot(data~year|factor(paste("Age",age)),data=lapply(retro.stck,stock.n),
                    main=list("Age-group Retrospective plot",cex=0.9),
                    as.table=TRUE,
                    groups=qname,
                    prepanel=function(...) {list(ylim=range(pretty(c(0,list(...)$y))))},
                    ylab="Stock numbers",
                    type="l",
                    lwd=c(rep(1,length(retro.stck)-1),3),
                    col="black",
                    scales=list(alternating=1,y=list(relation="free",rot=0)))
print(age.retro)


### ======================================================================================================
### Documenting assessment
### ======================================================================================================
FnPrint("GENERATING DOCUMENTATION...\n")
#Documentation the run with alternative table numbering
options("width"=80)
ica.out.file <- ica.out(stck,idxs,ica.obj,format=table.fmt.str)
write(ica.out.file,file=paste(filename,"ica.out",sep="."))
 
#And finally, write the results out in the lowestoft VPA format for further analysis eg MFDP
writeFLStock(stck,output.file=filename)