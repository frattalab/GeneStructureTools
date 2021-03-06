#' Filter out significant events from a whippet diff comparison
#' @param whippetDataSet whippetDataSet generated from \code{readWhippetDataSet()}
#' @param probability minimum probability required to call event as significant
#' @param psiDelta minimum change in psi required to call an event as significant
#' @param eventTypes which event type to filter for? default = \code{"all"}
#' @param idList (optional) list of gene ids to filter for
#' @param minCounts minumum number of counts for all replicates
#' in at least one condition to call an event as significant
#' @param medianCounts median count for all replicates
#' in at least one condition to call an event as significant
#' @param sampleTable data.frame with sample names and conditions.
#' Only needed if filtering with counts.
#' @return filtered whippet differential comparison data.frame
#' @export
#' @importFrom stats median
#' @family whippet data processing
#' @author Beth Signal
#' @examples
#' whippetFiles <- system.file("extdata","whippet/",
#' package = "GeneStructureTools")
#' wds <- readWhippetDataSet(whippetFiles)
#' wds <- filterWhippetEvents(wds)
filterWhippetEvents <- function(whippetDataSet,
                                probability = 0.95,
                                psiDelta = 0.1,
                                eventTypes = "all",
                                idList = NA,
                                minCounts = NA,
                                medianCounts = NA,
                                sampleTable){

    if(eventTypes[1] == "all"){
        eventTypes <- unique(diffSplicingResults(whippetDataSet)$type)
    }

    if(is.na(idList[1])){
        significantEventsIndex <-
            which(diffSplicingResults(whippetDataSet)$probability >
                      probability &
                      abs(diffSplicingResults(whippetDataSet)$psi_delta) >
                      psiDelta &
                      diffSplicingResults(whippetDataSet)$type %in%
                      eventTypes)
    }else{
        significantEventsIndex <-
            which(diffSplicingResults(whippetDataSet)$probability >
                      probability &
                      abs(diffSplicingResults(whippetDataSet)$psi_delta) >
                      psiDelta &
                      diffSplicingResults(whippetDataSet)$type %in%
                      eventTypes &
                      diffSplicingResults(whippetDataSet)$gene %in% idList)
    }

    slot(whippetDataSet, "diffSplicingResults") <-
        diffSplicingResults(whippetDataSet)[significantEventsIndex,]

    m <- match(diffSplicingResults(whippetDataSet)$coord,
               coordinates(whippetDataSet)$id)

    slot(whippetDataSet, "coordinates") <-
        coordinates(whippetDataSet)[unique(m),]

    keep <- which(readCounts(whippetDataSet)$Gene %in%
                      diffSplicingResults(whippetDataSet)$gene)

    slot(whippetDataSet, "readCounts") <-
        readCounts(whippetDataSet)[keep,]

    keep <- which(junctions(whippetDataSet)$gene %in%
                      diffSplicingResults(whippetDataSet)$gene)

    slot(whippetDataSet, "junctions") <-
        junctions(whippetDataSet)[keep,]


    #filter by read counts?
    if(nrow(slot(whippetDataSet, "readCounts")) > 0 & (!is.na(minCounts) |
                                                       !is.na(medianCounts))){
        m <- match(diffSplicingResults(whippetDataSet)$unique_name,
                   readCounts(whippetDataSet)$unique_name)
        n1 <- match(sampleTable$sample[
            sampleTable$condition %in%
                unique(diffSplicingResults(whippetDataSet)$condition_1)],
                    colnames(readCounts(whippetDataSet)))
        n2 <- match(sampleTable$sample[
            sampleTable$condition %in%
                unique(diffSplicingResults(whippetDataSet)$condition_2)],
                    colnames(readCounts(whippetDataSet)))

        diffSplicingResultsTemp <- diffSplicingResults(whippetDataSet)

        diffSplicingResultsTemp$condition_1_counts <-
            apply(readCounts(whippetDataSet)[m,n1], 1, stats::median)
        diffSplicingResultsTemp$condition_2_counts <-
            apply(readCounts(whippetDataSet)[m,n2], 1, stats::median)

        if(!is.na(minCounts)){
            keep <- which(apply(readCounts(whippetDataSet)[m,n1], 1,
                                function(x) all(x > minCounts)) |
                              apply(readCounts(whippetDataSet)[m,n2], 1,
                                    function(x) all(x > minCounts)))
            slot(whippetDataSet, "diffSplicingResults") <-
                diffSplicingResultsTemp[keep,]
        }

        if(!is.na(medianCounts)){
            keep <- which(diffSplicingResultsTemp$condition_1_counts >=
                              medianCounts |
                              diffSplicingResultsTemp$condition_2_counts >=
                              medianCounts)
            slot(whippetDataSet, "diffSplicingResults") <-
                diffSplicingResultsTemp[keep,]
        }

    }

    return(whippetDataSet)

}
#' Compare open reading frames for two sets of paired transcripts
#' @param transcriptsX GRanges object with exon annotations for
#' all transcripts to be compared for the 'normal' condition
#' @param transcriptsY GRanges object with exon annotations for
#' all transcripts to be compared for the 'alternative' condition
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param exons GRanges object made from a GTF containing exon coordinates
#' @param NMD Use NMD predictions? (Note: notNMD must be installed to use this feature)
#' @param NMDModel Use the "base" or "lncRNA" NMD model?
#' @param orfPrediction What type of orf predictions to return. default= \code{"allFrames"}
#' @param compareBy compare isoforms by 'transcript' id, or aggregate all changes occuring by 'gene'
#' @param compareToGene compare alternative isoforms to all normal gene isoforms (in exons)
#' @param whippetDataSet whippetDataSet generated from \code{readWhippetDataSet()}
#' Use if PSI directionality should be taken into account when comparing isoforms.
#' @param rearrangeXY should PSI directionality be taken into account?
#' @param exportGTF file name to export alternative isoform GTFs (default=\code{NULL})
#' @param uniprotData data.frame of uniprot sequence information
#' @param uniprotSeqFeatures data.frame of uniprot sequence features
#' @param selectLongest passed to getORFs()
#' @return Summarised ORF changes data.frame
#' @export
#' @import GenomicRanges
#' @importFrom rtracklayer import
#' @importFrom utils installed.packages
#' @family transcript isoform comparisons
#' @author Beth Signal
#' @examples
#' whippetFiles <- system.file("extdata","whippet/",
#' package = "GeneStructureTools")
#' wds <- readWhippetDataSet(whippetFiles)
#' wds <- filterWhippetEvents(wds)
#'
#' gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
#' package = "GeneStructureTools"))
#' exons <- gtf[gtf$type=="exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' wds.exonSkip <- filterWhippetEvents(wds, eventTypes="CE",psiDelta = 0.2)
#'
#' exons.exonSkip <- findExonContainingTranscripts(wds.exonSkip, exons,
#' variableWidth=0, findIntrons=FALSE, transcripts)
#' ExonSkippingTranscripts <- skipExonInTranscript(exons.exonSkip, exons, whippetDataSet=wds.exonSkip)
#' transcriptChangeSummary(ExonSkippingTranscripts[ExonSkippingTranscripts$set=="included_exon"],
#' ExonSkippingTranscripts[ExonSkippingTranscripts$set=="skipped_exon"],
#' BSgenome=g,exons)
transcriptChangeSummary <- function(transcriptsX,
                                    transcriptsY,
                                    BSgenome,
                                    exons,
                                    NMD = FALSE,
                                    NMDModel = NULL,
                                    compareBy="gene",
                                    orfPrediction = "allFrames",
                                    compareToGene = FALSE,
                                    whippetDataSet = NULL,
                                    rearrangeXY = TRUE,
                                    exportGTF = NULL,
                                    uniprotData=NULL,
                                    uniprotSeqFeatures=NULL,
                                    selectLongest=1){


    if(!is.null(whippetDataSet)){
        whippetEvents <- diffSplicingResults(whippetDataSet)

        if(rearrangeXY == TRUE){
            allTranscripts <- c(transcriptsX, transcriptsY)
            type <- gsub("_X","",gsub("_Y","", allTranscripts$set))
            type <- gsub("skipped_exon", "CE", gsub("included_exon","CE", type))
            type <- gsub("retained_intron", "RI", gsub("spliced_intron","RI", type))

            m <- match(paste0(allTranscripts$whippet_id,"_",type),
                       paste0(whippetEvents$coord,"_",
                              whippetEvents$type))
            # A -- psi in condition 1 (A) is higher (i.e. included -- > skipped)
            normA <- which(whippetEvents$psi_a > whippetEvents$psi_b)
            # B -- psi in condition 2 (B) is higher (i.e. skipped -- > included)
            normB <- which(whippetEvents$psi_a < whippetEvents$psi_b)

            #sets for X (+A)
            setsX <- c(paste0(unique(type), "_Y"), "included_exon","retained_intron")
            #sets for Y (+B)
            setsY <- c(paste0(unique(type), "_X"), "skipped_exon","spliced_intron")

            transcriptsX <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsX) |
                          (m %in% normB & allTranscripts$set %in% setsY))]

            transcriptsY <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsY) |
                          (m %in% normB & allTranscripts$set %in% setsX))]
        }

    }

    if(!is.null(exportGTF)){
        transcriptsX$comp_set <- "X"
        transcriptsY$comp_set <- "Y"
        transcriptsXY <- c(transcriptsX, transcriptsY)

        rtracklayer::export.gff(transcriptsXY, con=exportGTF, format="gtf")

        transcriptsX$comp_set <- NULL
        transcriptsY$comp_set <- NULL
    }

    if(orfPrediction == "allFrames"){
        orfsX <- getOrfs(transcriptsX, BSgenome,returnLongestOnly = FALSE,
                         allFrames = TRUE, uORFs = TRUE,
                         selectLongest = selectLongest)
        orfsY <- getOrfs(transcriptsY, BSgenome,returnLongestOnly = FALSE,
                         allFrames = TRUE, uORFs = TRUE,
                         selectLongest = selectLongest)
    }else{
        orfsX <- getOrfs(transcriptsX, BSgenome,returnLongestOnly = TRUE,
                         uORFs = TRUE, selectLongest = selectLongest)
        orfsY <- getOrfs(transcriptsY, BSgenome,returnLongestOnly = TRUE,
                         uORFs = TRUE, selectLongest = selectLongest)
    }

    if(all(!grepl("[+]", orfsX$id))){

        if(orfPrediction == "allFrames"){
            Yid.withFrame <- paste0(unlist(lapply(
                str_split(orfsY$id, "[+]"),"[[",1)),"_", orfsY$frame)
            Xid.withFrame <- paste0(orfsX$id,"_", orfsX$frame)
            m <- match(Yid.withFrame, Xid.withFrame)
        }else{
            m <- match(unlist(lapply(str_split(orfsY$id, "[+]"),"[[",1)),
                       orfsX$id)
        }

        orfsX<- orfsX[m,]
        orfsX$id <- orfsY$id
        #orfsX <- orfsX[which(!duplicated(orfsX$id)),]
    }

    # manual NMD
    notNMDInstalled <- "notNMD" %in% rownames(utils::installed.packages())
    notNMDLoaded <- "notNMD" %in% loadedNamespaces()

    if(NMD == TRUE){

        if(is.null(NMDModel)){
            useModel <- "base"
        }else{
            useModel <- NMDModel
        }

        if(notNMDInstalled & notNMDLoaded == FALSE){
            save(orfsX, orfsY, BSgenome, useModel, file="temp_ORFs.Rdata")

            #### run notnmd
            scriptLoc <- system.file("extdata","NMD_from_object.R",
                                     package = "notNMD")
            system(paste0("Rscript ", scriptLoc, " temp_ORFs.Rdata"))

            load("temp_ORFs.Rdata")
            system("rm -f temp_ORFs.Rdata")

        }else if(notNMDInstalled & notNMDLoaded == TRUE){

            if(exists("orfsX")){
                orfsX$nmd_prob <- predictNMD(orfsX, "prob", model = useModel)
                orfsX$nmd_class <- predictNMD(orfsX, model = useModel)
            }

            if(exists("orfsY")){
                orfsY$nmd_prob <- predictNMD(orfsY, "prob", model = useModel)
                orfsY$nmd_class <- predictNMD(orfsY, model = useModel)
            }

        }else{
            message("package notNMD is not installed")
            message("Skipping NMD calculations")
        }
    }

    orfsX <- orfsX[which(!is.na(orfsX$orf_length)),]
    orfsY <- orfsY[which(!is.na(orfsY$orf_length)),]

    if(compareToGene == TRUE){

        if(NMD == TRUE & notNMDInstalled & notNMDLoaded == FALSE){
            orfAllGenes <- getOrfs(exons[exons$gene_id %in%
                                             unique(c(transcriptsX$gene_id,
                                                      transcriptsY$gene_id))],
                                   BSgenome,returnLongestOnly = TRUE,
                                   selectLongest = selectLongest)

            save(orfAllGenes, BSgenome, file="temp_ORFs.Rdata")
            system(paste0("Rscript ", scriptLoc, " temp_ORFs.Rdata"))
            load("temp_ORFs.Rdata")
            system("rm -f temp_ORFs.Rdata")
            #orfAllGenes <- orfAllGenes[orfAllGenes$nmd_prob > 0.5,]

        }else if(notNMDInstalled & notNMDLoaded == TRUE){

            orfAllGenes$nmd_prob <- predictNMD(orfAllGenes, "prob", model = useModel)
            orfAllGenes$nmd_class <- predictNMD(orfAllGenes, model = useModel)

        }else{
            orfAllGenes <- getOrfs(
                exons[exons$gene_id %in%
                          unique(c(transcriptsX$gene_id,
                                   transcriptsY$gene_id)) &
                          exons$transcript_type=="protein_coding"],
                BSgenome=BSgenome,returnLongestOnly = TRUE)
        }

        orfChange <- orfDiff(orfsX, orfsY, filterNMD = NMD, compareBy = "gene",
                             geneSimilarity = TRUE,
                             allORFs = orfAllGenes,compareUTR = TRUE,
                             uniprotData = uniprotData,
                             uniprotSeqFeatures = uniprotSeqFeatures)
    }else{
        orfChange <- orfDiff(orfsX, orfsY, filterNMD = NMD, compareBy = "gene",
                             compareUTR = TRUE,
                             uniprotData = uniprotData,
                             uniprotSeqFeatures = uniprotSeqFeatures)
    }



    if(NMD == TRUE){
        orfsX$nmd_class_manual <- "nonsense_mediated_decay"
        orfsX$nmd_class_manual[orfsX$orf_length > 50 &
                                   (orfsX$min_dist_to_junction_b < 50 |
                                        orfsX$exon_b_from_final == 0)] <-
            "not_nmd"

        orfsX$nmd_prob_manual <- 1
        orfsX$nmd_prob_manual[orfsX$nmd_class_manual == "not_nmd"] <- 0

        orfsY$nmd_class_manual <- "nonsense_mediated_decay"
        orfsY$nmd_class_manual[orfsY$orf_length > 50 &
                                   (orfsY$min_dist_to_junction_b < 50 |
                                        orfsY$exon_b_from_final == 0)] <-
            "not_nmd"

        orfsY$nmd_prob_manual <- 1
        orfsY$nmd_prob_manual[orfsY$nmd_class_manual == "not_nmd"] <- 0

    }
    if(NMD == TRUE & notNMDInstalled){
        nmdChange <- attrChangeAltSpliced(orfsX,
                                          orfsY,
                                          attribute="nmd_prob",
                                          compareBy="gene",
                                          useMax=FALSE)
        m <- match(orfChange$id, nmdChange$id)
        orfChange <- cbind(orfChange, nmdChange[m,-1])

        nmdChangeMan <- attrChangeAltSpliced(orfsX,
                                             orfsY,
                                             attribute="nmd_prob_manual",
                                             compareBy="gene",
                                             useMax=FALSE)
        m <- match(orfChange$id, nmdChangeMan$id)
        orfChange <- cbind(orfChange, nmdChangeMan[m,-1])


    }
    if(!is.null(whippetDataSet)){
        m <- match(orfChange$id, whippetEvents$coord)
        orfChange <- cbind(whippetEvents[m,], orfChange)
    }
    return(orfChange)

}

