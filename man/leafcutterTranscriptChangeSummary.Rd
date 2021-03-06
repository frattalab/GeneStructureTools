% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/quickAnalysis.R
\name{leafcutterTranscriptChangeSummary}
\alias{leafcutterTranscriptChangeSummary}
\title{Compare open reading frames for whippet differentially spliced events}
\usage{
leafcutterTranscriptChangeSummary(significantEvents,
  combineGeneEvents = FALSE, exons, BSgenome, NMD = FALSE,
  showProgressBar = TRUE, junctions = NULL, exportGTF = NULL,
  uniprotData = NULL, uniprotSeqFeatures = NULL)
}
\arguments{
\item{significantEvents}{data.frame containing information from the
per_intron_results.tab file output from leafcutter.}

\item{combineGeneEvents}{combine clusters occuring in the same gene?
Currently not reccomended.}

\item{exons}{GRanges gtf annotation of exons}

\item{BSgenome}{BSGenome object containing the genome for the species analysed}

\item{NMD}{Use NMD predictions? (Note: notNMD must be installed to use this feature)}

\item{showProgressBar}{show a progress bar of alternative isoform generation?}

\item{junctions}{junctions GRanges object from readLeafcutterJunctions()}

\item{exportGTF}{file name to export alternative isoform GTFs (default=NULL)}

\item{uniprotData}{data.frame of uniprot sequence information}

\item{uniprotSeqFeatures}{data.frame of uniprot sequence features}
}
\value{
data.frame containing signficant whippet diff data and ORF change summaries
}
\description{
Compare open reading frames for whippet differentially spliced events
}
\examples{
leafcutterFiles <- list.files(system.file("extdata","leafcutter/",
package = "GeneStructureTools"), full.names = TRUE)
leafcutterIntrons <- read.delim(leafcutterFiles[
grep("intron_results", leafcutterFiles)],stringsAsFactors=FALSE)
gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
package = "GeneStructureTools"))
exons <- gtf[gtf$type=="exon"]
g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
leafcutterTranscriptChangeSummary(significantEvents = leafcutterIntrons,
exons=exons,BSgenome = g,NMD=FALSE)
}
\author{
Beth Signal
}
\concept{leafcutter data processing}
