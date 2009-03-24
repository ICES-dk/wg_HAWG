################################################################################
# Code to do the multifleet short term forecast for North Sea Herring
#
# By: Niels Hintzen
# Wageningen IMARES
# 22 March 2009
#
################################################################################

#Read in data
try(setwd("./stf/"))

stk     <- NSH
stk.ica <- NSH.ica
#===============================================================================
# Setup control file
#===============================================================================

DtY   <- ac(2008) #Data year
ImY   <- ac(2009) #Intermediate year
FcY   <- ac(2010) #Forecast year
CtY   <- ac(2011) #Continuation year
source("./data/readStfData.r")

TACS  <- list("A"=c(194233,NA,NA),"B"=c(7310,NA,NA),"C"=c(6538,5100,5100),"D"=c(2701,2000,2000))
RECS  <- list("ImY"=NSH.ica@param["Recruitment prediction","Value"],"FcY"=exp(mean(log(rec(NSH)[,ac((range(NSH)["maxyear"]-6):(range(NSH)["maxyear"]))]))),"CtY"=exp(mean(log(rec(NSH)[,ac((range(NSH)["maxyear"]-6):(range(NSH)["maxyear"]))]))))
FS    <- list("A"=FA,"B"=FB,"C"=FC,"D"=FD)
WS    <- list("A"=WA,"B"=WB,"C"=WC,"D"=WD)   

yrs1  <- list("m","m.spwn","harvest.spwn","stock.wt","stock.n")
yrs3  <- list("mat")

dsc   <- "North Sea Herring"
nam   <- "NSH"
dms   <- dimnames(stk@m)
dms$year <- c(rev(rev(dms$year)[1:3]),ImY,FcY,CtY)
dms$unit <- c("A","B","C","D")

f01   <- ac(0:1)
f26   <- ac(2:6)

stf.options <- c("mp","-15%","+15%","nf","bpa","tacro") #mp=according to management plan, +/-% = TAC change, nf=no fishing, bpa=reach BPA in CtY,tacro=same catch as last year
mp.options  <- c("i") #i=increase in B fleet is allowed, fro=B fleet takes fbar as year before
#===============================================================================
# Setup stock file
#===============================================================================

stf         <- FLStock(name=nam,desc=dsc,m=FLQuant(NA,dimnames=dms))
units(stf)  <- units(stk)
# Fill slots that are the same for all fleets 
for(i in c(unlist(yrs1),unlist(yrs3))){
  if(i %in% unlist(yrs1)) slot(stf,i)[] <- slot(stk,i)[,DtY]
  if(i %in% unlist(yrs3)) slot(stf,i)[] <- apply(slot(stk,i)[,ac((an(DtY)-2):an(DtY))],1,mean,na.rm=T)
}
# Fill slots that are unique for the fleets
for(i in dms$unit){
  stf@harvest[,,i]    <- FS[[i]]
  stf@catch.wt[,,i]   <- WS[[i]]
}

#===============================================================================
# Intermediate year 
#===============================================================================

stf@stock.n[,ImY]     <- stk.ica@survivors
for(i in dms$unit){
  stf@harvest[,ImY,i] <- fleet.harvest(stf,i,ImY,TACS[[i]][1])
  stf@catch  [,ImY,i] <- sum(stf@stock.n[,ImY,i]*(1-exp(-stf@harvest[,ImY,i]-stf@m[,ImY,i]))*stf@catch.wt[,ImY,i]*(stf@harvest[,ImY,i]/(stf@harvest[,ImY,i]+stf@m[,ImY,i])))
}

#Intermediate year stf option table
stf.table <- matrix(NA,nrow=c(length(stf.options)+1),ncol=12,dimnames=list("options"=c("intermediate year",stf.options),"values"=c("Fbar 2-6 A","Fbar 0-1 B","Fbar 0-1 C","Fbar 0-1 D","Fbar 2-6","Fbar 0-1","Catch A","Catch B","Catch C","Catch D","SSB","SSB")))
stf.table[1,1:11] <- c(round(c(mean(stf@harvest[f26,ImY,1]),apply(stf@harvest[f01,ImY,2:4],3,mean),mean(apply(stf@harvest[f26,ImY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,ImY],1,sum,na.rm=T))),3),
                       round(c(colSums((1-exp(-stf@harvest[,ImY]-stf@m[,ImY]))*stf@stock.n[,ImY]*stf@catch.wt[,ImY]*(stf@harvest[,ImY]/(stf@harvest[,ImY]+stf@m[,ImY])))),0),
                       round(sum(stf@stock.n[,ImY,1]*stf@stock.wt[,ImY,1]*exp(-apply(stf@harvest[,ImY],1,sum)*stf@harvest.spwn[,ImY,1]-stf@m[,ImY,1]*stf@m.spwn[,ImY,1])*stf@mat[,ImY,1]),0))

#===============================================================================
# Forecast year
#===============================================================================

