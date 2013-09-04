#' Run the derfinder analysis on a chromosome
#'
#' This is a major wrapper for running several key functions from this package. It is meant to be used after \link{loadCoverage} has been used for a specific chromosome. The steps run include \link{makeModels}, \link{preprocessCoverage}, \link{calculateStats}, \link{calculatePvalues} and \link[bumphunter]{annotateNearest}. 
#' 
#' @param chrnum Used for naming the output files when \code{writeOutput=TRUE} and for \link[bumphunter]{annotateNearest}. Use '21' instead of 'chr21'.
#' @param coverageInfo The output from \link{loadCoverage}.
#' @param testvars This argument is passed to \link{makeModels}.
#' @param adjustvars This argument is passed to \link{makeModels}.
#' @param nonzero This argument is passed to \link{makeModels}.
#' @param center This argument is passed to \link{makeModels}.
#' @param testIntercept This argument is passed to \link{makeModels}.
#' @param cutoffPre This argument is passed to \link{preprocessCoverage} (\code{cutoff}).
#' @param colsubset This argument is passed to \link{preprocessCoverage}.
#' @param scalefac This argument is passed to \link{preprocessCoverage}.
#' @param chunksize This argument is passed to \link{preprocessCoverage}.
#' @param cutoffFstat This is used to determine the cutoff argument of \link{calculatePvalues} and it's behaviour is determined by \code{cutoffType}.
#' @param cutoffType If set to \code{empirical}, the \code{cutoffFstat} (example: 0.99) quantile is used via \link{quantile}. If set to \code{theoretical}, the theoretical \code{cutoffFstats} (example: 1e-08) is calculated via \link{qf}. If set to \code{manual}, \code{cutoffFstats} is passed to \link{calculatePvalues} without any other calculation.
#' @param nPermute This argument is passed to \link{calculatePvalues}.
#' @param seeds This argument is passed to \link{calculatePvalues}.
#' @param maxGap This argument is passed to \link{calculatePvalues}.
#' @param groupInfo A factor specifying the group membership of each sample that can later be used with \code{plotRegion}.
#' @param subject This argument is passed to \link[bumphunter]{annotateNearest}. Note that only \code{hg19} works right now.
#' @param mc.cores This argument is passed to \link{preprocessCoverage} (useful if \code{chunksize=NULL}), \link{calculateStats} and \link{calculatePvalues}.
#' @param writeOutput If \code{TRUE}, output Rdata files are created at each step inside a directory with the chromosome name (example: 'chr21' if \code{chrnum="21"}). One Rdata files is created for each component described in the return section.
#' @param returnOutput If \code{TRUE}, it returns a list with the results from each step. Otherwise, it returns \code{NULL}.
#' @param verbose If \code{TRUE} basic status updates will be printed along the way.
#'
#' @return If \code{returnOutput=TRUE}, a list with seven components:
#' \describe{
#' \item{timeinfo }{ The wallclock timing information for each step.}
#' \item{optionsStats }{ The main options used when running this function.}
#' \item{models }{ The models used in the analysis.}
#' \item{coveragePrep }{ The output from \link{preprocessCoverage}.}
#' \item{fstats}{ The output from \link{calculateStats}.}
#' \item{regions}{ The output from \link{calculatePvalues}.}
#' \item{annotation}{ The output from \link[bumphunter]{annotateNearest}.}
#' }
#' These are the same components that are written to Rdata files if \code{writeOutput=TRUE}.
#'
#' @author Leonardo Collado-Torres
#' @seealso \link{makeModels}, \link{preprocessCoverage}, \link{calculateStats}, \link{calculatePvalues}, \link[bumphunter]{annotateNearest}
#' @export
#' @importMethodsFrom IRanges as.numeric
#'
#' @examples
#' group <- genomeInfo$pop
#' adjustvars <- data.frame(genomeInfo$gender)
#' results <- analyzeChr(chrnum="21", coverageInfo=genomeData, testvars=group, adjustvars=adjustvars, cutoffFstat=1, cutoffType="manual", mc.cores=1, writeOutput=FALSE, returnOutput=TRUE)
#' names(results)

