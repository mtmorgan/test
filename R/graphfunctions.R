################################################################
# function:
# boundary takes two parameters:
#   graph is the original graph from which the subgraph will be created
#   subgraph either the subgraph or the nodes of the subgraph
# boundary returns a list of length equal to the number of nodes in the
#   subgraph. Each element is a list of the nodes in graph
#
# created by: Elizabeth Whalen
# last updated: Feb 15, 2003, RG
################################################################

boundary<-function(subgraph, graph)
{
  if ( !is(graph, "graph") )
    stop("The second parameter must be an object of type graph.")

  if( is(subgraph, "graph") )
      snodes <- nodes(subgraph)
  else if( is.character(subgraph) )
      snodes <- subgraph
  else
      stop("wrong type of first argument")

  if( any( !(snodes %in% nodes(graph)) ) )
      stop("some nodes are not in the graph")

  subE <- inEdges(graph)[snodes]

  lapply(subE, function(x) x[!(x %in% snodes)] )
}


##check to see if any edges are duplicated, as we often don't have
##good ways to deal with that
duplicatedEdges <- function(graph) {
    if( !is(graph, "graphNEL") )
        stop("only graphNEL supported for now")

    for(e in graph@edgeL)
        if( any(duplicated(e$edges)) )
            return(TRUE)
    return(FALSE)
}

ugraphOld <- function()
{
    .Defunct("ugraph")
}

setMethod("ugraph", "graph",
          function(graph) {
              if (!isDirected(graph))
                return(graph)
              eMat <- edgeMatrix(graph)
              ## add recip edges
              eMat <- cbind(eMat, eMat[c(2, 1), ])
              ## put into graphNEL edgeL format
              eL <- lapply(split(as.vector(eMat[2, ]), as.vector(eMat[1, ])),
                           function(x) list(edges=unique(x)))
              theNodes <- nodes(graph)
              ## some nodes may be missing
              names(eL) <- theNodes[as.integer(names(eL))]
              ## add empty edge list for nodes with no edges
              noEdgeNodes <- theNodes[!(theNodes %in% names(eL))]
              noEdges <- lapply(noEdgeNodes,
                                function(x) list(edges=numeric(0)))
              names(noEdges) <- noEdgeNodes
              ## FIXME: should we skip standard initialize for speed?
              ## need to copy over at least the nodeData...
              new("graphNEL", nodes=theNodes, edgeL=c(eL, noEdges),
                  edgemode="undirected")
          })


 setMethod("edgeMatrix", c("graphNEL", "ANY"),
           function(object, duplicates=FALSE) {
                   ## Return a 2 row numeric matrix (from, to, weight)
               ed <- object@edgeL
               ##reorder to the same order as nodes
               ed <- ed[nodes(object)]
               nN <- length(ed)
               eds<-lapply(ed, function(x) x$edges)
               elem <- listLen(eds)
               from <- rep(1:nN, elem)
               to <- unlist(eds, use.names=FALSE)
               ans <- rbind(from, to)
               ##we duplicate edges in undirected graphNEL
               ##so here we remove them
               if( edgemode(object) == "undirected"  && !duplicates) {
                   swap <- from>to
                   ans[1,swap]<-to[swap]
                   ans[2,swap]<-from[swap]
                   t1 <- paste(ans[1,], ans[2,], sep="+")
                   ans <- ans[ ,!duplicated(t1), drop=FALSE]
               }
               ans
           })


  setMethod("edgeMatrix", c("clusterGraph", "ANY"),
            function(object, duplicates) {
                cls<-object@clusters
                nd <- nodes(object)
                ans <- numeric(0)
                for(cl in cls) {
                    idx <- match(cl, nd)
                    nn <- length(idx)
                    v1 <- rep(idx[-nn], (nn-1):1)
                    v2 <- numeric(0)
                    for( i in 2:nn)
                        v2 <- c(v2, i:nn)
                    v2 <- idx[v2]
                    ta <- rbind(v1, v2)
                    if( is.matrix(ans) )
                        ans <- cbind(ans, rbind(v1, v2))
                    else
                        ans <- rbind(v1, v2)
                }
                dimnames(ans) <- list(c("from", "to"), NULL)
                ans
            })

  setMethod("edgeMatrix", c("distGraph", "ANY"),
            function(object, duplicates) {
               ## Return a 2 row numeric matrix (from, to, weight)
               ed <- edges(object)
               ##reorder to the same order as nodes
               NODES <- nodes(object)
               ed <- ed[NODES]
               nN <- length(ed)
               elem <- listLen(ed)
               from <- rep(1:nN, elem)
               to <- match(unlist(ed), NODES)
               ans <- rbind(from, to)
               ##we duplicate edges in undirected graphNEL
               ##so here we remove them
               ##FIXME: see graphNEL for a speedup of this part
               if( edgemode(object) == "undirected"  && !duplicates) {
                   t1 <- apply(ans, 2, function(x) {paste(sort(x),
                                                           collapse="+")})
                   ans <- ans[ ,!duplicated(t1), drop=FALSE]
               }
               ans
           })


