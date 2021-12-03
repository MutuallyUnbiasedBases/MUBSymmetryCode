using LinearAlgebra, RowEchelon, GenericLinearAlgebra, AbstractAlgebra, SymEngine, Combinatorics, Printf

setprecision(128)
include("ConstructReprSet.jl")
include("DetValMon.jl")
include("HelperFunctions.jl")

#WRITES SEPARATE BLOCKS FOR I=1-part of t-th level of MOMENT MATRIX, USING THE SYMMETRY REDUCTION!
function MUBWriteSDPASk(d,k,t,option=0)
    manual_epsilon = 0.0000000000000001  #if smaller than this epsilon, consider coefficient to be zero.
    smallbigfloat = BigFloat("0.0000000000000000000000000000001")
    MonomialValuesDictionary = Dict()
    VarSet = Set{Tuple{Vector{Int},Vector{Int}}}();
    println("##### Generating Representative Set...")

    if (option ==1)
        println("#### CASE: d,k,t = ", d, " ", k, " ", t , "+1/2, i1-part.")
        @time ReprSet, BlockSizes = generateRepresentativeSetPlusHalf(k,t)
        ReprColSet= generateRepresentativeColumnSetPlusHalf(k,t)
        #println("##### Computing Inner Products in Base Block Diagonalization...")
        #@time InnerProducts = ReduceInnerProducts(ReprSet, ReprColSet, 2,true);
        Ivec = ones(Int,2*t+1)

    else  #generate representative set for t-th level
        println("#### CASE: d,k,t = ", d, " ", k, " ", t)
        @time ReprSet, FirstBlockSizes = generateRepresentativeSet(k,t)
        @time ReprColSet= generateRepresentativeColumnSet(k,t)
        #println("##### Computing Inner Products in Base Block Diagonalization...")
        #@time InnerProducts = ReduceInnerProducts(ReprSet, ReprColSet, 1,true);
        Ivec = ones(Int,2*t)
    end

    println("##### Computing Final Block Diagonalization...")
    ReducedBlocks=[];
    BlockSizes=[];
    MonomialValuesDictionary = Dict()

    aantalblocksK = size(ReprSet,1)
    @time for i=1: aantalblocksK
        #BlockForK = InnerProducts[i]
        blockSize=size(ReprSet[i],1)
        println("block of size ", blockSize )
        push!(BlockSizes,blockSize)
        Block = Array{Dict{Tuple{Vector{Int64}, Vector{Int64}}, BigFloat}}(undef,blockSize,blockSize)
        for rowidx = 1:blockSize
            print("row ",rowidx, " \r")
            reprRowElement = ReprSet[i][rowidx]
            for colidx = 1:blockSize
	            reprColElement = ReprColSet[i][colidx]
                if (colidx >=rowidx)
                    #compute the inner product.
                    Block[rowidx,colidx]=Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}();
                    if (option == 1 )
                        InnerProduct = ReduceInnerProduct(reprRowElement,reprColElement,1)
                    else
                        InnerProduct = ReduceInnerProduct(reprRowElement,reprColElement,0)
                    end
                    for wordssignK in InnerProduct
                        tempmonoomK=wordssignK[1];

                        if !haskey(MonomialValuesDictionary,tempmonoomK)
                            DictValueMon = Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
                            VarSet,DictValueMon = DetValMon(VarSet,DictValueMon,d,deepcopy(Ivec),deepcopy(tempmonoomK),1)
                            MonomialValuesDictionary[tempmonoomK] = DictValueMon
                        end
                        ##add dictionaries
                        TempValueDictionary =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
                        [TempValueDictionary[x]=MonomialValuesDictionary[tempmonoomK][x]*wordssignK[2]  for x in keys(MonomialValuesDictionary[tempmonoomK])]
                        Block[rowidx,colidx] = merge(+,deepcopy(Block[rowidx,colidx]),deepcopy(TempValueDictionary))
                    end                   
                end
            end
        end
        ReducedBlocks = push!(ReducedBlocks,Block);
 #	    empty!(MonomialValuesDictionary);
    end

    VarSetOrdered=[]
    [push!(VarSetOrdered,x) for x in VarSet];

    nVars= length(VarSet)
    println("##### List of variables: ", VarSetOrdered)
    
    println("blocksizes = $BlockSizes")
    println("Sum blocksizes = ", sum(BlockSizes));

    nBlocks = 2*nVars + size(ReducedBlocks,1)

    println("##### Writing the SDP...")
    ###start writing SDP file in SDPA-format (.dat-s)
    if (option ==1)  ## t+1/2th level
        io = open(string("sdp_d$d","_k$k","_t$t","_plushalf_i1part.dat-s"), "w")
        iovars = open(string("variables_d$d","_k$k","_t$t","_plushalf_i1part.txt"), "w")
    else
        io = open(string("sdp_d$d","_k$k","_t$t","_i1part.dat-s"), "w")
        iovars = open(string("variables_d$d","_k$k","_t$t","_i1part.txt"), "w")
    end

    for i=1:nVars 
        println(iovars, i, " ",VarSetOrdered[i])
    end
    close(iovars)

    #print the number of variables, the number of blocks and the block sizes.
    println(io, nVars)
    println(io, nBlocks)
    for i=1:(nVars)
        print(io, "1 1 ")
    end
    for i=1:size(ReducedBlocks,1)
        print(io, size(ReducedBlocks[i],1)," ")
    end
    print(io,"\n")
    #now print the objective vector
    for i=1:nVars
        print(io, "-1 ")
    end
    print(io,"\n");
    #now print the constraints -1 <= yi <= 1
    for i=1:nVars
        blocknumber = 2*(i-1)+1;
        #constraint yi - (-1) >=0, i.e. yi >=-1
        println(io,i," ",blocknumber," ",1, " ",1 , " ",1 )
        println(io,0," ",blocknumber," ",1, " ",1 , " ",-1 )
        #constraint -yi -(-1) >=0, i.e. yi <=1
        println(io,i," ",blocknumber+1," ",1, " ",1 , " ",-1 )
        println(io,0," ",blocknumber+1," ",1, " ",1 , " ",-1 )
    end

    #now print the constraint that the moment matrix must be p.s.d. (note, the block number is nBlocks)
    @time for blockindex = 1: size(ReducedBlocks,1)
        ArrayBlock = ReducedBlocks[blockindex]
        blocknumber = blockindex + 2*nVars 
        reducedBlockSize = size(ArrayBlock,1)

        for i=1:reducedBlockSize
            for j=i:reducedBlockSize
                coefficient = get(ReducedBlocks[blockindex][i,j],([-1],[-1]),0);
                coefficient *= -1 #constant coefficient should be multiplied with -1,  because the matrix is in the form F_1y_1 +..+F_my_m -C
                if abs(coefficient)> manual_epsilon
                        println(io,0," ",blocknumber," ",i, " ",j , " ", coefficient)
                end
                for varnumber =1:nVars
                    coefficient = get(ReducedBlocks[blockindex][i,j],VarSetOrdered[varnumber],0);  
                    if abs(coefficient)> manual_epsilon
                        println(io,varnumber," ",blocknumber," ",i, " ",j , " ",  coefficient)
                    end
                end
            end
        end
    end
    close(io)
    println("##### Writing finished.")