analyzeChr <- function(chrnum, coverageInfo, testvars, adjustvars=NULL, nonzero=TRUE, center=TRUE, testIntercept=FALSE, cutoffPre = 5, colsubset=NULL, scalefac=32, chunksize=NULL, cutoffFstat=1e-08, cutoffType="theoretical", nPermute=1, seeds=as.integer(gsub("-", "", Sys.Date())) + seq_len(nPermute), maxGap=300L, groupInfo=testvars, subject="hg19", mc.cores=getOption("mc.cores", 2L), writeOutput=TRUE, returnOutput=FALSE, verbose=TRUE) {
	stopifnot(length(intersect(cutoffType, c("empirical", "theoretical", "manual"))) == 1)
	chr <- paste0("chr", chrnum)
	## Begin timing
	timeinfo <- NULL
	## Init
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save parameters used for running calculateStats
	optionsStats <- list(testvars=testvars, adjustvars=adjustvars, nonzero=nonzero, cutoffPre=cutoffPre, colsubset=colsubset, scalefac=scalefac, chunksize=chunksize, cutoffFstat=cutoffFstat, cutoffType=cutoffType, nPermute=nPermute, seeds=seeds, maxGap=maxGap, groupInfo=groupInfo)

	## Setup
	timeinfo <- c(timeinfo, list(Sys.time()))

	if(writeOutput) {
		dir.create(chr, recursive=TRUE)
		save(optionsStats, file=file.path(chr, "optionsStats.Rdata"))
	}	
	## saveStatsOpts
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Build the models
	if(verbose) message(paste(Sys.time(), "analyzeChr: Building mod and mod0"))
	models <- makeModels(coverageInfo=coverageInfo, testvars=testvars, adjustvars=adjustvars, nonzero=nonzero, verbose=verbose, center=center, testIntercept=testIntercept)

	## buildModels
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save the model matrices
	if(writeOutput) {
		save(models, file=file.path(chr, "models.Rdata"))
	}
	## saveModels
	timeinfo <- c(timeinfo, list(Sys.time()))

	## pre-process the coverage data with automatic chunks depending on the number of cores
	if(verbose) message(paste(Sys.time(), "analyzeChr: Pre-processing the coverage data"))
	prep <- preprocessCoverage(coverageInfo=coverageInfo, cutoff=cutoffPre, colsubset=colsubset, scalefac=scalefac, chunksize=chunksize, mc.cores=mc.cores, verbose=verbose)

	## prepData
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save the prepared data
	if(writeOutput) {
		save(prep, file=file.path(chr, "coveragePrep.Rdata"))
	}
	## savePrep
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Run calculateStats
	if(verbose) message(paste(Sys.time(), "analyzeChr: Calculating statistics"))
	fstats <- calculateStats(coveragePrep=prep, models=models, mc.cores=mc.cores, verbose=verbose)

	## calculateStats
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save the output from calculateStats
	if(writeOutput) {
		save(fstats, file=file.path(chr, "fstats.Rdata"))
	}

	## saveStats
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Calculate p-values and find regions
	if(verbose) message(paste(Sys.time(), "analyzeChr: Calculating pvalues"))
	
	## Choose the cutoff
	if(cutoffType == "empirical") {
		cutoff <- quantile(as.numeric(fstats), 0.99)
	} else if (cutoffType == "theoretical") {
		n <- dim(models$mod)[1]
		df1 <- dim(models$mod)[2]
		df0 <- dim(models$mod0)[2]
		cutoff <- qf(cutoffFstat, df1-df0, n-df1, lower.tail=FALSE)
	} else if (cutoffType == "manual") {
		cutoff <- cutoffFstat
	}
	
	if(verbose) message(paste(Sys.time(), "analyzeChr: Using the following", cutoffType, "cutoff for the F-statistics", cutoff))
	
	regions <- calculatePvalues(coveragePrep=prep, models=models, fstats=fstats, nPermute=nPermute, seeds=seeds, chr=chr, maxGap=maxGap, cutoff=cutoff, mc.cores=mc.cores, verbose=verbose)

	## calculatePValues
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save the output from calculatePvalues
	if(writeOutput) {
		save(regions, file=file.path(chr, "regions.Rdata"))
	}

	## saveRegs
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Annotate
	if(verbose) message(paste(Sys.time(), "analyzeChr: Annotating regions"))
	library("bumphunter")
	annotation <- annotateNearest(regions$regions, subject)

	## Annotate
	timeinfo <- c(timeinfo, list(Sys.time()))

	if(writeOutput) {
		save(annotation, file=file.path(chr, "annotation.Rdata"))
	}

	## saveAnnotation
	timeinfo <- c(timeinfo, list(Sys.time()))

	## Save timing information
	timeinfo <- do.call(c, timeinfo)
	names(timeinfo) <- c("init", "setup", "saveStatsOpts", "buildModels", "saveModels", "prepData", "savePrep", "calculateStats", "saveStats", "calculatePvalues", "saveRegs", "annotate", "saveAnno")
	if(writeOutput) {
		save(timeinfo, file=file.path(chr, "timeinfo.Rdata"))
	}

	if(returnOutput) {
		result <- list(timeinfo=timeinfo, optionsStats=optionsStats, models=models, coveragePrep=prep, fstats=fstats, regions=regions, annotation=annotation)
	} else {
		result <- NULL
	}
	
	## Done
	return(invisible(result))
}