stf@stock.n[,FcY] <- c(RECS$FcY,(stf@stock.n[,ImY,1]*exp(-apply(stf@harvest[,ImY],1,sum)-stf@m[,ImY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,ImY,1]*exp(-apply(stf@harvest[,ImY],1,sum)-stf@m[,ImY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))

stf@harvest[,FcY] <- stf@harvest[,ImY]
for(i in dms$unit){
  if(is.na(TACS[[i]][2])==F) stf@harvest[,FcY,i] <- fleet.harvest(stf,i,FcY,TACS[[i]][2])
}    

###--- Management options ---###

### Following the management plan ###
if("mp" %in% stf.options){ 
  res                           <- optim(par=c(1,1),fn=find.FAB,stk=window(stf,an(FcY),an(FcY)),f01=f01,f26=f26,mp.options=mp.options)$par
  stf@harvest[,FcY,c("A")]      <- stf@harvest[,FcY,c("A")] * res[1]
  stf@harvest[,FcY,c("B")]      <- stf@harvest[,FcY,c("B")] * res[2]
                  
  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                       *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["mp",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                         round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                         round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                         ssb.CtY),0))
                   
}
### No fishing ###
if("nf" %in% stf.options){
  stf@harvest[,FcY] <- 0
  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                     *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["nf",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                         round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                         round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                         ssb.CtY),0))
}

### 15% reduction in TAC for the A-fleet ###
if("-15%" %in% stf.options){

  #reset harvest for all fleets
  stf@harvest[,FcY] <- stf@harvest[,ImY]
  for(i in dms$unit){
    if(is.na(TACS[[i]][2])==F) stf@harvest[,FcY,i] <- fleet.harvest(stf,i,FcY,TACS[[i]][2])
  }
   
  TAC.A <- TACS[["A"]][1]*0.85
  stf@harvest[,FcY,"A"] <- fleet.harvest(stf,"A",FcY,TAC.A)
  stf@harvest[,FcY,"B"] <- fleet.harvest(stf,"B",FcY,TACS[["B"]][1])
    
  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                     *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["-15%",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                           round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                           round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                           ssb.CtY),0))
}

### 15% increase in TAC for the A-fleet ###
if("+15%" %in% stf.options){
  #reset harvest for all fleets
  stf@harvest[,FcY] <- stf@harvest[,ImY]
  for(i in dms$unit){
    if(is.na(TACS[[i]][2])==F) stf@harvest[,FcY,i] <- fleet.harvest(stf,i,FcY,TACS[[i]][2])
  }
  
  TAC.A <- TACS[["A"]][1]*1.15
  stf@harvest[,FcY,"A"] <- fleet.harvest(stf,"A",FcY,TAC.A)
  stf@harvest[,FcY,"B"] <- fleet.harvest(stf,"B",FcY,TACS[["B"]][1])
    
  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                     *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["+15%",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                           round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                           round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                           ssb.CtY),0))
}

### Same catch as last year ###
if("tacro" %in% stf.options){
   #reset harvest for all fleets
  stf@harvest[,FcY] <- stf@harvest[,ImY]
  
  for(i in dms$unit) stf@harvest[,FcY,i] <- fleet.harvest(stf,i,FcY,TACS[[i]][1])

  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                     *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["tacro",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                            round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                            round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                            ssb.CtY),0))
}

### Bpa in continuation year ###
if("bpa" %in% stf.options){
   #reset harvest for all fleets
  stf@harvest[,FcY] <- stf@harvest[,ImY]
  
  res <- optimize(find.Bpa,c(0,2),stk=window(stf,an(FcY),an(CtY)),rec=RECS$FcY,bpa=1.3e6)$minimum
  stf@harvest[,FcY] <- stf@harvest[,FcY] * res
  ssb.CtY           <- sum(c(RECS$CtY,(stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,ImY,1]))[ac(range(stf)["min"]:(range(stf)["max"]-2)),],sum((stf@stock.n[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)-stf@m[,FcY,1]))[ac((range(stf)["max"]-1):range(stf)["max"]),]))
                     *stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  stf.table["bpa",]  <- c(round(c(mean(stf@harvest[f26,FcY,1]),apply(stf@harvest[f01,FcY,2:4],3,mean),mean(apply(stf@harvest[f26,FcY],1,sum,na.rm=T)),mean(apply(stf@harvest[f01,FcY],1,sum,na.rm=T))),3),
                          round(c(colSums((1-exp(-stf@harvest[,FcY]-stf@m[,FcY]))*stf@stock.n[,FcY]*stf@catch.wt[,FcY]*(stf@harvest[,FcY]/(stf@harvest[,FcY]+stf@m[,FcY])))),0),
                          round(c(sum(stf@stock.n[,FcY,1]*stf@stock.wt[,FcY,1]*exp(-apply(stf@harvest[,FcY],1,sum)*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1])*stf@mat[,FcY,1]),
                          ssb.CtY),0))
}