end


#WRITES SEPARATE BLOCKS FOR FULL t-th level of MOMENT MATRIX, USING THE FULL SYMMETRY REDUCTION OF THE WREATH PRODUCT GROUP S_d wr S_k
function MUBWriteSDPA(d,k,t, option=0)
    manual_epsilon = 0.0000000000000001  #if smaller than this epsilon, consider coefficient to be zero.
    smallbigfloat = BigFloat("0.0000000000000000000000000000001")


    if (option ==1)
        println("#### FULL SYMMETRY, CASE: d,k,t = ", d, " ", k, " ", t , "+1/2.")
        println("##### Generating SetPartitions, Compositions, (Multi)Partitions and Tableaux...")
        @time BlocksElement = GeneratePartitionsTableauxFullPlusHalf(d,k,t)

    else  #generate representative set for t-th level
        println("#### FULL SYMMETRY, CASE: d,k,t = ", d, " ", k, " ", t)
        println("##### Generating SetPartitions, Compositions, (Multi)Partitions and Tableaux...")
        @time BlocksElement = GeneratePartitionsTableauxFull(d,k,t)
    end


    println("##### Computing Block Diagonalization...")
    ReducedBlocks=[];
    BlockSizes=[];
    MonomialValuesDictionary = Dict()
    VarSet = Set{Tuple{Vector{Int},Vector{Int}}}();

    blockindex=0;
    numzerorows=0;
    time = @elapsed for (MultiPartition, CorrespondingRows) in BlocksElement
        blockindex+=1;
        ReprSetArray=[]
        ReprColSetArray=[]
        blockSize = size(CorrespondingRows,1)
        println("Block of size ",blockSize)
        push!(BlockSizes, blockSize)
        println("Generating representative set for this block... ")
        if option==1 #t+1/2-th level
            for indexobject in CorrespondingRows
                push!(ReprSetArray,RepresentativeFullElementPlusHalf(indexobject))
                push!(ReprColSetArray,RepresentativeColumnElementPlusHalf(indexobject))
            end
        else #t-th level
            for indexobject in CorrespondingRows
                push!(ReprSetArray,RepresentativeFullElement(indexobject))
                push!(ReprColSetArray,RepresentativeColumnElement(indexobject))
            end
        end
        # if blockindex == 3
        #     println("Representative set= ", ReprSetArray)
        # end
        Block = Array{Dict{Tuple{Vector{Int64}, Vector{Int64}}, BigFloat}}(undef,blockSize,blockSize)
        println("Computing inner products for this block... ")
        for rowindex =1:blockSize
            print("rij ",rowindex,"     \r")
            for colindex=rowindex:blockSize
                #compute the inner product.

                TotalInnerProducts = ReduceInnerProductUsingImub(ReprSetArray[rowindex], ReprColSetArray[colindex])

                Block[rowindex,colindex]=Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}();
                for (monomialpair,value) in TotalInnerProducts
                    tempmonoomd=monomialpair[1]
                    tempmonoomK=monomialpair[2]
    
                    if !haskey(MonomialValuesDictionary,monomialpair)
                        DictValueMon = Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
                        VarSet,DictValueMon = DetValMon(VarSet,DictValueMon,d,deepcopy(tempmonoomd),deepcopy(tempmonoomK),1)
                        MonomialValuesDictionary[monomialpair] = DictValueMon
                    end
                    ##add dictionaries
                    TempValueDictionary =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
                    [TempValueDictionary[x]=MonomialValuesDictionary[monomialpair][x]*value  for x in keys(MonomialValuesDictionary[monomialpair])]
                    Block[rowindex,colindex] = merge(+,deepcopy(Block[rowindex,colindex]),deepcopy(TempValueDictionary))
                end
                # if rowindex == colindex && size(free_symbols(Block[rowindex,colindex]),1)==0 && float(Block[rowindex,colindex]) < manual_epsilon
                #     println("diag entry = ", Block[rowindex,colindex])
                #     numzerorows+=1;
                #     break
                # end
            end
        end
        ReducedBlocks = push!(ReducedBlocks,Block);
    end


    VarSetOrdered=[]
    [push!(VarSetOrdered,x) for x in VarSet];


    println("Checking for additional constraints...")
    ##Now checking MUB-constraints 
    ##for (d,k,t)=(7,6,4): normal inner products 150 sec (using the new inner product version exploiting tracial property/optimizations) 
    ListMissing =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}[]
    time+= @elapsed if option==1   ## if plushalf 
        println("Checking Projector and Orthogonality constraints...")
        @time append!(ListMissing, CheckImubProjectorOrthogonality(d,k,t,1)) 
        println("Checking POVM constraints...")
        @time append!(ListMissing, CheckImubPOVMSimple(d,k,t,1))
        println("Checking MUB constraints...")
        @time append!(ListMissing, CheckImubMUBSimple(d,k,t,1))  
    else 
        println("Checking Projector and Orthogonality constraints...")
        @time append!(ListMissing, CheckImubProjectorOrthogonality(d,k,t)) 
        println("Checking POVM constraints...")
        @time append!(ListMissing, CheckImubPOVMSimple(d,k,t))
        println("Checking MUB constraints...")
        @time append!(ListMissing, CheckImubMUBSimple(d,k,t))  
    end
    println("Checking Commutator Constraints...")
    time+= @elapsed if option==1   ## if plushalf 
        if 2*t-8 >0 
            append!(ListMissing,CheckImubCommutators(3,3,d,k,2*t-8))
        end 
        if 2*t-7 >0 
            append!(ListMissing,CheckImubCommutators(3,2,d,k,2*t-7))
        end 
        if 2*t-6 >0
            append!(ListMissing,CheckImubCommutators(2,2,d,k,2*t-6))
        end 
    else
        if 2*t-9 >0 
            append!(ListMissing,CheckImubCommutators(3,3,d,k,2*t-9))
        end 
        if 2*t-8 >0 
            append!(ListMissing,CheckImubCommutators(3,2,d,k,2*t-8))
        end 
        if 2*t-7 >0
            append!(ListMissing,CheckImubCommutators(2,2,d,k,2*t-7))
        end 
    end

    nVars= length(VarSet)
    println("##### List of variables: ", VarSetOrdered)
    newConstraints = RemoveLinearDependentConstraints(ListMissing, VarSetOrdered)
    numberOfAdditionalConstraints = size(newConstraints,1)
    println("##### New constraints returns ", numberOfAdditionalConstraints," constraints:")
    println(newConstraints)
    
    println("blocksizes = $BlockSizes")
    println("Sum blocksizes = ", sum(BlockSizes));

    nBlocks = 2*nVars + size(ReducedBlocks,1) +2*numberOfAdditionalConstraints;

    println("##### Writing the SDP...")
    ###start writing SDP file in SDPA-format (.dat-s)
    if (option ==1)  ## t+1/2th level
        io = open(string("sdp_d$d","_k$k","_t$t","_plushalf.dat-s"), "w")
        iovars = open(string("variables_d$d","_k$k","_t$t","_plushalf.txt"), "w")
        ioExtraConstraints = open(string("extraConstraints_d$d","_k$k","_t$t","_plushalf.txt"), "w")
        ioTable = open(string("table_d$d","_k$k","_t$t","_plushalf.txt"), "w")
    else
        io = open(string("sdp_d$d","_k$k","_t$t",".dat-s"), "w")
        iovars = open(string("variables_d$d","_k$k","_t$t",".txt"), "w")
        ioExtraConstraints = open(string("extraConstraints_d$d","_k$k","_t$t",".txt"), "w")
        ioTable = open(string("table_d$d","_k$k","_t$t",".txt"), "w")
    end

    for i=1:nVars 
        println(iovars, i, " ",VarSetOrdered[i])
    end
    close(iovars)

    for i=1:numberOfAdditionalConstraints 
        println(ioExtraConstraints, i, " ",newConstraints[i])
    end
    close(ioExtraConstraints)

    #print the number of variables, the number of blocks and the block sizes.
    println(io, nVars)
    println(io, nBlocks)
    for i=1:(nVars+numberOfAdditionalConstraints)
        print(io, "1 1 ")
    end
    for i=1:size(ReducedBlocks,1)
        print(io, size(ReducedBlocks[i],1)," ")
    end
    print(io,"\n")
    #now print the objective vector
    for i=1:nVars
        print(io, "-1 ")
    end
    print(io,"\n");
    #now print the constraints -1 <= yi <= 1
    for i=1:nVars
        blocknumber = 2*(i-1)+1;
        #constraint yi - (-1) >=0, i.e. yi >=-1
        println(io,i," ",blocknumber," ",1, " ",1 , " ",1 )
        println(io,0," ",blocknumber," ",1, " ",1 , " ",-1 )
        #constraint -yi -(-1) >=0, i.e. yi <=1
        println(io,i," ",blocknumber+1," ",1, " ",1 , " ",-1 )
        println(io,0," ",blocknumber+1," ",1, " ",1 , " ",-1 )
    end

    #now print the additional linear constraints 
    for i=1:numberOfAdditionalConstraints
        constraint = newConstraints[i]
        blocknumber = 2*nVars+2*(i-1)+1
        coefficientZero = get(constraint,([-1],[-1]),0);
        ## write constraint that linearexpression >=0 
        println(io,0," ",blocknumber," ",1, " ",1 , " ",  -1*coefficientZero)
        for varnumber =1:nVars
            coefficient = get(constraint,VarSetOrdered[varnumber],0);  
            if abs(coefficient)> manual_epsilon
                println(io,varnumber," ",blocknumber," ",1, " ",1 , " ",  coefficient)
            end
        end
        ## now print constraint that -linearexpression >=0
        println(io,0," ",blocknumber+1," ",1, " ",1 , " ",  1*coefficientZero)
        for varnumber =1:nVars
            coefficient = get(constraint,VarSetOrdered[varnumber],0);  
            if abs(coefficient)> manual_epsilon
                println(io,varnumber," ",blocknumber+1," ",1, " ",1 , " ",  -1*coefficient)
            end
        end
    end

    #now print the constraint that the moment matrix must be p.s.d. (note, the block number is nBlocks)
    time+= @elapsed for blockindex = 1: size(ReducedBlocks,1)
        ArrayBlock = ReducedBlocks[blockindex]
        blocknumber = blockindex + 2*nVars +2*numberOfAdditionalConstraints
        reducedBlockSize = size(ArrayBlock,1)

        for i=1:reducedBlockSize
            for j=i:reducedBlockSize
                coefficient = get(ReducedBlocks[blockindex][i,j],([-1],[-1]),0);
                coefficient *= -1 #constant coefficient should be multiplied with -1,  because the matrix is in the form F_1y_1 +..+F_my_m -C
                if abs(coefficient)> manual_epsilon
                        println(io,0," ",blocknumber," ",i, " ",j , " ", coefficient)
                end
                for varnumber =1:nVars
                    coefficient = get(ReducedBlocks[blockindex][i,j],VarSetOrdered[varnumber],0);  
                    if abs(coefficient)> manual_epsilon
                        println(io,varnumber," ",blocknumber," ",i, " ",j , " ",  coefficient)
                    end
                end
            end
        end
    end
    close(io)


    #generate nonreduced version
    if (option ==1)
        BlocksElement = GeneratePartitionsTableauxFullPlusHalf(d,k,t,0)
    else  #generate representative set for t-th level
        BlocksElement = GeneratePartitionsTableauxFull(d,k,t,0)
    end
    BlockSizesNonReduced=[size(x,1) for (MultiPartition, x) in BlocksElement];

    if (option==1)
        println(ioTable, "time ", time  )
        println(ioTable, "d &  k &  t.5 & (dk)^t &  variables  & additional constraints  & BlockSizesNonReduced (sum & max) &  BlockSizes (sum & max) & result ")
        println(ioTable, d, " & ", k, " & ", t , ".5 & " , (d*k)^t, " & ", nVars, " & ", numberOfAdditionalConstraints, " & " ,sum(BlockSizesNonReduced)," & ",maximum(BlockSizesNonReduced) ," & " ,sum(BlockSizes)," & ",maximum(BlockSizes) ," &  \\\\")
    else       
        println(ioTable, "time ", time  )
        println(ioTable, "d &  k &  t & (dk)^t &  variables & additional constraints & (sum,max) BlockSizesNonReduced & (sum,max) BlockSizes & result ")
        println(ioTable, d, " & ", k, " & ", t , " & " , (d*k)^t, " & ", nVars, " & ", numberOfAdditionalConstraints, " & " ,sum(BlockSizesNonReduced)," & ",maximum(BlockSizesNonReduced) ," & " ,sum(BlockSizes)," & ",maximum(BlockSizes) ," &  \\\\")
    end    
        
    close(ioTable)

    println("##### Writing finished.")
