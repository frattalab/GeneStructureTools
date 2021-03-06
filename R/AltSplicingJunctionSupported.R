#' Find alternative junctions for Whippet alternative splicing events
#'
#' Find junctions that pair with each end of an AA (alt. acceptor) or
#' AD (alt. donor) whippet range
#' Find junctions that pair with the upsteam/downstream exon of an
#' AF (alt. first exon) or an AL (alt. last exon)
#' @param whippetDataSet whippetDataSet generated from \code{readWhippetDataSet()}
#' @param type type of Whippet event (AA/AD/AF/AL).
#' Note only one event type should be processed at a time.
#' @return GRanges object with alternative junctions.
#' Each event should have a set of X (for which the psi measurement is reported) junctions,
#' and alternative Y junctions.
#' @export
#' @import GenomicRanges
#' @family whippet splicing isoform creation
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
#' transcripts <- gtf[gtf$type=="transcript"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' wds.altAce <- filterWhippetEvents(wds, eventTypes="AA")
#' jncPairs.altAce <- findJunctionPairs(wds.altAce, type="AA")
#'
#' wds.altDon <- filterWhippetEvents(wds, eventTypes="AD")
#' jncPairs.altDon <- findJunctionPairs(wds.altDon, type="AD")
#'
#' wds.altFirst <- filterWhippetEvents(wds, eventTypes="AF", psiDelta=0.2)
#' jncPairs.altFirst <- findJunctionPairs(wds.altFirst, type="AF")
#'
#' wds.altLast <- filterWhippetEvents(wds, eventTypes="AL", psiDelta=0.2)
#' jncPairs.altLast <- findJunctionPairs(wds.altLast, type="AL")
findJunctionPairs <- function(whippetDataSet, type=NA){


    whippetDataSet <- filterWhippetEvents(whippetDataSet,
                                          probability = 0,
                                          psiDelta = 0,
                                          eventTypes=type)

    eventCoords <- coordinates(whippetDataSet)
    jncCoords <- junctions(whippetDataSet)

    eventCoords$type <- type
    # search for alternatives to the left or the right?
    eventCoords$search <- "right"
    eventCoords$search[(eventCoords$type=="AA" &
                            as.logical(strand(eventCoords) == '+'))|
                           (eventCoords$type=="AD" &
                                as.logical(strand(eventCoords) == '-'))|
                           (eventCoords$type=="AF" &
                                as.logical(strand(eventCoords) == '-'))|
                           (eventCoords$type=="AL" &
                                as.logical(strand(eventCoords) == '+'))] <-
        "left"

    junctionSJA.right <- eventCoords[eventCoords$search=="right"]
    junctionSJA.left <- eventCoords[eventCoords$search=="left"]

    # right if AA&-
    # left if AA&+
    olA.from <- vector()
    if(length(junctionSJA.right) > 0){
        if(type %in% c("AA", "AD")){
            start(junctionSJA.right) <- start(junctionSJA.right) -1
            end(junctionSJA.right) <- start(junctionSJA.right)
        }else{
            start(junctionSJA.right) <- end(junctionSJA.right)
        }
        olA.right <- findOverlaps(junctionSJA.right, jncCoords, type="start")
        olA.from <- append(olA.from,
                           as.character(junctionSJA.right$id[olA.right@from]))
        junctionsA <- jncCoords[olA.right@to]
    }
    if(length(junctionSJA.left) > 0){
        end(junctionSJA.left) <- start(junctionSJA.left)
        olA.left <- findOverlaps(junctionSJA.left, jncCoords, type="end")
        olA.from <- append(olA.from,
                           as.character(junctionSJA.left$id[olA.left@from]))
        if(exists("junctionsA")){
            junctionsA <- c(junctionsA, jncCoords[olA.left@to])
        }else{
            junctionsA <- jncCoords[olA.left@to]
        }
    }

    if(length(junctionsA) > 0){
        junctionsA$whippet_id <- olA.from
        junctionsA$search <- eventCoords$search[match(junctionsA$whippet_id,
                                                      eventCoords$id)]
        junctionsA$set <- "A"
    }

    if(type %in% c("AA","AD")){
        if(length(junctionsA) > 0){

            # junction B only required if AA/AD
            junctionSJB.right <- eventCoords[eventCoords$search=="right"]
            junctionSJB.left <- eventCoords[eventCoords$search=="left"]

            # same for B junctions
            olB.from <- vector()
            if(length(junctionSJB.right) > 0){
                start(junctionSJB.right) <- end(junctionSJB.right)
                olB.right <- findOverlaps(junctionSJB.right, jncCoords,
                                          type="start")
                olB.from <- append(olB.from,
                                   as.character(
                                       junctionSJB.right$id[olB.right@from]))
                junctionsB <- jncCoords[olB.right@to]
            }
            if(length(junctionSJB.left) > 0){
                end(junctionSJB.left) <- end(junctionSJB.left) +1
                start(junctionSJB.left) <- end(junctionSJB.left)
                olB.left <- findOverlaps(junctionSJB.left, jncCoords, type="end")
                olB.from <- append(olB.from,
                                   as.character(junctionSJB.left$id[olB.left@from]))
                if(exists("junctionsB")){
                    junctionsB <- c(junctionsB, jncCoords[olB.left@to])
                }else{
                    junctionsB <- jncCoords[olB.left@to]
                }
            }
            if(length(junctionsB) > 0 & length(junctionsA) > 0){
                junctionsB$whippet_id <- olB.from
                junctionsB$search <- eventCoords$search[match(junctionsB$whippet_id,
                                                              eventCoords$id)]
                junctionsB$set <- "B"
                junctions <- c(junctionsA, junctionsB)
            }else{
                junctions <- NULL
            }
        }else{
            junctions <- NULL
        }
    }

    if(type %in% c("AF","AL")){
        if(length(junctionsA) > 0){
            junctionsA.left <- junctionsA[junctionsA$search=="left"]
            junctionsA.right <- junctionsA[junctionsA$search=="right"]

            if(length(junctionsA.left) > 0){
                end(junctionsA.left) <- start(junctionsA.left)
                olC.left <- findOverlaps(junctionsA.left, jncCoords, type="start")
                junctionsC.left <- jncCoords[olC.left@to]
                junctionsC.left$whippet_id <-
                    junctionsA.left$whippet_id[olC.left@from]
                junctionsC.left$search <- junctionsA.left$search[olC.left@from]
                ol <- findOverlaps(junctionsC.left, junctionsA, type="equal")
                if(length(ol) > 0){
                    junctionsC.left <- junctionsC.left[-ol@from]
                }
                junctionsC <- junctionsC.left
            }
            if(length(junctionsA.right) > 0){
                start(junctionsA.right) <- end(junctionsA.right)
                olC.right <- findOverlaps(junctionsA.right, jncCoords, type="end")
                junctionsC.right <- jncCoords[olC.right@to]
                junctionsC.right$whippet_id <-
                    junctionsA.right$whippet_id[olC.right@from]
                junctionsC.right$search <- junctionsA.right$search[olC.right@from]
                ol <- findOverlaps(junctionsC.right, junctionsA, type="equal")
                if(length(ol) > 0){
                    junctionsC.right <- junctionsC.right[-ol@from]
                }
                if(exists("junctionsC")){
                    junctionsC <- c(junctionsC, junctionsC.right)
                }else{
                    junctionsC <- junctionsC.right
                }
            }

            if(length(junctionsC) > 0 & length(junctionsA) > 0){
                junctionsC$set <- "C"
                junctions <- c(junctionsA, junctionsC)
            }else{
                junctions <- NULL
            }
        }else{
            junctions <- NULL
        }
    }

    if(!is.null(junctions)){
        keep <- which(width(junctions) > 2)

        # replace junction codes
        if(type %in% c("AA", "AD")){
            junctions$set[which((junctions$set=="A" &
                                     as.logical(strand(junctions) == "+")) |
                                    (junctions$set=="B" &
                                    as.logical(strand(junctions) == "-")))] <- "X"
            junctions$set[which((junctions$set=="A" &
                                     as.logical(strand(junctions) == "-")) |
                                    (junctions$set=="B" &
                                    as.logical(strand(junctions) == "+")))] <- "Y"
        }
        if(type %in% c("AF", "AL")){
            junctions$set[which(junctions$set=="A")] <- "X"
            junctions$set[which(junctions$set=="C")] <- "Y"
        }

        junctions <- junctions[keep]
        return(junctions)
    }else{
        return(NULL)
    }
}

