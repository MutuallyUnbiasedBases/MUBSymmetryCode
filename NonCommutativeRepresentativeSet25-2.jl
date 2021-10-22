using LinearAlgebra, GenericLinearAlgebra, AbstractAlgebra
using SymEngine, Combinatorics
using Printf

setprecision(128)

#NEW FASTER VERSION
function make_partition(J)  #returns lexicographically smallest element of S_n-orbit of word in {0,..,n-1}^t
    #For example: make_partition([3, 3, 2, 1]) = [0,0,1,2]
    originalJ=deepcopy(J);
    n=length(J);
    nogtehernummeren = collect(1:n) #vector of all indices

    aantalhernummerd=0;
    nieuwentry = 0;

    while aantalhernummerd < n
        kleinstetehernummeren = nogtehernummeren[1];
        gahernummeren  = findall(x -> x == originalJ[kleinstetehernummeren], originalJ);
        J[gahernummeren].= nieuwentry;

        aantalhernummerd+=length(gahernummeren)
        setdiff!(nogtehernummeren, gahernummeren);
        nieuwentry+=1;
    end

    return J
end


#generate array of set partitions of [t] into at most r parts;
function SetPartitionsAtMost(t,r)
    startset = collect(partitions(collect(1:t),1))

    for j=2:r
        startset = append!(startset,collect(partitions(collect(1:t),j)))
    end

    return startset
end

#generate the young shapes of a tableau of k boxes and height at most r
function ShapeAtMost(k,r)
    startset = collect(partitions(k,1))

    for j=2:r
        startset = append!(startset,collect(partitions(k,j)))
    end

    return startset
end

#generate the young shapes of a tableau of k boxes and height at most r+1
# WITH AT LEAST k-r BOXES IN FIRST ROW
function ShapeAtMostrplus1Startkr(k,r)
    shapes = ShapeAtMost(k,r+1)
    newshapes = [];
    for shape in shapes
        if shape[1]>=k-r
            push!(newshapes,shape)
        end
    end
    return newshapes
end


function IsSemiStandard(Y)
    issemi=true;

    rowpartition = Y.part;
    colpartition = conj(Y).part;

    #check rows
    for i=1:size(rowpartition,1)
        for j=1:(rowpartition[i]-1);
            if (Y[i,j]> Y[i,j+1])
                return false
            end
        end
    end

    #check cols
    for i=1:size(colpartition,1)
        for j=1:(colpartition[i]-1);
            if (Y[j,i]>= Y[j+1,i])
                return false
            end
        end
    end

    return issemi;
end


function AllCandidateVectors(k,r)
    test = permutations(collect(2:r+1));
    Candidates=[];
    for i in test
        Candidates =push!(Candidates,[[ones(Int,k-r,1); i]...]);
    end
    return Candidates
end


function ArrayCombinations(A,B)
    ret=[]
    for i=1:size(A,1)
        for j=1:size(B,1)
            ret=push!(ret,cat(A[i],B[j];dims=1))
        end
    end

    return ret;
end


#A is an array with signs, B is just an array of permutations
function ArrayCombinationsWithSigns(A,B)
    ret=[]
    for i=1:size(A,1)
        for j=1:size(B,1)
            ret=push!(ret,(cat(A[i][1],B[j];dims=1),A[i][2]*levicivita(B[j])))
        end
    end

    return ret;
end


#Returns an array with all young tableaux row equivalent to the given young tableau
function AllRowEquivalentTableaux(Y)
    RowEquivalentTableaux=[];
    rowpartition = Y.part;

    #begin with first row
    T=collect(multiset_permutations(Y[1,1:rowpartition[1]],rowpartition[1]));
    #add rows
    for i=2:size(rowpartition,1)
        T=ArrayCombinations(T, collect(multiset_permutations(Y[i,1:rowpartition[i]],rowpartition[i])))
    end

    for i=1:size(T,1)
        fill!(Y,T[i])
        RowEquivalentTableaux = push!(RowEquivalentTableaux,deepcopy(Y))
    end

    return RowEquivalentTableaux;
end


#Returns an array consisting of tuples (P*Y, sign P), where P runs over the permutations in the column stabilizer of Y
function AllColumnSignTableaux(Y)
    ColumnSignTableaux=[];
    rowpartition = Y.part;
    Yprime=conj(Y)
    colpartition = Yprime.part;

    #begin with first column, save permutation + sign
    Tstart=collect(permutations(collect(1:colpartition[1])));
    T=[];
    for i=1:size(Tstart,1)
        T=push!(T,(Tstart[i], levicivita(Tstart[i])))
    end

    #add columns, save permutation + sign
    for i=2:size(colpartition,1)
        T=ArrayCombinationsWithSigns(T, collect(permutations(collect(1:colpartition[i]))))
    end

    #make the new tableaux
    for i=1:size(T,1)
        start=1;
        Yprimecopy = deepcopy(Yprime)
        newfilling=[];
        for j=1:rowpartition[1]
            newfilling=append!(newfilling,Yprime[j,T[i][1][start:start+colpartition[j]-1]])
            start+=colpartition[j]
        end
        fill!(Yprimecopy,convert(Array{Int},newfilling))
        Ydash = conj(Yprimecopy)

        ColumnSignTableaux = push!(ColumnSignTableaux,(Ydash,T[i][2]))
    end

    return ColumnSignTableaux;
end



#generate blocks for k bases and level t
function generateRepresentativeSet(k,t)
    maxheight = min(k,t+1);

    Lambdas = ShapeAtMost(k,maxheight);
    SPartitions = SetPartitionsAtMost(t,maxheight)

    blockSizes=[];
    #maxblockSize=0;



    RepresentativeSet=[];
    for lambda in Lambdas
        #maxreprelementsize=0;
        Ystart = YoungTableau(lambda)
        GoodTableauxPartitions = []
        blockSize = 0;

        for setpart in SPartitions
            r=size(setpart,1);
            candidates = AllCandidateVectors(k,r);
            for candidate in candidates
                fill!(Ystart,candidate)
                if (IsSemiStandard(Ystart))
                    #push a deepcopy so that we push the correct filling and do not change it afterwards.
                    GoodTableauxPartitions = push!(GoodTableauxPartitions,(deepcopy(Ystart),setpart))
                end
            end
        end
        blockSize = size(GoodTableauxPartitions,1)

        ReprArrayLambda=[];

        for rowindex = 1:blockSize
            sigmawithP1 = GoodTableauxPartitions[rowindex];

            P1=sigmawithP1[2];
            r=size(P1,1);

            WordsWithSigns=[]

            RowTableaux = AllRowEquivalentTableaux(sigmawithP1[1])
            for rowtab in RowTableaux
                ColTableaux = AllColumnSignTableaux(rowtab)
                for coltab in ColTableaux
                    FillVector = coltab[1].fill;
                    #we combine the fillvector and the partition into a word of length t;
                    Word = zeros(Int,t);
                    for symbol = 2:r+1
                        position = findall(x -> x.==symbol, FillVector)[1]
                        Set = P1[symbol-1];
                        Word[Set].=position;
                    end
                    Sign = coltab[2];
                    WordsWithSigns=push!(WordsWithSigns, (Word, Sign))
                end
            end

            ReprArrayLambda = push!(ReprArrayLambda,WordsWithSigns)
        end


        if blockSize >0
            blockSizes=push!(blockSizes,blockSize);
            RepresentativeSet=push!(RepresentativeSet,ReprArrayLambda)
        end

    end

    println("blockSizes: $blockSizes")

    return RepresentativeSet, blockSizes