end

#check projector constraint on homogeneous polynomials of degree 2t-2
#option 1 is level +half, so check for polynomials of degree 2t-1 
function CheckImubProjectorOrthogonality(d,k,t,option=0)
    ListOfReducedMonomials= ReducedMonomials(d,k,2*t-2+option)
    VarSet = Set{Tuple{Vector{Int},Vector{Int}}}()
    ListMissing =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}[]
    for monomialpair in ListOfReducedMonomials 
        Ivec=monomialpair[1]; 
        Kvec=monomialpair[2];
        for j=1:maximum(Kvec)+1
            for i=1:maximum(Ivec)+1
                tempIvec = push!(deepcopy(Ivec), i-1)
                tempKvec = push!(deepcopy(Kvec), j-1)
                tempIvec2 = push!(deepcopy(Ivec), i-1,i-1)
                tempKvec2 = push!(deepcopy(Kvec), j-1,j-1)
                VarSet, Dict1 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec,tempKvec,1)
                VarSet, Dict2 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec2,tempKvec2,-1)
                testValue = merge(+,Dict1,Dict2)
            
                if !checkValue(testValue)
                    push!(ListMissing, testValue)
                end
                for i2=1:minimum([d,maximum(Ivec)+2])
                    if i != i2 
                        tempIvec3 = push!(deepcopy(Ivec), i-1, i2-1)
                        tempKvec3 = push!(deepcopy(Kvec), j-1, j-1)
                        VarSet, Dict3 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec3,tempKvec3,1)
                        if !checkValue(Dict3)
                            push!(ListMissing, Dict3)
                        end
                    end
                end
            end
        end
    end
    return ListMissing 