setMethod("edgeMatrix", "graphAM",
          function(object, duplicates=FALSE) {
              to <- apply(object@adjMat, 1, function(x) which(x != 0))
              from <- rep(1:numNodes(object), listLen(to))
              to <- unlist(to, use.names=FALSE)
              ans <- rbind(from=from, to=to)
              ## we duplicate edges in undirected graphs
              ## so here we remove them
              if (!isDirected(object)  && !duplicates) {
                  swap <- from > to
                  ans[1, swap] <- to[swap]
                  ans[2, swap] <- from[swap]
                  t1 <- paste(ans[1, ], ans[2, ], sep="+")
                  ans <- ans[ , !duplicated(t1), drop=FALSE]
              }
              ans
          })


##it seems to me that we might want the edge weights for
##a given edgeMatrix and that that would be much better done
##in the edgeMatrix function
##we are presuming that eM has integer offsets in it
##eWV <- function(g, eM, sep=ifelse(edgemode(g)=="directed", "->",
##                       "--"))
##{
##    unE <- unique(eM[1,])
##    edL <- g@edgeL
##    eE <- lapply(edL, function(x) x$edges)
##    eW <- lapply(edL, function(x) {
##        ans = x$weights
##        ed = length(x$edges)
##        if( is.null(ans) && ed > 0 )
##            ans = rep(1, ed)
##        ans})
##
##    nr <- listLen(eE)
##    ##now we can subset -
##    eMn <- paste(rep((1:length(nr))[unE],nr[unE]), unlist(eE[unE]), sep=sep)
##    eWv <- unlist(eW[unE])
##    dE <- paste(eM[1,], eM[2,], sep=sep)
##    wh<-match(dE, eMn)
##    if(any(is.na(wh)) )
##        stop("edges in supplied edgematrix not found")
##    ans <-eWv[wh]
##    names(ans) <- eMn[wh]
##    ans
##}

#eWV <- function(g, eM, sep=ifelse(edgemode(g)=="directed", "->",
#                       "--"))
#{
#    edL <- g@edgeL
#    ##fix up the edgeweights so we really find them
#    eW <- lapply(edL, function(x) {
#        ans = x$weights
#        ed = length(x$edges)
#        if( is.null(ans) && ed > 0 )
#            ans = rep(1, ed)
#        if( length(ans) > 0 )
#            names(ans) = x$edges
#        ans})
#
#    a1 <- apply(eM, 2,
#                function(x) eW[[x[1]]][as.character(x[2])])
#    names(a1) <- paste(eM[1,], eM[2,], sep=sep)
#    return(a1)
#}


eWV <- function (g, eM, sep = ifelse(edgemode(g) == "directed", "->",
    "--"), useNNames = FALSE)
{
# returns vector of weights.  default has names equal to node
# indices, but useNNames can be set to put node names as names
# of corresponding weights
#
    n <- nodes(g)
    from <- n[eM["from", ]]
    to <- n[eM["to", ]]
    eW <- tryCatch(edgeData(g, from=from, to=to, attr="weight"),
                   error=function(e) {
                       edgeDataDefaults(g, "weight") <- 1:1
                       edgeData(g, from=from, to=to, attr="weight")
                   })
    eW <- unlist(eW)
    if (!useNNames)
      nms <- paste(eM["from", ], eM["to", ], sep=sep)
    else
      nms <- paste(from, to, sep=sep)
    names(eW) <- nms
    eW
}


pathWeights <- function (g, p, eM = NULL)
{
#
# a path is a vector of names of adjacent nodes
# we form the vector of steps through the path
# (pairs of adjacent nodes) and attach the weights
# for each step.  no checking is done to verify
# that the path p exists in g
#
    if (length(p) < 2)
        stop("a path must have length > 1")
    if (is.null(eM))
        eM <- edgeMatrix(g)
    wv <- eWV(g, eM, useNNames = TRUE)
    sep <- ifelse(edgemode(g) == "undirected", "--", "->")
    pcomps <- cbind(p[-length(p)], p[-1])
    if (edgemode(g) == "undirected") pcomps <- rbind(pcomps, pcomps[,c(2,1)]) # don't know node order in wv labels
    inds <- apply(pcomps, 1, function(x) paste(x[1], x[2], sep = sep))
    tmp <- wv[inds]
    tmp[!is.na(tmp)]
}