end





#generate blocks for k bases and level t ONLY I-1,1,1,1,1,1-part.
function generatePartitionsTableaux(k,t)
    maxheight = min(k,t+1);

    Lambdas = ShapeAtMost(k,maxheight);
    SPartitions = SetPartitionsAtMost(t,maxheight)

    blockSizes=[];
    #maxblockSize=0;

    LambdaToBlocksDict = Dict();
    for lambda in Lambdas
        #maxreprelementsize=0;
        Ystart = YoungTableau(lambda)
        GoodTableauxPartitions = []
        blockSize = 0;

        for setpart in SPartitions
            r=size(setpart,1);
            candidates = AllCandidateVectors(k,r);
            for candidate in candidates
                fill!(Ystart,candidate)
                if (IsSemiStandard(Ystart))
                    #push a deepcopy so that we push the correct filling and do not change it afterwards.
                    GoodTableauxPartitions = push!(GoodTableauxPartitions,(deepcopy(Ystart),setpart))
                end
            end
        end
        blockSize = size(GoodTableauxPartitions,1)

        if blockSize >0
            blockSizes=push!(blockSizes,blockSize);
            LambdaToBlocksDict[lambda] = GoodTableauxPartitions
        end

    end

    println("blockSizes: $blockSizes")

    return LambdaToBlocksDict, blockSizes
end


include("SimplePolynomials.jl")
function TableauxPolynomialTest()
    t=5
    LambdaToBlocksDict, blockSizes = generatePartitionsTableaux(6,5)
    println(blockSizes)

    @time for (lambda, blockindexelements) in LambdaToBlocksDict
        println("newblock")
        for rowindexelement in blockindexelements
            tab1= rowindexelement[1]
            PartP = rowindexelement[2]
            for colindexelement in blockindexelements
                tab2= colindexelement[1]
                PartQ = colindexelement[2]

                Zpolynomial = symPolytabloidProduct(tab1,tab2)

                InnerProduct=[];
                # println("ZPoly: ", Zpolynomial)
                for (zmon, zcoef) in Zpolynomial.coeffs
                    push!(InnerProduct,(ZijmonWithPQToWord(zmon,PartP,PartQ,t),zcoef))
                end
                #println(InnerProduct)
                # println("Ppart: ", PartP)
                # println("Qpart: ", PartQ)
                # println()

            end
        end
    end

end


function ZijmonWithPQToWord(Zijmon, Ppart, Qpart, t)
word= zeros(Int,2*t); 
Pword= zeros(Int,t);
r1=size(Ppart,1)
r2=size(Qpart,1)
Qword= zeros(Int,t)
rvalue = 0; 
for Pi in Ppart
    rvalue+=1
    Pword[Pi].=rvalue
end
word[1:t]=reverse(Pword)

currentnewelement=r1+1;
for i=1:r2
   j=findfirst(x->x==1, Zijmon[:,i+1])
   if j==1
       Qword[Qpart[i]].=currentnewelement;
       currentnewelement+=1; 
   else
       Qword[Qpart[i]].=j-1 
   end
end
word[t+1:end]=Qword

return make_partition(word)
end


#TableauxPolynomialTest()



#generate blocks for k bases and level t
function generateRepresentativeColumnSet(k,t)
    maxheight = min(k,t+1);

    Lambdas = ShapeAtMost(k,maxheight);
    SPartitions = SetPartitionsAtMost(t,maxheight)

    blockSizes=[];
    #maxblockSize=0;



    RepresentativeSet=[];
    for lambda in Lambdas
        #maxreprelementsize=0;
        Ystart = YoungTableau(lambda)
        GoodTableauxPartitions = []
        blockSize = 0;

        for setpart in SPartitions
            r=size(setpart,1);
            candidates = AllCandidateVectors(k,r);
            for candidate in candidates
                fill!(Ystart,candidate)
                if (IsSemiStandard(Ystart))
                    #push a deepcopy so that we push the correct filling and do not change it afterwards.
                    GoodTableauxPartitions = push!(GoodTableauxPartitions,(deepcopy(Ystart),setpart))
                end
            end
        end
        blockSize = size(GoodTableauxPartitions,1)

        ReprArrayLambda=[];

        for rowindex = 1:blockSize
            sigmawithP1 = GoodTableauxPartitions[rowindex];

            P1=sigmawithP1[2];
            r=size(P1,1);

            WordsWithSigns=[]

            RowTableaux = AllRowEquivalentTableaux(sigmawithP1[1])
            for rowtab in RowTableaux
                FillVector = rowtab.fill;
                #we combine the fillvector and the partition into a word of length t;
                Word = zeros(Int,t);
                for symbol = 2:r+1
                    position = findfirst(x -> x.==symbol, FillVector)
                    Set = P1[symbol-1];
                    Word[Set].=position;
                end

                WordsWithSigns=push!(WordsWithSigns, (Word, 1))
            end

            ReprArrayLambda = push!(ReprArrayLambda,WordsWithSigns)
            #WORDSWITHSIGNS IS NOW THE (sigmawithP1)-th ELEMENT OF THE REPRESENTATIVE SET

        end


        if blockSize >0
            blockSizes=push!(blockSizes,blockSize);
            RepresentativeSet=push!(RepresentativeSet,ReprArrayLambda)
        end

    end

    return RepresentativeSet
end




#generate blocks for k bases and level t
function generateRepresentativeSetPlusHalf(k,t)
    k-=1;  #act only on k-1 elements with Sk-1 for level t+1/2
    maxheight = min(k,t+1);

    Lambdas = ShapeAtMost(k,maxheight);
    SPartitions = SetPartitionsAtMost(t+1,min(k+1,t+1))

    blockSizes=[];

    RepresentativeSet=[];
    for lambda in Lambdas

        Ystart = YoungTableau(lambda)
        GoodTableauxPartitions = []
        blockSize = 0;

        for setpart in SPartitions
            r=size(setpart,1) -1;  #first partition will correspond to first symbol which is fixed
            candidates = AllCandidateVectors(k,r);
            for candidate in candidates
                fill!(Ystart,candidate)
                if (IsSemiStandard(Ystart))
                    #push a deepcopy so that we push the correct filling and do not change it afterwards.
                    GoodTableauxPartitions = push!(GoodTableauxPartitions,(deepcopy(Ystart),setpart))
                    blockSize+=1;
                end
            end

        end

        ReprArrayLambda=[];

        for rowindex = 1:blockSize
            sigmawithP1 = GoodTableauxPartitions[rowindex];

            P1=sigmawithP1[2];
            r=size(P1,1)-1;  #minus one because the first partition is fixed

            WordsWithSigns=[]

            RowTableaux = AllRowEquivalentTableaux(sigmawithP1[1])
            for rowtab in RowTableaux
                ColTableaux = AllColumnSignTableaux(rowtab)
                for coltab in ColTableaux
                    FillVector = coltab[1].fill;
                    #we combine the fillvector and the partition into a word of length t;
                    Word = zeros(Int,t+1);
                    FirstSet = P1[1]
                    Word[FirstSet].=1;
                    for symbol = 2:r+1
                        position = findall(x -> x.==symbol, FillVector)[1]
                        Set = P1[symbol];
                        Word[Set].=position+1;
                    end
                    Sign = coltab[2];
                    popfirst!(Word)  #this is optional. We remove the first element from the word, so that we obtain a word of length t instead of a word of length t+1 starting with 1.
                    WordsWithSigns=push!(WordsWithSigns, (Word, Sign))
                end
            end

            ReprArrayLambda = push!(ReprArrayLambda,WordsWithSigns)

            #WORDSWITHSIGNS IS NOW THE (sigmawithP1)-th ELEMENT OF THE REPRESENTATIVE SET
        end


        if blockSize >0
            blockSizes=push!(blockSizes,blockSize);
            RepresentativeSet=push!(RepresentativeSet,ReprArrayLambda)
        end

    end

    println("blockSizes: $blockSizes")
    return RepresentativeSet, blockSizes