end 


#check MUB-constraint on homogeneous polynomials of degree 2t-3
#option 1 is level +half, so check for polynomials of degree 2t-2 
function CheckImubMUBSimple(d,k,t,option=0)
    ListOfReducedMonomials= ReducedMonomials(d,k,2*t-3+option,true)
    VarSet = Set{Tuple{Vector{Int},Vector{Int}}}()
    ListMissing =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}[]
    for monomialpair in ListOfReducedMonomials 
        Ivec=monomialpair[1]; 
        Kvec=monomialpair[2];
        for j=1:k 
            for i=1:d
                tempIvec = push!(deepcopy(Ivec), i-1)
                tempKvec = push!(deepcopy(Kvec), j-1)
                VarSet, Dict1 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec,tempKvec,BigFloat(1/d))
                for j2=1:k
                    if j2 !=j 
                        for i2=1:d
                            tempIvec2 = push!(deepcopy(Ivec), i-1, i2-1,i-1)
                            tempKvec2 = push!(deepcopy(Kvec), j-1, j2-1,j-1)
                            VarSet, Dict2 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec2,tempKvec2,-1)
                            testValue = merge(+,Dict1,Dict2)
                            if !checkValue(testValue)
                                push!(ListMissing, testValue)
                            end
                        end
                    end
                end
            end
        end
    end
    return ListMissing 
