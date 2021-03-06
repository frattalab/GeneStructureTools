% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/quickAnalysis.R
\name{transcriptChangeSummary}
\alias{transcriptChangeSummary}
\title{Compare open reading frames for two sets of paired transcripts}
\usage{
transcriptChangeSummary(transcriptsX, transcriptsY, BSgenome, exons,
  NMD = FALSE, NMDModel = NULL, compareBy = "gene",
  orfPrediction = "allFrames", compareToGene = FALSE,
  whippetDataSet = NULL, rearrangeXY = TRUE, exportGTF = NULL,
  uniprotData = NULL, uniprotSeqFeatures = NULL, selectLongest = 1)
}
\arguments{
\item{transcriptsX}{GRanges object with exon annotations for
all transcripts to be compared for the 'normal' condition}

\item{transcriptsY}{GRanges object with exon annotations for
all transcripts to be compared for the 'alternative' condition}

\item{BSgenome}{BSGenome object containing the genome for the species analysed}

\item{exons}{GRanges object made from a GTF containing exon coordinates}

\item{NMD}{Use NMD predictions? (Note: notNMD must be installed to use this feature)}

\item{NMDModel}{Use the "base" or "lncRNA" NMD model?}

\item{compareBy}{compare isoforms by 'transcript' id, or aggregate all changes occuring by 'gene'}

\item{orfPrediction}{What type of orf predictions to return. default= \code{"allFrames"}}

\item{compareToGene}{compare alternative isoforms to all normal gene isoforms (in exons)}

\item{whippetDataSet}{whippetDataSet generated from \code{readWhippetDataSet()}
Use if PSI directionality should be taken into account when comparing isoforms.}

\item{rearrangeXY}{should PSI directionality be taken into account?}

\item{exportGTF}{file name to export alternative isoform GTFs (default=\code{NULL})}

\item{uniprotData}{data.frame of uniprot sequence information}

\item{uniprotSeqFeatures}{data.frame of uniprot sequence features}

\item{selectLongest}{passed to getORFs()}
}
\value{
Summarised ORF changes data.frame
}
\description{
Compare open reading frames for two sets of paired transcripts
}
\examples{
whippetFiles <- system.file("extdata","whippet/",
package = "GeneStructureTools")
wds <- readWhippetDataSet(whippetFiles)
wds <- filterWhippetEvents(wds)

gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
package = "GeneStructureTools"))
exons <- gtf[gtf$type=="exon"]
g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10

wds.exonSkip <- filterWhippetEvents(wds, eventTypes="CE",psiDelta = 0.2)

exons.exonSkip <- findExonContainingTranscripts(wds.exonSkip, exons,
variableWidth=0, findIntrons=FALSE, transcripts)
ExonSkippingTranscripts <- skipExonInTranscript(exons.exonSkip, exons, whippetDataSet=wds.exonSkip)
transcriptChangeSummary(ExonSkippingTranscripts[ExonSkippingTranscripts$set=="included_exon"],
ExonSkippingTranscripts[ExonSkippingTranscripts$set=="skipped_exon"],
BSgenome=g,exons)
}
\seealso{
Other transcript isoform comparisons: \code{\link{attrChangeAltSpliced}},
  \code{\link{orfDiff}}
}
\author{
Beth Signal
}
\concept{transcript isoform comparisons}