end


#generate blocks for k bases and level t
function generateRepresentativeColumnSetPlusHalf(k,t)
    k-=1;  #act only on k-1 elements with Sk-1 for level t+1/2
    maxheight = min(k,t+1);

    Lambdas = ShapeAtMost(k,maxheight);
    SPartitions = SetPartitionsAtMost(t+1,min(k+1,t+1))

    blockSizes=[];

    RepresentativeSet=[];
    for lambda in Lambdas

        Ystart = YoungTableau(lambda)
        GoodTableauxPartitions = []
        blockSize = 0;

        for setpart in SPartitions
            r=size(setpart,1) -1;  #first partition will correspond to first symbol which is fixed
            candidates = AllCandidateVectors(k,r);
            for candidate in candidates
                fill!(Ystart,candidate)
                if (IsSemiStandard(Ystart))
                    #push a deepcopy so that we push the correct filling and do not change it afterwards.
                    GoodTableauxPartitions = push!(GoodTableauxPartitions,(deepcopy(Ystart),setpart))
                    blockSize+=1;
                end
            end

        end

        ReprArrayLambda=[];

        for rowindex = 1:blockSize
            sigmawithP1 = GoodTableauxPartitions[rowindex];

            P1=sigmawithP1[2];
            r=size(P1,1)-1;  #minus one because the first partition is fixed

            WordsWithSigns=[]

            RowTableaux = AllRowEquivalentTableaux(sigmawithP1[1])
            for rowtab in RowTableaux
                FillVector = rowtab.fill;
                #we combine the fillvector and the partition into a word of length t;
                Word = zeros(Int,t+1);
                FirstSet = P1[1]
                Word[FirstSet].=1;
                for symbol = 2:r+1
                    position = findall(x -> x.==symbol, FillVector)[1]
                    Set = P1[symbol];
                    Word[Set].=position+1;
                end
                popfirst!(Word)  #this is optional. We remove the first element from the word, so that we obtain a word of length t instead of a word of length t+1 starting with 1.
                WordsWithSigns=push!(WordsWithSigns, (Word, 1))
            end

            ReprArrayLambda = push!(ReprArrayLambda,WordsWithSigns)

            #WORDSWITHSIGNS IS NOW THE (sigmawithP1)-th ELEMENT OF THE REPRESENTATIVE SET
        end


        if blockSize >0
            blockSizes=push!(blockSizes,blockSize);
            RepresentativeSet=push!(RepresentativeSet,ReprArrayLambda)
        end

    end
    return RepresentativeSet
end



function ReduceInnerProducts(ReprSet, ReprColSet, option=1, computeOnlyUpperDiagonal=false)
    #if option==2, we do the t+1/2- version. The corresponding representative sets must be given as input arguments!
    #If option==1, we do the normal t-th level version. The corresponding representative sets must be given as input arguments!
    aantalblocks = size(ReprSet,1)
    ReducedBlocks=[];
    @time for i=1: aantalblocks
        Ulambda = ReprSet[i];
        Ucollambda = ReprColSet[i]
        blockSize=size(Ulambda,1);
        println("block ",i ," of size ", blockSize )
        Block = Array{Array}(undef,blockSize,blockSize)
        for rowidx = 1:blockSize
            println("row ", rowidx)
            ReprRow = Ulambda[rowidx]
            for colidx = 1:blockSize
                if !computeOnlyUpperDiagonal || colidx >= rowidx
                    ReprCol = Ucollambda[colidx]
                    #compute the inner product, this is costly!
                    RowColDict = Dict()
                    Entry=[];
                    if (option==2)
                        for wordssign1 in ReprRow
                            firstpartword = reverse(wordssign1[1])
                            for wordssign2 in ReprCol
                                tempmonoom = make_partition([firstpartword;1;wordssign2[1]])

                                if !haskey(RowColDict,tempmonoom)
                                    RowColDict[tempmonoom] = wordssign1[2]
                                else
                                    RowColDict[tempmonoom] += wordssign1[2]
                                end
                            end
                        end
                    else
                        for wordssign1 in ReprRow
                            firstpartword = reverse(wordssign1[1])
                            for wordssign2 in ReprCol
                                tempmonoom = make_partition([firstpartword;wordssign2[1]])

                                if !haskey(RowColDict,tempmonoom)
                                    RowColDict[tempmonoom] = wordssign1[2]
                                else
                                    RowColDict[tempmonoom] += wordssign1[2]
                                end
                            end
                        end
                    end
                    for (monoom, value) in RowColDict
                        push!(Entry,(monoom,value))
                    end
                    Block[rowidx, colidx]=Entry
                end
            end
        end
        ReducedBlocks = push!(ReducedBlocks,Block);
    end
    return ReducedBlocks
end




function ReduceInnerProduct(ReprRow, ReprCol, option=1)
    #if option==2, we do the t+1/2- version. The corresponding representative set elements must be given as input arguments!
    #If option==1, we do the normal t-th level version. The corresponding representative set elements must be given as input arguments!

                    #compute the inner product, this is costly!
                    RowColDict = Dict()
                    Entry=[];
                    if (option==2)
                        for wordssign1 in ReprRow
                            firstpartword = reverse(wordssign1[1])
                            for wordssign2 in ReprCol
                                tempmonoom = make_partition([firstpartword;1;wordssign2[1]])

                                if !haskey(RowColDict,tempmonoom)
                                    RowColDict[tempmonoom] = wordssign1[2]
                                else
                                    RowColDict[tempmonoom] += wordssign1[2]
                                end
                            end
                        end
                    else
                        for wordssign1 in ReprRow
                            firstpartword = reverse(wordssign1[1])
                            for wordssign2 in ReprCol
                                tempmonoom = make_partition([firstpartword;wordssign2[1]])

                                if !haskey(RowColDict,tempmonoom)
                                    RowColDict[tempmonoom] = wordssign1[2]
                                else
                                    RowColDict[tempmonoom] += wordssign1[2]
                                end
                            end
                        end
                    end
                    for (monoom, value) in RowColDict
                        push!(Entry,(monoom,value))
                    end
	    return RowColDict;
end


#flatten function
function flatten(arr)
	rst = Any[]
	grep(v) = 	for x in v
				if isa(x, Tuple)
				grep(x)
				else push!(rst, x) end
				end
	grep(arr)
	return rst
end