end 



#check MUB-constraint on homogeneous polynomials of degree 2t-1
#option 1 is level +half, so check for polynomials of degree 2t
function CheckImubPOVMSimple(d,k,t, option=0)
    ListOfReducedMonomials= ReducedMonomials(d,k,2*t-1+option,true)
    VarSet = Set{Tuple{Vector{Int},Vector{Int}}}()
    ListMissing =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}[]
    for monomialpair in ListOfReducedMonomials 
        Ivec=monomialpair[1]; 
        Kvec=monomialpair[2];
        VarSet, Dict1 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,deepcopy(Ivec),deepcopy(Kvec),1)
        for j=1:maximum(Kvec)+1 
            testValue=deepcopy(Dict1)
            for i=1:d
                tempIvec2 = push!(deepcopy(Ivec), i-1)
                tempKvec2 = push!(deepcopy(Kvec), j-1)
                VarSet, Dict2 = DetValMon(VarSet,Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,tempIvec2,tempKvec2,-1)
                testValue = merge(+,testValue,Dict2)
            end
            if !checkValue(testValue)
                push!(ListMissing, testValue)
            end
        end
    end
    return unique(ListMissing) 
end 
function checkValue(MonomialDict::Dict{Tuple{Vector{Int},Vector{Int}},BigFloat} , treshold= 0.00000000001)
    for (key,value) in MonomialDict
        if abs(value) > treshold 
            return false 
        end
    end
    return true 