#' Compare open reading frames for whippet differentially spliced events
#' @param whippetDataSet whippetDataSet generated from \code{readWhippetDataSet()}
#' @param eventTypes which event type to filter for? default = "all"
#' @param exons GRanges gtf annotation of exons
#' @param transcripts GRanges gtf annotation of transcripts
#' @param gtf.all GRanges gtf annotation (can be used instead of specifying exons and transcripts)
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param NMD Use NMD predictions? (Note: notNMD must be installed to use this feature)
#' @param exportGTF file name to export alternative isoform GTFs (default=NULL)
#' @param rearrangeXY should PSI directionality be taken into account?
#' @param uniprotData data.frame of uniprot sequence information
#' @param uniprotSeqFeatures data.frame of uniprot sequence features
#' @param selectLongest passed to getORFs()
#' @return data.frame containing signficant whippet diff data and ORF change summaries
#' @export
#' @importFrom rtracklayer import
#' @import GenomicRanges
#' @family whippet data processing
#' @author Beth Signal
#' @examples
#' whippetFiles <- system.file("extdata","whippet/",
#' package = "GeneStructureTools")
#' wds <- readWhippetDataSet(whippetFiles)
#' wds <- filterWhippetEvents(wds)
#'
#' gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
#' package = "GeneStructureTools"))
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#' whippetTranscriptChangeSummary(wds, gtf.all=gtf,BSgenome = g)
whippetTranscriptChangeSummary <- function(whippetDataSet,
                                           gtf.all=NULL,
                                           BSgenome,
                                           eventTypes = "all",
                                           exons=NULL,
                                           transcripts=NULL,
                                           NMD = FALSE,
                                           exportGTF = NULL,
                                           rearrangeXY = FALSE,
                                           uniprotData=NULL,
                                           uniprotSeqFeatures=NULL,
                                           selectLongest=1){


    # diffSplicingResults(whippetDataSet)

    if(is.null(exons) & !is.null(gtf.all)){
        exons <- gtf.all[gtf.all$type=="exon"]
    }
    if(is.null(transcripts) & !is.null(gtf.all)){
        transcripts <- gtf.all[gtf.all$type=="transcript"]
    }else if(is.null(transcripts) & !is.null(exons)){
        transcripts <- exonsToTranscripts(exons)
    }


    if(eventTypes[1] == "all"){
        eventTypes <- unique(diffSplicingResults(whippetDataSet)$type)
    }
    if(!is.null(exportGTF)){
        exportedTranscripts <- list()
    }
    if(any(eventTypes == "CE") &
       any(diffSplicingResults(whippetDataSet)$type == "CE")){


        whippetDataSet.ce <- filterWhippetEvents(whippetDataSet,
                                                 probability = 0,
                                                 psiDelta = 0,
                                                 eventTypes="CE")

        significantEvents.ce <- diffSplicingResults(whippetDataSet.ce)

        exons.ce <- findExonContainingTranscripts(input=whippetDataSet.ce,
                                                  exons=exons,
                                                  variableWidth=0,
                                                  findIntrons=FALSE,
                                                  transcripts=transcripts)
        # make skipped exon transcripts
        skippedExonTranscripts <- skipExonInTranscript(whippetDataSet=whippetDataSet.ce,
                                                       skippedExons = exons.ce,
                                                       exons = exons,
                                                       glueExons = TRUE)

        orfChanges.ce <- transcriptChangeSummary(
            skippedExonTranscripts[skippedExonTranscripts$set=="included_exon"],
            skippedExonTranscripts[skippedExonTranscripts$set=="skipped_exon"],
            BSgenome = BSgenome,NMD = NMD, whippetDataSet=whippetDataSet.ce,
            rearrangeXY = rearrangeXY,
            uniprotData = uniprotData,
            uniprotSeqFeatures = uniprotSeqFeatures,
            selectLongest = selectLongest)
        # add to significantEvents.ce
        m <- match(significantEvents.ce$coord, orfChanges.ce$id)
        significantEvents.ce <- cbind(significantEvents.ce, orfChanges.ce[m,-1])

        if(exists("SignificantEvents.withORF")){
            SignificantEvents.withORF <- rbind(SignificantEvents.withORF,
                                               significantEvents.ce)
        }else{
            SignificantEvents.withORF <- significantEvents.ce
        }
        if(!is.null(exportGTF)){
            exportedTranscripts <- c(exportedTranscripts,
                                     skippedExonTranscripts)
        }
    }
    if(any(eventTypes == "RI") & any(diffSplicingResults(whippetDataSet)$type ==
                                     "RI")){

        whippetDataSet.ri <- filterWhippetEvents(whippetDataSet,
                                                 probability = 0,
                                                 psiDelta = 0,
                                                 eventTypes="RI")

        significantEvents.ri <- diffSplicingResults(whippetDataSet.ri)

        exons.ri <- findIntronContainingTranscripts(input=whippetDataSet.ri,
                                                    exons=exons)

        # find introns in the gtf that overlap whippet introns
        significantEvents.ri <-
            diffSplicingResults(whippetDataSet)[which(
                diffSplicingResults(whippetDataSet)$type=="RI"),]
        # add the intron into transcripts
        retainedIntronTranscripts <- addIntronInTranscript(whippetDataSet=whippetDataSet.ri,
                                                           flankingExons = exons.ri,
                                                           exons = exons,
                                                           glueExons = TRUE)


        orfChanges.ri <- transcriptChangeSummary(
            retainedIntronTranscripts[retainedIntronTranscripts$set==
                                          "spliced_intron"],
            retainedIntronTranscripts[retainedIntronTranscripts$set==
                                          "retained_intron"],
            BSgenome = BSgenome,NMD = NMD, whippetDataSet=whippetDataSet.ri,
            rearrangeXY = rearrangeXY,
            uniprotData = uniprotData,
            uniprotSeqFeatures = uniprotSeqFeatures,
            selectLongest = selectLongest)
        # add to significantEvents.ce
        m <- match(significantEvents.ri$coord, orfChanges.ri$id)
        significantEvents.ri <- cbind(significantEvents.ri, orfChanges.ri[m,-1])

        if(exists("SignificantEvents.withORF")){
            SignificantEvents.withORF <- rbind(SignificantEvents.withORF,
                                               significantEvents.ri)
        }else{
            SignificantEvents.withORF <- significantEvents.ri
        }
        if(!is.null(exportGTF)){
            exportedTranscripts <- c(exportedTranscripts,
                                     retainedIntronTranscripts)
        }
    }
    if(any(eventTypes %in% c("AA","AD","AF","AL")) &
       any(diffSplicingResults(whippetDataSet)$type %in%
           c("AA","AD","AF","AL"))){

        events.junctions <- eventTypes[eventTypes %in% c("AA","AD","AF","AL")]
        events.significant <- unique(diffSplicingResults(whippetDataSet)$type)
        events.significant <- events.significant[events.significant %in%
                                                     events.junctions]

        for(e in seq_along(events.significant)){

            event <- events.significant[e]

            whippetDataSet.jnc <- filterWhippetEvents(whippetDataSet,
                                                      probability = 0,
                                                      psiDelta = 0,
                                                      eventTypes=event)

            significantEvents.jnc <- diffSplicingResults(whippetDataSet.jnc)

            junctionPairs <- findJunctionPairs(whippetDataSet.jnc, type=event)

            # check for pairs
            ids.x <- unique(junctionPairs$whippet_id[junctionPairs$set=="X"])
            ids.x <- ids.x[ids.x %in% unique(
                junctionPairs$whippet_id[junctionPairs$set=="Y"])]

            significantEvents.jnc <-significantEvents.jnc[
                which(significantEvents.jnc$coord %in% ids.x),]
            junctionPairs <- junctionPairs[
                which(junctionPairs$whippet_id %in% ids.x),]

            if(nrow(significantEvents.jnc) > 0){
                # make transcripts with alternative junction usage
                altTranscripts <- replaceJunction(whippetDataSet.jnc,
                                                  junctionPairs,
                                                  exons, type=event)
                orfChanges.jnc <- transcriptChangeSummary(
                    transcriptsX = altTranscripts[
                        altTranscripts$set==paste0(event, "_X")],
                    transcriptsY = altTranscripts[
                        altTranscripts$set==paste0(event, "_Y")],
                    BSgenome = BSgenome,NMD = NMD,
                    whippetDataSet=whippetDataSet.jnc,
                    rearrangeXY = rearrangeXY,
                    uniprotData = uniprotData,
                    uniprotSeqFeatures = uniprotSeqFeatures,
                    selectLongest = selectLongest)

                # add to significantEvents
                m <- match(significantEvents.jnc$coord, orfChanges.jnc$id)
                significantEvents.jnc <- cbind(significantEvents.jnc,
                                               orfChanges.jnc[m,-1])

                if(exists("SignificantEvents.withORF")){
                    SignificantEvents.withORF <-
                        rbind(SignificantEvents.withORF,
                              significantEvents.jnc)
                }else{
                    SignificantEvents.withORF <- significantEvents.jnc
                }
                if(!is.null(exportGTF)){
                    exportedTranscripts <- c(exportedTranscripts,
                                             altTranscripts)
                }
            }
        }

    }
    if(!is.null(exportGTF)){
        exportedTranscripts <- do.call("c", exportedTranscripts)
        rtracklayer::export.gff(exportedTranscripts, con=exportGTF,
                                format="gtf")
    }
    if(exists("SignificantEvents.withORF")){
        return(SignificantEvents.withORF)
    }else{
        return(NULL)
    }
}
#' Compare open reading frames for whippet differentially spliced events
#' @param significantEvents  data.frame containing information from the
#' per_intron_results.tab file output from leafcutter.
#' @param combineGeneEvents combine clusters occuring in the same gene?
#' Currently not reccomended.
#' @param exons GRanges gtf annotation of exons
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param NMD Use NMD predictions? (Note: notNMD must be installed to use this feature)
#' @param showProgressBar show a progress bar of alternative isoform generation?
#' @param junctions junctions GRanges object from readLeafcutterJunctions()
#' @param exportGTF file name to export alternative isoform GTFs (default=NULL)
#' @param uniprotData data.frame of uniprot sequence information
#' @param uniprotSeqFeatures data.frame of uniprot sequence features
#' @return data.frame containing signficant whippet diff data and ORF change summaries
#' @export
#' @importFrom utils setTxtProgressBar
#' @importFrom utils txtProgressBar
#' @importFrom stringr str_split
#' @importFrom rtracklayer import
#' @import GenomicRanges
#' @family leafcutter data processing
#' @author Beth Signal
#' @examples
#' leafcutterFiles <- list.files(system.file("extdata","leafcutter/",
#' package = "GeneStructureTools"), full.names = TRUE)
#' leafcutterIntrons <- read.delim(leafcutterFiles[
#' grep("intron_results", leafcutterFiles)],stringsAsFactors=FALSE)
#' gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
#' package = "GeneStructureTools"))
#' exons <- gtf[gtf$type=="exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#' leafcutterTranscriptChangeSummary(significantEvents = leafcutterIntrons,
#' exons=exons,BSgenome = g,NMD=FALSE)