#returns a list of tuples of products (x,y) with x in the first and y in the second array.
# if you apply it iteratively, it returns tuples of tuples like (x,(y,(w,z))). The function flatten from above can then return an array [x,y,w,z].
function productQ(Qfirst, Qj)
    outputQ=[];
    if (isempty(Qfirst))
        return Qj;
    end
    outputQ= collect( Base.product( Qfirst,Qj))
    return outputQ;
end

function CreatePQiPartitions(k,d,t)
    PPartitions = SetPartitionsAtMost(t,k)
    PWithQList = []
    for P in PPartitions
        QPartitionslist =[];
        for Pi in P
            QiPartitions = SetPartitionsAtMost(length(Pi),d)
            QPartitionslist = productQ(QPartitionslist,QiPartitions)
        end
        for Q in QPartitionslist
            Qdef=flatten(Q)
            #Make sure that if P consists of only one part, we still consider Q as a collection [Q_1].
            if size(P,1)==1
                 Test=Any[]
                  push!(Test,Qdef)
                  Qdef=Test
            end
            push!(PWithQList,(P,Qdef))
        end
    end
    return PWithQList
end

##ONLY CREATE RELEVANT P,{Q_1,...,Q_r} that do NOT give rise to zero rows.
function CreateRelevantPQiPartitions(k,d,t)
    PPartitions = SetPartitionsAtMost(t,k)
    PWithQList = []
    for P in PPartitions
        QPartitionslist =[];
        for Pi in P
            QiPartitions = SetPartitionsAtMost(length(Pi),d)
            QPartitionslist = productQ(QPartitionslist,QiPartitions)
        end
        for Q in QPartitionslist
            Qdef=flatten(Q)
            #Make sure that if P consists of only one part, we still consider Q as a collection [Q_1].
            if size(P,1)==1
                 Test=Any[]
                  push!(Test,Qdef)
                  Qdef=Test
            end

            #Create Kvec and Ivec out of P,Qdef.
            Kvec  = zeros(Int,t);
            Ivec = zeros(Int,t); 
            piindex=0;
            for Pi in P
                Kvec[Pi].= piindex
                piindex+=1
                
                IvecPart = zeros(Int,size(Pi,1))
                qiindex=0;
                for Qii in Qdef[piindex]
                    IvecPart[Qii].=qiindex
                    qiindex+=1
                end
                Ivec[Pi].=IvecPart
            end


            #check if (Kvec, Ivec) gives zero row
            givesZeroRow=false
            for index1 in 1:t-1    #if there is a basis which occurs twice subsequently: reduce using Projector-constraint
                index2 = index1+1 ;
        
                if (Kvec[index1]==Kvec[index2] && Ivec[index1] != Ivec[index2])
                        givesZeroRow=true;
                end
            end

            if (!givesZeroRow)
                push!(PWithQList,(P,Qdef))
            end
        end
    end
    return PWithQList
end

multisets(n, k)  = map(A -> [sum(A .== i) for i in 1:n],
                      with_replacement_combinations(1:n, k))



#consider the partition mur=(d-r,1,....,1).
#create a map from from lambda vdash d
#to all semistandard young tableaux of shape lambda with filling mu_r.
function CreateSemiStandardTableauxsizedmur(d,r)
    Shapes =  ShapeAtMost(d,r+1)
    MapLambdaDToSSYT= Dict();
    candidates = AllCandidateVectors(d,r);
    for lambda in Shapes
        GoodTableauxPartitions =[]
        Ystart = YoungTableau(lambda)
        for candidate in candidates
            fill!(Ystart,candidate)
            if (IsSemiStandard(Ystart))
                #push a deepcopy so that we push the correct filling and do not change it afterwards.
                GoodTableauxPartitions = push!(GoodTableauxPartitions,deepcopy(Ystart))
            end
        end
        MapLambdaDToSSYT[lambda] =  GoodTableauxPartitions
    end
    return MapLambdaDToSSYT
end


#consider the partition mur=(d-r,1,....,1).
#create a map from from lambda vdash d
#to all semistandard young tableaux of shape lambda with filling mu_r.
function CreateSemiStandardTableauxsizedmurForShape(d,r,shape)
    candidates = AllCandidateVectors(d,r);
        GoodTableauxPartitions =[]
        Ystart = YoungTableau(shape)
        for candidate in candidates
            fill!(Ystart,candidate)
            if (IsSemiStandard(Ystart))
                #push a deepcopy so that we push the correct filling and do not change it afterwards.
                GoodTableauxPartitions = push!(GoodTableauxPartitions,deepcopy(Ystart))
            end
        end
    return GoodTableauxPartitions
end


function TableauxTuples(composition,k, r)
    TableauxTuples =[]
    TTuplesFinal = []
   for ki in composition
      if ki>0
       Shapes =  ShapeAtMost(ki,r+1)
      else
       Shapes=[[]]
      end
      TableauxTuples = productQ(TableauxTuples,Shapes)
   end
   for TabProd in TableauxTuples
        TabProdDef=flatten(TabProd)
        #only push shapes with at least k-r in the first row of the first tableau (or empty first tableau if k0=0)
        if(size(TabProdDef[1],1)==0 || TabProdDef[1][1]>=k-r)
            push!(TTuplesFinal,TabProdDef)
        end
   end

   return TTuplesFinal
end

#TableauxTuples([6; 2;0;0],8,3)