end


function ComputeTotalInnerProduct(MonomialValuesDictionary,TotalInnerProducts,VarSet,d)
    TestValueDictionary =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
    for (monomialpair,value) in TotalInnerProducts
        tempmonoomd=monomialpair[1]
        tempmonoomK=monomialpair[2]
        if !haskey(MonomialValuesDictionary,monomialpair)
            DictValueMon = Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
            VarSet,DictValueMon = DetValMon(VarSet,DictValueMon,d,deepcopy(tempmonoomd),deepcopy(tempmonoomK),1)
            MonomialValuesDictionary[monomialpair] = DictValueMon
        end
        ##add dictionaries
        TempValueDictionary =Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}()
        [TempValueDictionary[x]=MonomialValuesDictionary[monomialpair][x]*value  for x in keys(MonomialValuesDictionary[monomialpair])]
        TestValueDictionary = merge(+,deepcopy(TestValueDictionary),deepcopy(TempValueDictionary))
    end
    return TestValueDictionary
end
function RemoveLinearDependentConstraints(ListMissing, VarSetOrdered)
    TempVarSet= deepcopy(VarSetOrdered)
    unique!(ListMissing)
    treshold = 0.0000000001 
    numberOfVariables = size(TempVarSet,1)
    push!(TempVarSet,([-1],[-1]))
    Matrix = zeros(BigFloat, size(ListMissing,1),numberOfVariables+1)

    for i=1:size(ListMissing,1)
        for j=1:numberOfVariables+1
            Matrix[i,j]=get(ListMissing[i],TempVarSet[j],0)
        end
    end
    #display(Matrix)

    M= RowEchelon.rref!(Matrix)

    nonZeroDictList=[]
    for i=1:size(M,1)
        isZero=true;
        RowDict= Dict();
        for j=1:size(M,2)
            if abs(M[i,j])> treshold
               RowDict[TempVarSet[j]] = M[i,j]
               isZero=false 
            end
        end
        if !isZero
            push!(nonZeroDictList,RowDict)
        end
    end
    return nonZeroDictList