leafcutterTranscriptChangeSummary <- function(significantEvents,
                                              combineGeneEvents=FALSE,
                                              exons,
                                              BSgenome,
                                              NMD = FALSE,
                                              showProgressBar=TRUE,
                                              junctions=NULL,
                                              exportGTF=NULL,
                                              uniprotData=NULL,
                                              uniprotSeqFeatures=NULL){


    geneEvents <- as.data.frame(table(significantEvents$ensemblID,
                                      significantEvents$clusterID))
    geneEvents <- geneEvents[geneEvents$Freq!=0,]

    if(combineGeneEvents == FALSE){
        if(showProgressBar){
            message(paste0("Generating alternative isoforms for ",
                           nrow(geneEvents), " clusters:"))
            pb <- utils::txtProgressBar(min = 0, max = nrow(geneEvents),
                                        style = 3)
        }

        altIso <- alternativeIntronUsage(altIntronLocs = significantEvents[significantEvents$clusterID == geneEvents$Var2[1],],
            exons, junctions=junctions)
        if(showProgressBar){utils::setTxtProgressBar(pb, 1)}

        if(nrow(geneEvents) > 1){
            for(i in 2:nrow(geneEvents)){
                altIntronLocs = significantEvents[
                    significantEvents$clusterID == geneEvents$Var2[i],]

                altIntronLocs$deltapsi <- altIntronLocs$PSI_a - altIntronLocs$PSI_b
                if(all(altIntronLocs$deltapsi < 0) | all(altIntronLocs$deltapsi > 0)){
                    altIntronLocs <- altIntronLocs[-(1:nrow(altIntronLocs)),]
                }

                if(nrow(altIntronLocs) > 1){
                    altIso1 <- alternativeIntronUsage(altIntronLocs, exons, junctions=junctions)
                    if(!is.null(altIso1)){
                        altIso <- c(altIso, altIso1)
                    }
                }
                if(showProgressBar){utils::setTxtProgressBar(pb, i)}

            }
        }
    }else{
        genes <- unique(geneEvents$Var1)
        if(showProgressBar){
            message(paste0("Generating alternative isoforms for ",
                           nrow(geneEvents), " genes:"))
            pb <- utils::txtProgressBar(min = 0, max = length(genes), style = 3)
        }
        for(j in seq_along(genes)){
            clusters <- geneEvents[geneEvents$Var1==genes[j],]

            altIso <- alternativeIntronUsage(significantEvents[
                significantEvents$clusterID == clusters$Var2[1],],
                exons)

            if(nrow(clusters) > 1){
                for(i in 2:nrow(clusters)){
                    altIntronLocs = significantEvents[
                        significantEvents$clusterID == clusters$Var2[i],]
                    altIntronLocs <- altIntronLocs[altIntronLocs$verdict==
                                                       "annotated",]
                    if(nrow(altIntronLocs) > 1){
                        altIso1 <- alternativeIntronUsage(altIntronLocs,
                                                          c(exons, altIso))
                        altIso <- c(altIso, altIso1)
                    }

                }
            }
            if(showProgressBar){utils::setTxtProgressBar(pb, j)}

        }


    }
    if(is.list(altIso)){
        if(length(altIso) > 1){
            altIso <- do.call("c", altIso)
        }
    }

    altIso$spliced_id <- unlist(lapply(
        stringr::str_split(altIso$transcript_id, " "),"[[",2))

    transcriptsX <- altIso[grep("dnre", altIso$transcript_id)]
    transcriptsY <- altIso[grep("upre", altIso$transcript_id)]

    if(!is.null(exportGTF)){
        rtracklayer::export.gff(altIso, con=exportGTF, format="gtf")
    }

    orfDiff <- transcriptChangeSummary(transcriptsX,
                                       transcriptsY,
                                       BSgenome = BSgenome,
                                       NMD = NMD,
                                       uniprotData = uniprotData,
                                       uniprotSeqFeatures = uniprotSeqFeatures)
    m <- match(gsub("_","",significantEvents$clusterID), orfDiff$id)
    significantEvents.withORF <- cbind(significantEvents, orfDiff[m,-1])
    #significantEvents.withORF <- significantEvents.withORF[!duplicated(m),]

    return(significantEvents.withORF)
}