function BlockGroottesFullProblem(k, d, t)
    PWithQList = CreatePQiPartitions(k,d,t) #CreateRelevantPQiPartitions(k,d,t)

    LambdasForD = ShapeAtMost(d,t+1) 
    MapLambdaDToIndex = Dict();
    MapIndexToLambdaD = Dict();


    MapFinalBlockDiagLambda = Dict();

    for PQ in PWithQList
        P=PQ[1]; Q=PQ[2];
        r=size(P,1);
        biggestQiSize = maximum([size(Qi,1) for Qi in Q ])

        LambdasForDr = ShapeAtMost(d,biggestQiSize+1)
        MapLambdaDToIndex = Dict();
        MapIndexToLambdaD = Dict();
        index=0;
        for lambdaD in LambdasForDr
            index+=1;
            MapLambdaDToIndex[lambdaD]=index;
            MapIndexToLambdaD[index]=lambdaD
        end
        maximumLambdaDIndex = size(LambdasForDr,1);   

        #generate compositions of k in at most maximumLambdaDIndex parts.
        CompositionsToConsider = multisets(maximumLambdaDIndex,k)
        for comp in CompositionsToConsider
            #consider only relevant compositions
            if comp[1] >= k-r 
                TableauxT = TableauxTuples(comp,k, r);
                # now we have all relevant Lambda
                for tableauxTuple in TableauxT
                    #make sure the tableauxtuple is of the correct length
                    for j=size(tableauxTuple,1)+1:size(LambdasForD,1)
                        push!(tableauxTuple,[])
                    end
                     # generate possible fillings.
                    fillingkvectors = AllCandidateVectors(k,r)

                    for fillingkvector in fillingkvectors
                        startindex =1;
                        kantoevoegen=true;
                        FilledTableauxTuple=[];
                        for tupleindex = 1:size(comp,1)
                            ki=comp[tupleindex]
                            fillkivector = fillingkvector[startindex : startindex+ki - 1]
                            Ytab = ki>0 ? YoungTableau(convert(Array{Int64,1},tableauxTuple[tupleindex])) : []
                            if ki>0
                                fill!(Ytab,fillkivector)
                                if (ki >0 &&!IsSemiStandard(Ytab))
                                    kantoevoegen=false;
                                end
                            end
                            startindex+=ki
                            push!(FilledTableauxTuple,Ytab)
                        end
                        if kantoevoegen
                            #for each ri = 1:r, create collection (array) with possibilities for 1:r ssyts
                            # in the end, each entry of allowedSSYTSD must become an array of size r, where entry i is a SSYT of shape nu_j, where j is the unique j such that lambda_j contains
                            # the entry i+1.
                            allowedSSYTSD=[]
                            newsize=1;
                            productofmorethanonetableau=false
                            for ri=1:r
                                fillindex = findall(x -> x==ri+1,fillingkvector)[1]
                                RelevantQi = Q[ri]
                                Qisize=size(RelevantQi,1)

                                #determine composition index
                                compindex=1;
                                compsum=comp[1]
                                while compsum < fillindex
                                    compindex+=1;
                                    compsum+=comp[compindex]
                                end
                                #now we know the i for which lambda_i vdash k_i contains the sign ri
                                #recover shape:
                                shape = MapIndexToLambdaD[compindex]
                                newSSYTS= CreateSemiStandardTableauxsizedmurForShape(d,Qisize,shape)  #NEW: QIsize
                                newsize = isempty(newSSYTS) ? 0 : newsize*length(newSSYTS)
                                if newsize>=1
                                    if (!isempty(allowedSSYTSD) && !isempty(newSSYTS))
                                        productofmorethanonetableau=true
                                    end
                                    allowedSSYTSD = productQ(allowedSSYTSD, newSSYTS)
                                end
                            end
                            Test=Any[];
                            if productofmorethanonetableau
                                for indextemp = 1: newsize
                                    push!(Test,flatten(allowedSSYTSD[indextemp]))
                                end
                            else
                            #tuple contains only one tableau, AllowedSSYTSD is a list [tab1, tab2, tab3] but we want it to be [[tab1],[tab2],[tab3]]
                                for indextemp = 1: newsize
                                    push!(Test,[allowedSSYTSD[indextemp]])
                                end
                            end
                            allowedSSYTSD=Test
                            if (!haskey(MapFinalBlockDiagLambda,tableauxTuple))
                                MapFinalBlockDiagLambda[tableauxTuple]=[]
                            end
                            for test=1:newsize
                                push!(MapFinalBlockDiagLambda[tableauxTuple], [P,Q,FilledTableauxTuple,allowedSSYTSD[test]])
                            end
                        end
                    end
                end
            end
        end
    end

    totaal=0;
    totaalsom = 0;
    maxblokgrootte=0;
    for (key, value) in MapFinalBlockDiagLambda
        blokgrootte=length(value)
        if (blokgrootte>0 )
            println(key, " of size ", blokgrootte)
            totaal=totaal+(blokgrootte*blokgrootte);
            totaalsom=totaalsom+(blokgrootte);
            if blokgrootte > maxblokgrootte
                maxblokgrootte=blokgrootte
            end
        else
            delete!(MapFinalBlockDiagLambda,key)
        end
    end
    println("som van kwadraten van gevonden blokgroottes: ",totaal)
    println("som van blokgroottes: ",totaalsom)
    println("max blokgrootte: ",maxblokgrootte)
    return MapFinalBlockDiagLambda
end


BlockGroottesFullProblem(4, 4, 2)

function BlockGroottesFullProblemPlusHalf(k, d, t)
    PWithQList =  CreateRelevantPQiPartitions(k,d,t+1) #CreatePQiPartitions(k,d,t+1)

    LambdasForD = ShapeAtMost(d,t+1) 
    MapLambdaDToIndex = Dict();
    MapIndexToLambdaD = Dict();


    MapFinalBlockDiagLambda = Dict();

    for PQ in PWithQList
        P=PQ[1]; Q=PQ[2];
        r=size(P,1)-1;  #NOTE: first partition fixed (plus half), r one smaller. 
        biggestQiSize = maximum([size(Qi,1) for Qi in  Q])  #determine the size of the largest Qi 
        biggestQiSize >t ? biggestQiSize=t : biggestQiSize=biggestQiSize ; 

        #println(biggestQiSize)

        FirstQi = Q[1]
        Qisize=size(FirstQi,1)
        LambdasForFirstQi = ShapeAtMost(d-1,Qisize) 

        LambdasForDr = ShapeAtMost(d,biggestQiSize+1)
        MapLambdaDToIndex = Dict();
        MapIndexToLambdaD = Dict();
        index=0;
        for lambdaD in LambdasForDr
            index+=1;
            MapLambdaDToIndex[lambdaD]=index;
            MapIndexToLambdaD[index]=lambdaD
        end
        maximumLambdaDIndex = size(LambdasForDr,1);   

        #generate compositions of k in at most maximumLambdaDIndex parts.
        CompositionsToConsider = multisets(maximumLambdaDIndex,k-1)
        for comp in CompositionsToConsider
            #consider only relevant compositions
            if comp[1] >= k-1-r 
                TableauxT = TableauxTuples(comp,k-1, r);
                # now we have all relevant Lambda
                for tableauxTuple in TableauxT
                #make sure the tableauxtuple is of the correct length
               # println(size(tableauxTuple,1))
                for j=size(tableauxTuple,1)+1:size(LambdasForD,1)
                    push!(tableauxTuple,[])
                end

                for shapeFirstQi in LambdasForFirstQi

                     # generate possible fillings.
                    fillingkvectors = AllCandidateVectors(k-1,r)

                    for fillingkvector in fillingkvectors
                        startindex =1;
                        kantoevoegen=true;
                        FilledTableauxTuple=[];
                        for tupleindex = 1:size(comp,1)
                            ki=comp[tupleindex]
                            fillkivector = fillingkvector[startindex : startindex+ki - 1]
                            Ytab = ki>0 ? YoungTableau(convert(Array{Int64,1},tableauxTuple[tupleindex])) : []
                            if ki>0
                                fill!(Ytab,fillkivector)
                                if (ki >0 &&!IsSemiStandard(Ytab))
                                    kantoevoegen=false;
                                end
                            end
                            startindex+=ki
                            push!(FilledTableauxTuple,Ytab)
                        end
                        if kantoevoegen 
                            #for each ri = 1:r, create collection (array) with possibilities for 1:r ssyts
                            # in the end, each entry of allowedSSYTSD must become an array of size r, where entry i is a SSYT of shape nu_j, where j is the unique j such that lambda_j contains
                            # the entry i+1.
                            allowedSSYTSD=[]
                            newsize=1;
                            productofmorethanonetableau=false
                            FirstQi = Q[1] 
                            Qisize=size(FirstQi,1)
                            newSSYTS= CreateSemiStandardTableauxsizedmurForShape(d-1,Qisize-1,shapeFirstQi)  
                            newsize = isempty(newSSYTS) ? 0 : newsize*length(newSSYTS)
                            if newsize>=1
                                if (!isempty(allowedSSYTSD) && !isempty(newSSYTS))
                                    productofmorethanonetableau=true
                                end
                                allowedSSYTSD = productQ(allowedSSYTSD, newSSYTS)
                            end
                            for ri=1:r
                                fillindex = findall(x -> x==ri+1,fillingkvector)[1]
                                RelevantQi = Q[ri+1]
                                Qisize=size(RelevantQi,1)

                                #determine composition index
                                compindex=1;
                                compsum=comp[1]
                                while compsum < fillindex
                                    compindex+=1;
                                    compsum+=comp[compindex]
                                end
                                #now we know the i for which lambda_i vdash k_i contains the sign ri
                                #recover shape:
                                shape = MapIndexToLambdaD[compindex]
                                newSSYTS= CreateSemiStandardTableauxsizedmurForShape(d,Qisize,shape)  #NEW: QIsize
                                newsize = isempty(newSSYTS) ? 0 : newsize*length(newSSYTS)
                                if newsize>=1
                                    if (!isempty(allowedSSYTSD) && !isempty(newSSYTS))
                                        productofmorethanonetableau=true
                                    end
                                    allowedSSYTSD = productQ(allowedSSYTSD, newSSYTS)
                                end
                            end
                            
                            Test=Any[];
                            if productofmorethanonetableau
                                for indextemp = 1: newsize
                                    push!(Test,flatten(allowedSSYTSD[indextemp]))
                                end
                            else
                            #tuple contains only one tableau, AllowedSSYTSD is a list [tab1, tab2, tab3] but we want it to be [[tab1],[tab2],[tab3]]
                                for indextemp = 1: newsize
                                    push!(Test,[allowedSSYTSD[indextemp]])
                                end
                            end
                            allowedSSYTSD=Test
                            if (!haskey(MapFinalBlockDiagLambda,(tableauxTuple,shapeFirstQi)))
                                MapFinalBlockDiagLambda[(tableauxTuple,shapeFirstQi)]=[]
                            end
                            for test=1:newsize
                                push!(MapFinalBlockDiagLambda[(tableauxTuple,shapeFirstQi)], [P,Q,FilledTableauxTuple,allowedSSYTSD[test]])
                            end
                        end
                    end
                end
                end
            end
        end
    end

    totaal=0;
    totaalsom = 0;
    maxblokgrootte=0;
    for (key, value) in MapFinalBlockDiagLambda
        blokgrootte=length(value)
        if (blokgrootte>0 )
            # println()
            println(key, " of size ", blokgrootte)
            # println("indicesobject")
            # println()
            # display(value)
            # println()
            totaal=totaal+(blokgrootte*blokgrootte);
            totaalsom=totaalsom+blokgrootte;
            if blokgrootte > maxblokgrootte
                maxblokgrootte=blokgrootte
            end
        else
            delete!(MapFinalBlockDiagLambda,key)
        end
    end
    println("som van kwadraten van gevonden blokgroottes: ",totaal)
    println("som van gevonden blokgroottes: ",totaalsom)
    println("max blokgrootte: ",maxblokgrootte)
    return MapFinalBlockDiagLambda