end


##Check the commutator constraint on monomials 
function CheckImubCommutators(degu,degv,d,k,degt)
    wordsU = degu >=degt ? ReducedMonomials(d,k,degu+1) : GenMonNC(d,k,degu); 
    wordsV = GenMonNC(d,k,degv)
    ListMissing=[]
    wordPairs = []
    for u = 1:size(wordsU,1)
        uI = degu>=degt ? wordsU[u][1][2:end] : wordsU[u,1:degu].-1
        uK = degu>=degt ? wordsU[u][2][2:end] : wordsU[u,degu+1:end].-1
        for v = 1:size(wordsV,1)
            wordV = wordsV[v,:].-1
            vI = wordV[1:degv]
            vK = wordV[degv+1:end]
            wordI = [0;uI;0;vI;0]
            wordK = [0;uK;0;vK;0]
            if degu >= degt 
                wordK = make_partition(wordK)
                tempWord = renumberIdependingOnK(wordI,wordK)
                if !([tempWord;wordK] in wordPairs)
                    push!(wordPairs,[tempWord;wordK])
                end
            else
                push!(wordPairs,[wordI;wordK])
            end
        end
    end
    println("Reduced list of wordPairs has been computed...")
    wordsT= degt >degu ?  ReducedMonomials(d,k,degt+1) : GenMonNC(d,k,degt)
    for w = 1:size(wordPairs,1)
        print("word: ",w,"/",size(wordPairs,1), " \r")
        wordI = wordPairs[w][1:degu+degv+3] 
        wordK = wordPairs[w][degu+degv+4:end] 
        wordI2 = [wordI[1];wordI[3+degu:2+degu+degv];wordI[2+degu];wordI[2:degu+1];wordI[degu+degv+3]]
        wordK2 = [wordK[1];wordK[3+degu:2+degu+degv];wordK[2+degu];wordK[2:degu+1];wordK[degu+degv+3]]
        for i = 1:size(wordsT,1)
            wordtI = degt > degu ? wordsT[i][1][2:end] : wordsT[i,1:degt].-1
            wordtK = degt > degu ? wordsT[i][2][2:end] : wordsT[i,degt+1:2*degt].-1
            VarSet,TempDict1 = DetValMon(Set{Tuple{Vector{Int},Vector{Int}}}(),Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,deepcopy([wordI;wordtI]),deepcopy([wordK;wordtK]),1)
            VarSet,TempDict2 = DetValMon(Set{Tuple{Vector{Int},Vector{Int}}}(),Dict{Tuple{Vector{Int},Vector{Int}},BigFloat}(),d,deepcopy([wordI2;wordtI]),deepcopy([wordK2;wordtK]),-1)
            FinalDict = merge!(+,TempDict1,TempDict2)
            if checkValue(FinalDict) == false 
                push!(ListMissing,deepcopy(FinalDict))
                #println("CONSTRAINT MISSING! ", size(ListMissing),"  ", FinalDict )
            end
        end
    end
    return unique(ListMissing) 
end