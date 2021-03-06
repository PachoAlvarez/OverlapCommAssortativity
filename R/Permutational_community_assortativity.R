# Load required libraries
library(igraph)
library(asnipe)
library(assortnet)
library(igraph)
library(igraphdata)
library(linkcomm)
library(reshape2)
#source("R/non_nested_height2.R")
#source("R/adj_to_edgelist.R")
#source("R/assortmentdiscreteLinkCom.R")


#### Permutation loop for Pij ####
networkPerm <- function(data) {
  #Read igraph object and convert it into an adjacency matrix
  a <- as.matrix(as_adj(data, type = "lower", attr = "weight"))
  b <- a
  
  #Permute the edges inside the adjacency network - lower diag
  
  b[lower.tri(b)] <- sample(b[lower.tri(b)])
  
  #b <- makeSymm(b)
  #b
  d <- data.frame(b, stringsAsFactors = F, check.names = F)
  
  ee <- adj_to_edgelist(d) #change column names
  ee <- ee[ee$V3 != 0, ]
  
  if(length(unique(c(ee$V1, ee$V2))) == ncol(a)) {
    return(ee)
  } else {
    return(networkPerm(data))
  }
}
#Function to calculate r_c, with default number of permutations = 100, and default option to plot result. Plot will be saved as pdf file in R output folder as "rc_result.pdf".

calc_Pmatrix <- function(data, n.permutations=100, algorithm = "linkcomm",
                         permutations = TRUE, boot.data = NULL, gbi.format = TRUE){
  
    if(permutations == FALSE & is.null(boot.data)) {
        stop("To run the bootstrap algorithm, remember to fill the 'boot.data' parameter with the original observation matrix from which the network comes")
    }
  # Create space to store results from permutations
  network.community <- array(0, dim = c(length(V(data)),length(V(data))),
                             dimnames = list(names(V(data)), names(V(data))))
  
  network.present <- array(0, dim = c(length(V(data)),length(V(data))),
                           dimnames = list(names(V(data)), names(V(data))))
  
  community.observed <- array(0, dim = c(length(V(data)),length(V(data))),
                              dimnames = list(names(V(data)), names(V(data))))
  
  # Calculate community membership of the observed network
  community.observed <- getNetworkCommunities(data, algorithm)
  
  #community.observed <- fastgreedy.community(graph.adjacency(network,mode="undirected",weighted=TRUE))
  
  # 3. Main bootstrapping method: i) Bootstrap the observed data, ii) recalculate the network, 
  #    iii) recalculate community membership, iv) check if both individuals are observed
  
  for (i in 1:n.permutations) {
    # This step bootrstraps the sampling periods
    if(permutations == FALSE)   {
        if(permutations == FALSE)   {
            if(gbi.format) {
                gbi.boot <- boot.data[sample(1:nrow(boot.data),nrow(boot.data),replace=TRUE),]
                network.perm <- get_network(gbi.boot,data_format="GBI", association_index="SRI")
                network.perm <- adj_to_edgelist(network.perm)
                network.perm <- network.perm[network.perm$V3 != 0, ]
            } else {
                network.perm <- boot.data[sample(1:nrow(boot.data),nrow(boot.data),replace=TRUE),]
                network.perm$V3 <- 1
                names(network.perm) <- c("V1", "V2", "V3")
                network.perm <- aggregate(V3 ~ V1 + V2, data = network.perm, FUN = sum)
                
            }
        }
    } else {
        network.perm <- networkPerm(data)
    }
    
    # This step calculates the community membership from the bootstrapped network
    community.perm <- getNetworkCommunities(network.perm, algorithm)
    
    # This step adds 1 to any dyads in the same community
    #if(length(community.perm$clusters) == 1) { #If only one community exist, we consider that the nodes don't group in communities
     # network.community <- network.community + 0 
    #} else {
    
    # in particular, the following lines allow us to reorder the new network to be comparable to the original
      g <- graph.data.frame(as.matrix(community.perm), directed = F)
      V(g)$type <- V(g)$name %in% as.matrix(community.perm)[,1]
      g <- bipartite.projection(g)$proj2
      g <- as.matrix(as_adj(g))
      
      #network.community <- network.community + outer(community.boot$membership, community.boot$membership,"==")
      m_comb <- do.call(rbind, lapply(list(g, network.community), melt))
    
      # This step adds 1 to any dyads that are both present (in this case if they have at least 1 edge)
      
      if(i != 1) {
        net.pres <- acast(m_comb, m_comb$Var1~m_comb$Var2, sum)[rownames(network.community), colnames(network.community)] - network.community  
      }
      
      network.community <- acast(m_comb, m_comb$Var1~m_comb$Var2, sum)[rownames(network.community), colnames(network.community)]
    #}
    
      if(i == 1) {
        net.pres <- network.community
      } 
      
    network.present <- network.present + outer(rowSums(net.pres) > 0, rowSums(net.pres) > 0, "*")
    #network.present <- network.present + 1
    #network.present <- network.present + outer((rowSums(network.boot)>0),(rowSums(network.boot)>0),"*")
    print(i)
  }
  # End bootstrap
  
  # Calculate proportion of times observed in the same community
  P <- network.community/network.present
  P[!is.finite(P)] <- 0
  
  # Calculate assortment from known community membership
  Pmatrix_comm <- list(Pij = P, nodeclusters = community.observed)
  return(Pmatrix_comm)
}