end


#BlockGroottesFullProblemPlusHalf(3,3,1)

function TableauxVectorsProduct(ProductArray, NewVectorWithSigns)
    OutputWithSigns=[]
    if (isempty(NewVectorWithSigns) || isempty(ProductArray))
        return isempty(ProductArray) ? NewVectorWithSigns : ProductArray;
    end
    for v1WithSign in ProductArray
        for v2WithSign in NewVectorWithSigns
            push!(OutputWithSigns, (vcat(v1WithSign[1], v2WithSign[1]) ,v1WithSign[2]*v2WithSign[2]))
        end
    end

    return OutputWithSigns
end

function QiTableauxVectorsProduct(ProductArray, NewVectorWithSigns)
    OutputWithSigns=[]
    if (isempty(NewVectorWithSigns))
        return ProductArray;
    end
    if (isempty(ProductArray))
        for v2WithSign in NewVectorWithSigns
            newwordlist = []
            push!(newwordlist,v2WithSign[1])
            push!(OutputWithSigns,(newwordlist,v2WithSign[2] ))
        end
    end
    for v1WithSign in ProductArray
        for v2WithSign in NewVectorWithSigns
                newwordlist = []
                for word in v1WithSign[1]
                        if (size(word,1)==1)
                            newwordlist=push!(newwordlist,[word[1]])  
                        else
                            push!(newwordlist,word) 
                        end
                end
                push!(newwordlist,v2WithSign[1])
                push!(OutputWithSigns,(newwordlist,v1WithSign[2]*v2WithSign[2] ))
        end
    end

    return OutputWithSigns
end

#indexobject = [P, Q, \bm{tau}, \bm{sigma}]

function RepresentativeFullElement(indexobject )
    P=indexobject[1]
    #determine t
    t=0;
    for Pi in P
        t+=size(Pi,1)
    end

    #println("P: ", P)
    Q=indexobject[2]
    #println("Q: ", Q)
    FilledKTableauxTuple = indexobject[3]
    FilledDTableauxTuple = indexobject[4]

    ### Make k-representative object
    ProductTableauVectorsWithSigns=[]
    for tauitableau in FilledKTableauxTuple
        TableauVectorsWithSigns =[];
        if (!isempty(tauitableau))
            RowTableaux = AllRowEquivalentTableaux(tauitableau)
            for rowtab in RowTableaux
                ColTableaux = AllColumnSignTableaux(rowtab)
                for coltab in ColTableaux
                    FillVector = coltab[1].fill;
                    #we combine the fillvector and the partition into a word of length t;
                    Sign = coltab[2];
                    TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (FillVector, Sign))
                end
            end
            ProductTableauVectorsWithSigns = TableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        end
    end 
    WordsKWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        FillVector= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word=zeros(Int,t)
        for symbol = 1:size(P,1)
            position = findall(x -> x.==(symbol+1), FillVector)[1]
            Set = P[symbol];
            Word[Set].=position;
        end
        push!(WordsKWithSigns,(Word, sign))
    end

    ############# MAKE D-OBJECT ###################
    #println("filledDtuple:", FilledDTableauxTuple)
    qiindex=1;
    ProductTableauVectorsWithSigns=[]
    for sigmaitableau in FilledDTableauxTuple
        Qi=Q[qiindex];
        lengthword = length(P[qiindex])
        qiindex+=1;
        TableauVectorsWithSigns =[];
        RowTableaux = AllRowEquivalentTableaux(sigmaitableau)
        for rowtab in RowTableaux
            ColTableaux = AllColumnSignTableaux(rowtab)
            for coltab in ColTableaux
                FillVector = coltab[1].fill;
                #we combine the fillvector and the partition into a word of length r_i;
                ri = maximum(FillVector)-1;
                Word = zeros(Int,lengthword);
                for symbol = 2:ri+1
                    position = findall(x -> x.==symbol, FillVector)[1]
                    Set = Qi[symbol-1];
                    Word[Set].=position;
                end
                Sign = coltab[2];
                TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (Word, Sign))
            end
        end
        ProductTableauVectorsWithSigns = QiTableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
    end
    WordsDWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        vectorslist= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word = zeros(Int,t);
        piindex=1;
        for Pi in P
            Word[Pi].=vectorslist[piindex]
            piindex+=1
        end
        push!(WordsDWithSigns,(Word, sign))
    end
    ########### END OF D-OBJECT ###########################

    return (WordsKWithSigns, WordsDWithSigns)
end