#' Find transcripts containing/overlapping junctions and replace them with alternative junctions
#'
#' @param whippetDataSet whippetDataSet generated from \code{readWhippetDataSet()}
#' @param junctionPairs GRanges object with alternative Whippet junctions.
#' Generated by findJunctionPairs()
#' @param exons GRanges object made from a GTF containing exon coordinates
#' @param type type of Whippet event (AA/AD/AF/AL).
#' Note only one event type should be processed at a time.
#' @return GRanges object with transcripts containing alternative junctions.
#' @export
#' @importFrom rtracklayer import
#' @import GenomicRanges
#' @family whippet splicing isoform creation
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
#' transcripts <- gtf[gtf$type=="transcript"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' wds.altAce <- filterWhippetEvents(wds, eventTypes="AA")
#' jncPairs.altAce <- findJunctionPairs(wds.altAce, type="AA")
#' transcripts.altAce <- replaceJunction(wds.altAce, jncPairs.altAce, exons, type="AA")
#'
#' wds.altDon <- filterWhippetEvents(wds, eventTypes="AD")
#' jncPairs.altDon <- findJunctionPairs(wds.altDon, type="AD")
#' transcripts.altDon <- replaceJunction(wds.altDon, jncPairs.altDon, exons, type="AD")
#'
#' wds.altFirst <- filterWhippetEvents(wds, eventTypes="AF", psiDelta=0.2)
#' jncPairs.altFirst <- findJunctionPairs(wds.altFirst, type="AF")
#' transcripts.altFirst <- replaceJunction(wds.altFirst, jncPairs.altFirst, exons, type="AF")
#'
#' wds.altLast <- filterWhippetEvents(wds, eventTypes="AL", psiDelta=0.2)
#' jncPairs.altLast <- findJunctionPairs(wds.altLast, type="AL")
#' transcripts.altLast <- replaceJunction(wds.altLast, jncPairs.altLast, exons, type="AL")
replaceJunction <- function(whippetDataSet, junctionPairs, exons, type=NA){


    junctionPairs$type <- type
    range <- junctionPairs

    eventCoords <- coordinates(whippetDataSet)
    eventCoords <- eventCoords[eventCoords$id %in% junctionPairs$whippet_id]


    if(type %in% c("AA", "AD")){
        ## find exons that use/overlap the junction - at the side where it's alternative
        end(range)[which(range$search=="right")] <-
            start(range)[which(range$search=="right")]
        start(range)[which(range$search=="left")] <-
            end(range)[which(range$search=="left")]

        ol.junction <- findOverlaps(range, exons)
        ol.junction <- cbind(as.data.frame(ol.junction),
                             transcript_id=exons$transcript_id[ol.junction@to])

        ## table of transcripts overlapping the junction
        # tid: transcript id
        tidTable <- as.data.frame(table(ol.junction$queryHits,
                                        ol.junction$transcript_id))
        tidTable <- tidTable[tidTable$Freq > 0,]
        colnames(tidTable)[1:2] <- c("from_index","to_transcript_id")
        tids <- unique(tidTable$to_transcript_id)

        #all combinations of transcripts + junctions
        tidTable <- data.frame(from_index=rep(1:length(junctionPairs),
                                              each=length(tids)),
                               to_transcript_id=rep(tids,
                                                    length(junctionPairs)),
                               Freq=1)

        tidTable$junction_id <- range$id[tidTable$from_index]
        ## new transcript id:
        ## unique if different junctions are going to be used in same transcript base
        tidTable$new_transcript_id <- paste0(tidTable$to_transcript_id,"+AS",
                                             " ",tidTable$junction_id)

        ## all transcripts for structural altercations
        gtfTranscripts <- exons[exons$transcript_id %in% tids]
        mcols(gtfTranscripts) <-
            mcols(gtfTranscripts)[,c('gene_id','transcript_id',
                                     'transcript_type','exon_id',
                                     'exon_number')]
        m <- match(gtfTranscripts$transcript_id, tidTable$to_transcript_id)
        # add new transcript id
        gtfTranscripts$new_transcript_id <-
            paste0(gtfTranscripts$transcript_id,"+AS ",
                   range$id[tidTable$from_index[m]])
        gtfTranscripts$new_transcript_id_exnum <-
            paste0(gtfTranscripts$new_transcript_id,"_",
                   as.numeric(gtfTranscripts$exon_number))

        # duplicate core transcripts if needed
        needsDuplicated <- which(!(tidTable$new_transcript_id %in%
                                       gtfTranscripts$new_transcript_id))
        if(length(needsDuplicated) > 0){
            gtfTranscripts.add <- gtfTranscripts[
                gtfTranscripts$transcript_id %in%
                    tidTable$to_transcript_id[needsDuplicated]]
        }
        while(length(needsDuplicated) > 0){
            gtfTranscripts.add <- gtfTranscripts.add[
                gtfTranscripts.add$transcript_id %in%
                    tidTable$to_transcript_id[needsDuplicated]]
            m <- match(gtfTranscripts.add$transcript_id,
                       tidTable$to_transcript_id[needsDuplicated])
            gtfTranscripts.add$new_transcript_id <-
                paste0(gtfTranscripts.add$transcript_id,"+AS ",
                       tidTable$junction_id[needsDuplicated][m])
            gtfTranscripts <- c(gtfTranscripts, gtfTranscripts.add)
            needsDuplicated <- which(!(tidTable$new_transcript_id %in%
                                           gtfTranscripts$new_transcript_id))
        }

        gtfTranscripts$from <- unlist(lapply(str_split(
            gtfTranscripts$new_transcript_id, "AS "),"[[",2))
        gtfTranscripts <- gtfTranscripts[order(gtfTranscripts$transcript_id,
                                               start(gtfTranscripts))]

        ## alter exons hitting the junctions so they all break at the same place
        # range is at the alt. points defined in eventCoords
        range <- junctionPairs
        start(range) <- min(start(junctionPairs))
        end(range) <- max(start(junctionPairs))

        ol.left <- as.data.frame(findOverlaps(range, gtfTranscripts))
        ol.left$from_id <- range$id[ol.left$queryHits]
        ol.left$to_id <- gtfTranscripts$from[ol.left$subjectHits]
        ol.left <- ol.left[ol.left$from_id == ol.left$to_id,]

        # fix the end of the left transcript exons
        exons.left <- gtfTranscripts[ol.left$subjectHits]

        keep <- which(start(exons.left) <
                          start(junctionPairs[ol.left$queryHits]))
        end(exons.left)[keep] <- start(junctionPairs[ol.left$queryHits])[keep]
        exons.left <- exons.left[keep]

        # now the right side
        range <- junctionPairs

        end(range) <- max(end(junctionPairs))
        start(range) <- min(end(junctionPairs))

        ol.right <- as.data.frame(findOverlaps(range, gtfTranscripts))
        ol.right$from_id <- range$id[ol.right$queryHits]
        ol.right$to_id <- gtfTranscripts$from[ol.right$subjectHits]
        ol.right <- ol.right[ol.right$from_id == ol.right$to_id,]

        # fix the start of the right exons
        exons.right <- gtfTranscripts[ol.right$subjectHits]

        keep <- which(end(exons.right) > end(junctionPairs[ol.right$queryHits]))
        start(exons.right)[keep] <- end(junctionPairs[ol.right$queryHits])[keep]
        exons.right <- exons.right[keep]

        m <- match(exons.left$new_transcript_id, exons.right$new_transcript_id)
        exons.left <- exons.left[which(!is.na(m))]
        exons.right <- exons.right[m[which(!is.na(m))]]

        exons.glued <- exons.left
        end(exons.glued) <- end(exons.right)

        # replacement exon pairs
        gtfTranscripts.replacement <- c(exons.left,exons.right)

        # remove replaced exons from gtf
        gtfTranscripts.altered <-
            gtfTranscripts[gtfTranscripts$new_transcript_id %in%
                               gtfTranscripts.replacement$new_transcript_id]


        ol <- as.data.frame(findOverlaps(exons.glued, gtfTranscripts.altered))
        ol$from_id <- exons.glued$new_transcript_id[ol$queryHits]
        ol$to_id <- gtfTranscripts.altered$new_transcript_id[ol$subjectHits]
        ol <- ol[ol$from_id == ol$to_id,]
        gtfTranscripts.altered <- gtfTranscripts.altered[-unique(ol$subjectHits)]

        # add together
        gtfTranscripts.altered <- c(gtfTranscripts.altered,
                                    gtfTranscripts.replacement)
        gtfTranscripts.altered <- gtfTranscripts.altered[order(
            gtfTranscripts.altered$new_transcript_id,
            start(gtfTranscripts.altered))]

        gtfTranscripts.altered$set <-
            range$set[match(gtfTranscripts.altered$from, range$id)]
        gtfTranscripts.altered$whippet_id <- junctionPairs$whippet_id[
            match(gtfTranscripts.altered$from, junctionPairs$id)]
        gtfTranscripts.altered$transcript_id <-
            paste0(gtfTranscripts.altered$transcript_id,
                   "+AS",type,gtfTranscripts.altered$set," ",
                   gtfTranscripts.altered$whippet_id)
        gtfTranscripts.altered$set <- paste0(type, "_",
                                             gtfTranscripts.altered$set)


    }else if(type %in% c("AF", "AL")){
        end(range)[which(range$search=="right")] <-
            start(range)[which(range$search=="right")]
        start(range)[which(range$search=="left")] <-
            end(range)[which(range$search=="left")]

        olFirstLast.left <- findOverlaps(range, exons, type="start")
        olFirstLast.right <- findOverlaps(range, exons, type="end")
        olFirstLast.left <-
            cbind(as.data.frame(olFirstLast.left),
                  transcript_id=exons$transcript_id[olFirstLast.left@to])
        olFirstLast.left <- olFirstLast.left[
            which(range$search[olFirstLast.left$queryHits] == "left"),]

        olFirstLast.right <-
            cbind(as.data.frame(olFirstLast.right),
                  transcript_id=exons$transcript_id[olFirstLast.right@to])
        olFirstLast.right <- olFirstLast.right[
            which(range$search[olFirstLast.right$queryHits] == "right"),]

        olFirstLast <- rbind(olFirstLast.left, olFirstLast.right)

        olFirstLast$search <- range$search[olFirstLast$queryHits]

        exonsFirstLast <- exons[olFirstLast$subjectHits]
        exonsFirstLast$set <- range$set[olFirstLast$queryHits]
        exonsFirstLast$search <- range$search[olFirstLast$queryHits]

        exonsFirstLast$junction_id <- range$id[olFirstLast$queryHits]
        newId.left <- paste0(seqnames(exonsFirstLast),":",
                             start(junctionPairs)[olFirstLast$queryHits],"-",
                             end(junctionPairs)[olFirstLast$queryHits],"+",
                             end(exonsFirstLast))
        newId.right <- paste0(seqnames(exonsFirstLast),":",
                              start(junctionPairs)[olFirstLast$queryHits],"-",
                              end(junctionPairs)[olFirstLast$queryHits],"+",
                              start(exonsFirstLast))
        exonsFirstLast$new_id <- NA
        exonsFirstLast$new_id[which(exonsFirstLast$search=="left")] <-
            newId.left[which(exonsFirstLast$search=="left")]
        exonsFirstLast$new_id[which(exonsFirstLast$search=="right")] <-
            newId.right[which(exonsFirstLast$search=="right")]

        m <- match(exonsFirstLast$junction_id, junctionPairs$id)
        junctionPairs <- junctionPairs[m]
        range <- junctionPairs
        range$id <- exonsFirstLast$new_id
        end(range)[which(range$search=="left")] <-
            start(range)[which(range$search=="left")]
        start(range)[which(range$search=="right")] <-
            end(range)[which(range$search=="right")]

        ol.junction <- findOverlaps(range, exons)
        ol.junction <- cbind(as.data.frame(ol.junction),
                             transcript_id=exons$transcript_id[ol.junction@to])

        ## table of transcripts overlapping the junction
        # tid: transcript id
        tidTable <- as.data.frame(table(ol.junction$queryHits,
                                        ol.junction$transcript_id))
        tidTable <- tidTable[tidTable$Freq > 0,]
        colnames(tidTable)[1:2] <- c("from_index","to_transcript_id")
        tids <- unique(tidTable$to_transcript_id)

        tidTable$junction_id <- range$id[tidTable$from_index]
        ## new transcript id --
        ## unique if different junctions are going to be used in same transcript base
        tidTable$new_transcript_id <- paste0(tidTable$to_transcript_id,"+AS ",
                                             tidTable$junction_id)
        ## all transcripts for structural altercations
        gtfTranscripts <- exons[exons$transcript_id %in% tids]
        mcols(gtfTranscripts) <-
            mcols(gtfTranscripts)[,c('gene_id','transcript_id',
                                     'transcript_type','exon_id',
                                     'exon_number')]
        m <- match(gtfTranscripts$transcript_id, tidTable$to_transcript_id)
        # add new transcript id
        gtfTranscripts$new_transcript_id <-
            paste0(gtfTranscripts$transcript_id,"+AS ",
                   range$id[tidTable$from_index[m]])
        gtfTranscripts$new_transcript_id_exnum <-
            paste0(gtfTranscripts$new_transcript_id,
                   "_",
                   as.numeric(gtfTranscripts$exon_number))

        # duplicate core transcripts if needed
        needsDuplicated <- which(!(tidTable$new_transcript_id %in%
                                       gtfTranscripts$new_transcript_id))
        if(length(needsDuplicated) > 0){
            gtfTranscripts.add <-
                gtfTranscripts[gtfTranscripts$transcript_id %in%
                                   tidTable$to_transcript_id[needsDuplicated]]
        }
        while(length(needsDuplicated) > 0){
            gtfTranscripts.add <- gtfTranscripts.add[
                gtfTranscripts.add$transcript_id %in%
                    tidTable$to_transcript_id[needsDuplicated]]
            m <- match(gtfTranscripts.add$transcript_id,
                       tidTable$to_transcript_id[needsDuplicated])
            gtfTranscripts.add$new_transcript_id <-
                paste0(gtfTranscripts.add$transcript_id,"+AS ",
                       tidTable$junction_id[needsDuplicated][m])
            gtfTranscripts <- c(gtfTranscripts, gtfTranscripts.add)
            needsDuplicated <- which(!(tidTable$new_transcript_id %in%
                                           gtfTranscripts$new_transcript_id))
        }

        gtfTranscripts$from <- unlist(lapply(str_split(
            gtfTranscripts$new_transcript_id, "AS "),"[[",2))
        gtfTranscripts <- gtfTranscripts[order(gtfTranscripts$transcript_id,
                                               start(gtfTranscripts))]

        gtfTranscripts <- gtfTranscripts[gtfTranscripts$transcript_id %in%
                                             exonsFirstLast$transcript_id]
        gtfTranscripts$new_transcript_id_exnum <-
            paste0(gtfTranscripts$new_transcript_id, "_",
                   as.numeric(gtfTranscripts$exon_number))

        range <- junctionPairs
        range$id <- exonsFirstLast$new_id

        ## find exons that use/overlap the junction - at the side where it's alternative
        end(range)[which(range$search=="left")] <-
            start(range)[which(range$search=="left")]
        start(range)[which(range$search=="right")] <-
            end(range)[which(range$search=="right")]

        ### Same used junction replacement
        ol.left <- as.data.frame(findOverlaps(range, gtfTranscripts))
        ol.left$from_id <- range$id[ol.left$queryHits]
        ol.left$to_id <- gtfTranscripts$from[ol.left$subjectHits]
        ol.left <- ol.left[ol.left$from_id == ol.left$to_id,]
        ol.left <- ol.left[which(range$search[ol.left$queryHits] == "left"),]

        # fix the end of the left transcript exons
        exons.left <- gtfTranscripts[ol.left$subjectHits]
        end(exons.left) <- end(range[ol.left$queryHits])

        ol.right <- as.data.frame(findOverlaps(range, gtfTranscripts))
        ol.right$from_id <- range$id[ol.right$queryHits]
        ol.right$to_id <- gtfTranscripts$from[ol.right$subjectHits]
        ol.right <- ol.right[ol.right$from_id == ol.right$to_id,]
        ol.right <-
            ol.right[which(range$search[ol.right$queryHits] == "right"),]

        # fix the end of the right transcript exons
        exons.right <- gtfTranscripts[ol.right$subjectHits]
        start(exons.right) <- start(range[ol.right$queryHits])

        junctionReplacementExons <- c(exons.left, exons.right)
        junctionReplacementExons$set <-
            range$set[match(junctionReplacementExons$from, range$id)]

        keep <- which(gtfTranscripts$new_transcript_id %in%
                          junctionReplacementExons$new_transcript_id)
        gtfTranscripts.altered <- gtfTranscripts[keep]
        gtfTranscripts.altered$set <-
            range$set[match(gtfTranscripts.altered$from, range$id)]

        ### First/last exon replacement

        m <- match(junctionReplacementExons$from, exonsFirstLast$new_id)
        replacementExonsFirstLast <- junctionReplacementExons
        ranges(replacementExonsFirstLast) <- ranges(exonsFirstLast[m])


        # remove anything after first/last
        if(type=="AF"){
            back <- 0
            n <- which(gtfTranscripts.altered$new_transcript_id_exnum %in%
                           junctionReplacementExons$new_transcript_id_exnum)
            ids <- gtfTranscripts.altered$new_transcript_id[n]
            exonNumbers <- as.numeric(gtfTranscripts.altered$exon_number[n])
            altTidExNum <- paste0(ids, "_", exonNumbers-back)
            m <- match(altTidExNum,
                       gtfTranscripts.altered$new_transcript_id_exnum)
            m <- m[!is.na(m)]
            while(length(m) > 0){
                gtfTranscripts.altered <- gtfTranscripts.altered[-m]
                back <- back + 1
                altTidExNum <- paste0(ids, "_", exonNumbers-back)
                m <- match(altTidExNum,
                           gtfTranscripts.altered$new_transcript_id_exnum)
                m <- m[!is.na(m)]
            }
        }
        if(type=="AL"){
            fwd <- 0
            n <- which(gtfTranscripts.altered$new_transcript_id_exnum %in%
                           junctionReplacementExons$new_transcript_id_exnum)
            ids <- gtfTranscripts.altered$new_transcript_id[n]
            exonNumbers <- as.numeric(gtfTranscripts.altered$exon_number[n])
            altTidExNum <- paste0(ids, "_", exonNumbers+fwd)
            m <- match(altTidExNum,
                       gtfTranscripts.altered$new_transcript_id_exnum)
            m <- m[!is.na(m)]
            while(length(m) > 0){
                gtfTranscripts.altered <- gtfTranscripts.altered[-m]
                fwd <- fwd + 1
                altTidExNum <- paste0(ids, "_", exonNumbers+fwd)
                m <- match(altTidExNum,
                           gtfTranscripts.altered$new_transcript_id_exnum)
                m <- m[!is.na(m)]
            }
        }

        # remove overlapping exons
        longRange <- replacementExonsFirstLast
        rangeDF <- data.frame(start_1 = start(replacementExonsFirstLast),
                              start_2 = start(junctionReplacementExons),
                              end_1 = end(replacementExonsFirstLast),
                              end_2 = end(junctionReplacementExons))
        start(longRange) <- apply(rangeDF[,1:2], 1, min)
        end(longRange) <- apply(rangeDF[,3:4], 1, max)

        ol <- as.data.frame(findOverlaps(longRange, gtfTranscripts.altered))
        ol$from_id <- longRange$new_transcript_id[ol$queryHits]
        ol$to_id <- gtfTranscripts.altered$new_transcript_id[ol$subjectHits]
        ol <- ol[which(ol$from_id == ol$to_id),]
        if(dim(ol)[1] > 0){
            gtfTranscripts.altered <-
                (gtfTranscripts.altered[-unique(ol$subjectHits)])
        }
        gtfTranscripts.altered <- c(gtfTranscripts.altered,
                                    junctionReplacementExons,
                                    replacementExonsFirstLast)

        #redo exon numbering
        gtfTranscripts.altered <- gtfTranscripts.altered[
            order(gtfTranscripts.altered$new_transcript_id,
                  start(gtfTranscripts.altered))]
        tab <- as.data.frame(table(gtfTranscripts.altered$new_transcript_id))
        tab$strand <- as.character(strand(gtfTranscripts.altered[
            match(tab$Var1,gtfTranscripts.altered$new_transcript_id)]))
        gtfTranscripts.altered$exon_number <-
            unlist(apply(tab, 1, function(x)
                if(x[3] == "-"){c(x[2]:1)}else{c(1:x[2])}))

        gtfTranscripts.altered <- gtfTranscripts.altered[
            order(gtfTranscripts.altered$new_transcript_id,
                  start(gtfTranscripts.altered))]

        gtfTranscripts.altered$set <- range$set[
            match(gtfTranscripts.altered$from, range$id)]
        mcols(gtfTranscripts.altered) <- mcols(gtfTranscripts.altered)[
            ,match(c('gene_id','transcript_id',
                     'transcript_type','exon_id',
                     'exon_number','from','set'),
                   colnames(mcols(gtfTranscripts.altered)))]
        colnames(mcols(gtfTranscripts.altered))[6] <- "new_event_id"
        gtfTranscripts.altered$whippet_id <- range$whippet_id[
            match(gtfTranscripts.altered$new_event_id, range$id)]
        gtfTranscripts.altered$transcript_id <- paste0(
            gtfTranscripts.altered$transcript_id,
            "+AS",type,gtfTranscripts.altered$set," ",
            gtfTranscripts.altered$whippet_id)
        gtfTranscripts.altered$set <- paste0(type, "_",
                                             gtfTranscripts.altered$set)

    }

    mcols(gtfTranscripts.altered) <-
        mcols(gtfTranscripts.altered)[,c('gene_id','transcript_id',
                                         'transcript_type','exon_id',
                                         'exon_number',
                                         'set','whippet_id')]
    gtfTranscripts.altered <- removeDuplicateTranscripts(gtfTranscripts.altered)

    return(gtfTranscripts.altered)
}
#' Remove transcript duplicates
#'
#' Removes Structural duplicates of transcripts in a GRanges object
#' Note that duplicates must have different transcript ids.
#' @param transcripts GRanges object with transcript structures in exon form
#' @return GRanges object with unique transcript structures in exon form
#' @export
#' @import GenomicRanges
#' @importFrom rtracklayer import
#' @family gtf manipulation
#' @author Beth Signal
#' @examples
#' gtf <- rtracklayer::import(system.file("extdata","example_gtf.gtf",
#' package = "GeneStructureTools"))
#' exons <- gtf[gtf$type=="exon"]
#' exons.altName <- exons
#' exons.altName$transcript_id <- paste(exons.altName$transcript_id, "duplicated", sep="_")
#' exons.duplicated <- c(exons, exons.altName)
#' length(exons.duplicated)
#' exons.deduplicated <- removeDuplicateTranscripts(exons.duplicated)
#' length(exons.deduplicated)
removeDuplicateTranscripts <- function(transcripts){
    transcriptDF <- as.data.frame(transcripts)

    transcriptDF$startend <- with(transcriptDF, paste0(start,"-",end))
    transcriptRangePaste <- aggregate(startend ~ transcript_id, transcriptDF,
                                      function(x) paste0(x, collapse="+"))

    keep <- transcriptRangePaste$transcript_id[
        which(!duplicated(transcriptRangePaste$startend))]
    transcriptsFiltered <- transcripts[transcripts$transcript_id %in% keep]
    return(transcriptsFiltered)
}