function RepresentativeColumnElement(indexobject )
    P=indexobject[1]
    #determine t
    t=0;
    for Pi in P
        t+=size(Pi,1)
    end

    #println("P: ", P)
    Q=indexobject[2]
    #println("Q: ", Q)
    FilledKTableauxTuple = indexobject[3]
    FilledDTableauxTuple = indexobject[4]

    ### Make k-representative object
    ProductTableauVectorsWithSigns=[]
    for tauitableau in FilledKTableauxTuple
        TableauVectorsWithSigns =[];
        if (!isempty(tauitableau))
            RowTableaux = AllRowEquivalentTableaux(tauitableau)
            for rowtab in RowTableaux
                    FillVector = rowtab.fill;
                    #we combine the fillvector and the partition into a word of length t;
                    TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (FillVector,1))
            end
            ProductTableauVectorsWithSigns = TableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        end
    end 
    WordsKWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        FillVector= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word=zeros(Int,t)
        for symbol = 1:size(P,1)
            position = findall(x -> x.==(symbol+1), FillVector)[1]
            Set = P[symbol];
            Word[Set].=position;
        end
        push!(WordsKWithSigns,(Word, sign))
    end

    ############# MAKE D-OBJECT ###################
    #println("filledDtuple:", FilledDTableauxTuple)
    qiindex=1;
    ProductTableauVectorsWithSigns=[]
    for sigmaitableau in FilledDTableauxTuple
        Qi=Q[qiindex];
        lengthword = length(P[qiindex])
        qiindex+=1;
        TableauVectorsWithSigns =[];
        RowTableaux = AllRowEquivalentTableaux(sigmaitableau)
        for rowtab in RowTableaux
                FillVector = rowtab.fill;
                #we combine the fillvector and the partition into a word of length r_i;
                ri = maximum(FillVector)-1;
                Word = zeros(Int,lengthword);
                for symbol = 2:ri+1
                    position = findall(x -> x.==symbol, FillVector)[1]
                    Set = Qi[symbol-1];
                    Word[Set].=position;
                end
                TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (Word, 1))
            
        end
        ProductTableauVectorsWithSigns = QiTableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
    end
    WordsDWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        vectorslist= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word = zeros(Int,t);
        piindex=1;
        for Pi in P
            Word[Pi].=vectorslist[piindex]
            piindex+=1
        end
        push!(WordsDWithSigns,(Word, sign))
    end
    ########### END OF D-OBJECT ###########################

    return (WordsKWithSigns, WordsDWithSigns)
end

function TestFullFunction( )
    TestMap = BlockGroottesFullProblem(7,6,5)

    #Key are the shapes Lambda, Value contains the indexobjects for the rows/columns of the block corresponding to Lambda
    for (key, value) in TestMap
        for indexobject in value
            RepresentativeFullElement(indexobject )
        end
    end
    println("einde zonder fouten :-)")
end

function ReduceInnerProductFULL(ReprRow, ReprCol)
    #we do the normal t-th level version. The corresponding representative set elements must be given as input arguments!

        #compute the inner product, this is costly!
        RowColKDict = Dict()
        RowColDDict = Dict()

        ReprKRow=ReprRow[1]; ReprDRow=ReprRow[2];
        ReprKCol=ReprCol[1]; ReprDCol=ReprCol[2];
        
        ##reduce K inner product
        for wordssign1 in ReprKRow
            firstpartword = reverse(wordssign1[1])
            for wordssign2 in ReprKCol
                tempmonoom = make_partition([firstpartword;wordssign2[1]])

                if !haskey(RowColKDict,tempmonoom)
                    RowColKDict[tempmonoom] = wordssign1[2]
                else
                    RowColKDict[tempmonoom] += wordssign1[2]
                end
            end
        end

        ##reduce d inner product
        for wordssign1 in ReprDRow
            firstpartword = reverse(wordssign1[1])
            for wordssign2 in ReprDCol
                tempmonoom = make_partition([firstpartword;wordssign2[1]])

                if !haskey(RowColDDict,tempmonoom)
                    RowColDDict[tempmonoom] = wordssign1[2]
                else
                    RowColDDict[tempmonoom] += wordssign1[2]
                end
            end
        end

    return (RowColKDict, RowColDDict );
end 



function ReduceInnerProductFULLNEW(ReprRow, ReprCol)
    #we do the normal t-th level version. The corresponding representative set elements must be given as input arguments!

        #compute the inner product, this is costly!
        RowColKDict = Dict()
        EntryDict = Dict()

        ReprKRow=ReprRow[1]; ReprDRow=ReprRow[2];
        ReprKCol=ReprCol[1]; ReprDCol=ReprCol[2];
        
        ##reduce K inner product
        for wordssign1 in ReprKRow
            firstpartword = reverse(wordssign1[1])
            for wordssign2 in ReprKCol
                tempmonoom = make_partition([firstpartword;wordssign2[1]])

                if !haskey(RowColKDict,tempmonoom)
                    RowColKDict[tempmonoom] = wordssign1[2]
                else
                    RowColKDict[tempmonoom] += wordssign1[2]
                end
            end
        end

        ##For all k inner products, reduce d inner product depending on k inner product
        for (tempmonoomK, valueK)  in RowColKDict
            Kpart=[];
            for i in unique(tempmonoomK)
                push!(Kpart,findall(x->x==i, tempmonoomK));
            end
            for wordssign1 in ReprDRow
                firstpartword = reverse(wordssign1[1])
                for wordssign2 in ReprDCol

                    tempmonoomDim=renumberIdependingOnKPartition([firstpartword;wordssign2[1]],Kpart)

                    if !haskey(EntryDict,(tempmonoomDim, tempmonoomK))
                        EntryDict[(tempmonoomDim, tempmonoomK)] = valueK*wordssign1[2]
                    else 
                        EntryDict[(tempmonoomDim, tempmonoomK)] +=  valueK*wordssign1[2]
                    end
                end
            end
        end

    return EntryDict;
end

function renumberIdependingOnKPartition(Ivec,KPartition)
    for Pi in KPartition
        Ivec[Pi] = make_partition(Ivec[Pi])
    end
    return Ivec;

end

function ReduceInnerProductFurther(InnerProductsK, InnerProductsD)

        #compute the inner product, this is costly!
        EntryDict = Dict()

        for (tempmonoomK, valueK)  in InnerProductsK
            Kpart=[];
            for i in unique(tempmonoomK)
                push!(Kpart,findall(x->x==i, tempmonoomK));
            end
            for (tempmonoomDim, valueD)  in InnerProductsD
                tempmonoomDim=renumberIdependingOnKPartition(deepcopy(tempmonoomDim),Kpart)
                if !haskey(EntryDict,(tempmonoomDim, tempmonoomK))
                    EntryDict[(tempmonoomDim, tempmonoomK)] = valueK*valueD
                else 
                    EntryDict[(tempmonoomDim, tempmonoomK)] +=  valueK*valueD
                end
            end
        end
    return EntryDict;
end



function RepresentativeFullElementPlusHalf(indexobject )
    P=indexobject[1]
    #determine t
    t=0;
    for Pi in P
        t+=size(Pi,1)
    end
    t-=1
    #sum of size(Pi,1) is t+1, we are in situation PlusHalf

    #println("P: ", P)
    Q=indexobject[2]
    #println("Q: ", Q)
    FilledKTableauxTuple = indexobject[3]
    FilledDTableauxTuple = indexobject[4]

    ### Make k-representative object
    ProductTableauVectorsWithSigns=[]
    for tauitableau in FilledKTableauxTuple
        TableauVectorsWithSigns =[];
        if (!isempty(tauitableau))
            RowTableaux = AllRowEquivalentTableaux(tauitableau)
            for rowtab in RowTableaux
                ColTableaux = AllColumnSignTableaux(rowtab)
                for coltab in ColTableaux
                    FillVector = coltab[1].fill;
                    #we combine the fillvector and the partition into a word of length t;
                    Sign = coltab[2];
                    TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (FillVector, Sign))
                end
            end
            ProductTableauVectorsWithSigns = TableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        end
    end 
    WordsKWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        FillVector= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word=zeros(Int,t+1)
        FirstSet = P[1]
        Word[FirstSet].=1;
        for symbol = 2:size(P,1)
            position = findall(x -> x.==symbol, FillVector)[1]
            Set = P[symbol];
            Word[Set].=position+1;  ##S_{k-1} acts on 2,....,k
        end
        push!(WordsKWithSigns,(Word, sign))
    end

    ############# MAKE D-OBJECT ###################
    #println("filledDtuple:", FilledDTableauxTuple)
    qiindex=1;
    ProductTableauVectorsWithSigns=[]
    for sigmaitableau in FilledDTableauxTuple
        Qi=Q[qiindex];
        lengthword = length(P[qiindex])
        TableauVectorsWithSigns =[];
        RowTableaux = AllRowEquivalentTableaux(sigmaitableau)

        for rowtab in RowTableaux
            ColTableaux = AllColumnSignTableaux(rowtab)
            for coltab in ColTableaux
                Word = zeros(Int,lengthword);
                if qiindex == 1
                    Word[Qi[1]].=1;
                end
                FillVector = coltab[1].fill;
                #we combine the fillvector and the partition into a word of length r_i;
                ri = maximum(FillVector)-1;
                for symbol = 2:ri+1
                    position = findall(x -> x.==symbol, FillVector)[1]
                    symboltranslation = qiindex==1 ? symbol : (symbol-1); 
                    Set = Qi[symboltranslation];
                    position = qiindex==1 ? position+1 : position  #if qiindex=1 we have that S_{d-1} acts on 2,..,d. Otherwise S_d acts on [d].
                    Word[Set].=position;
                end
                Sign = coltab[2];
                TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (Word, Sign))
            end
        end
        ProductTableauVectorsWithSigns = QiTableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        qiindex+=1;
    end
    WordsDWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        vectorslist= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word = zeros(Int,t+1);
        piindex=1;
        for Pi in P
            Word[Pi].=vectorslist[piindex]
            piindex+=1
        end
        push!(WordsDWithSigns,(Word, sign))
    end
    ########### END OF D-OBJECT ###########################

    return (WordsKWithSigns, WordsDWithSigns)
end



function RepresentativeColumnElementPlusHalf(indexobject )
    P=indexobject[1]
    #determine t
    t=0;
    for Pi in P
        t+=size(Pi,1)
    end
    t-=1
    #sum of size(Pi,1) is t+1, we are in situation PlusHalf

    #println("P: ", P)
    Q=indexobject[2]
    #println("Q: ", Q)
    FilledKTableauxTuple = indexobject[3]
    FilledDTableauxTuple = indexobject[4]

    ### Make k-representative object
    ProductTableauVectorsWithSigns=[]
    for tauitableau in FilledKTableauxTuple
        TableauVectorsWithSigns =[];
        if (!isempty(tauitableau))
            RowTableaux = AllRowEquivalentTableaux(tauitableau)
            for rowtab in RowTableaux
                    FillVector = rowtab.fill;
                    #we combine the fillvector and the partition into a word of length t;
                    Sign = 1;
                    TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (FillVector, Sign))
            end
            ProductTableauVectorsWithSigns = TableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        end
    end 
    WordsKWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        FillVector= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word=zeros(Int,t+1)
        FirstSet = P[1]
        Word[FirstSet].=1;
        for symbol = 2:size(P,1)
            position = findall(x -> x.==symbol, FillVector)[1]
            Set = P[symbol];
            Word[Set].=position+1;  ##S_{k-1} acts on 2,....,k
        end
        popfirst!(Word)  #word consists of [1,word of length t] here we remove the first "1", because it is also present in the row-element 
        push!(WordsKWithSigns,(Word, sign))
    end

    ############# MAKE D-OBJECT ###################
    #println("filledDtuple:", FilledDTableauxTuple)
    qiindex=1;
    ProductTableauVectorsWithSigns=[]
    for sigmaitableau in FilledDTableauxTuple
        Qi=Q[qiindex];
        lengthword = length(P[qiindex])
        TableauVectorsWithSigns =[];
        RowTableaux = AllRowEquivalentTableaux(sigmaitableau)

        for rowtab in RowTableaux
                Word = zeros(Int,lengthword);
                if qiindex == 1
                    Word[Qi[1]].=1;
                end
                FillVector = rowtab.fill;
                #we combine the fillvector and the partition into a word of length r_i;
                ri = maximum(FillVector)-1;
                for symbol = 2:ri+1
                    position = findall(x -> x.==symbol, FillVector)[1]
                    symboltranslation = qiindex==1 ? symbol : (symbol-1); 
                    Set = Qi[symboltranslation];
                    position = qiindex==1 ? position+1 : position  #if qiindex=1 we have that S_{d-1} acts on 2,..,d. Otherwise S_d acts on [d].
                    Word[Set].=position;
                end
                Sign = 1;
                TableauVectorsWithSigns=push!(TableauVectorsWithSigns, (Word, Sign))
        end
        ProductTableauVectorsWithSigns = QiTableauxVectorsProduct(ProductTableauVectorsWithSigns, TableauVectorsWithSigns)
        qiindex+=1;
    end
    WordsDWithSigns =[]
    for ProductVectorsWithSigns in ProductTableauVectorsWithSigns
        vectorslist= ProductVectorsWithSigns[1]
        sign= ProductVectorsWithSigns[2]
        Word = zeros(Int,t+1);
        piindex=1;
        for Pi in P
            Word[Pi].=vectorslist[piindex]
            piindex+=1
        end
        popfirst!(Word)
        push!(WordsDWithSigns,(Word, sign))
    end
    ########### END OF D-OBJECT ###########################

    return (WordsKWithSigns, WordsDWithSigns)
end


function TestFullFunctionPlusHalf( )
    TestMap = BlockGroottesFullProblemPlusHalf(4,4,1)

    #Key are the shapes Lambda, Value contains the indexobjects for the rows/columns of the block corresponding to Lambda
    for (key, value) in TestMap
        for indexobject in value
            display(RepresentativeColumnElementPlusHalf(indexobject ))
        end
    end
    println("einde zonder fouten :-)")
end

#TestFullFunctionPlusHalf( )
#TestFullFunction( )
#@time ReprSet, BlockSizes = generateRepresentativeSet(6,6)
#@time ReprColSet= generateRepresentativeColumnSet(6,6)
#@time Reduced = ReduceInnerProducts(ReprSet, ReprColSet)



#generateRepresentativeSetPlusHalf(6,5)
