# α è un piano perpendicolare agli assi e che si sposta a metà del pointset,
# piano ortogonale ad ogni chiamata di dewall

"""
    MakeFirstWallSimplex(P::Lar.Points, axis::Array{Float64,1}, off::Float64)::Array{Int64,1}

The MakeFirstWallSimplex function selects the point p1 ∈ `P` nearest to the plane `α`. Then it selects a
second point p2 such that: (a) p2 is on the other side of α from p1 , and (b) p2 is the point in P with the
minimum Euclidean distance from p1 . Then, it seeks the point p3 at which the radius of the circum-circle
about 1-face (p1 , p2 ) and point p3 is minimized: the points (p1 , p2 , p3 ) are a 2-face of the DT(P). The
process continues in the same way until the required first d-simplex is built.
"""
function MakeFirstWallSimplex(P::Lar.Points, axis::Array{Float64,1}, off::Float64)::Array{Int64,1}

	d = size(P,1)+1 # dimension of upper_simplex
	indices = Int64[]

	coord = findall(x -> x == 1., axis)[1]
    Pminus,Pplus = AlphaShape.pointsetPartition(P, axis, off)

    #The first point of the face is the nearest to middle plane in negative halfspace.
    #for point in Pminus
    maxcoord = max( Pminus[coord,:]...)
    index = findall(x -> x == maxcoord, P[coord,:])[1]
    p1 = P[:,index]
	push!(indices,index)

    #The 2nd point of the face is the euclidean nearest to first point that is in the positive halfspace
    #for point in Pplus
    distance = [Lar.norm(p1-Pplus[:,i]) for i = 1:size(Pplus,2)]
    minDist = min(filter(p-> !isnan(p) && p!=0,distance)...)
    ind2 = findall(x -> x == minDist, distance)[1]
    p2 = Pplus[:, ind2]
    index = findall(x -> x == [p2...], [P[:,i] for i = 1:size(P,2)])[1]
	push!(indices,index)

    #The other points are that with previous ones builds the smallest hypersphere.

	simplexPoint = [p1,p2]
	for dim = length(simplexPoint)+1:d
		radius = [AlphaShape.foundAlpha([simplexPoint...,P[:,i]]) for i = 1:size(P,2)]
    	minRad = min(filter(p-> !isnan(p) && p!=0,radius)...)
    	index = findall(x->x == minRad, radius)[1]
    	p = P[:, index]
		@assert p ∉ simplexPoint  "FirstTetra, Planar dataset, unable to build first tetrahedron."
		push!(simplexPoint,p)
		push!(indices,index)
	end

    return sort(indices)
end

"""
	MakeSimplex(f::Array{Int64,1},P::Lar.Points)

Given a face f , the adjacent simplex can be identified by using the Delaunay simplex definition: all
the points p ∈ P are tested by checking the radius of the hypersphere which circumscribes p and the d
vertices of f . In the pseudo code in Figure 3 the function MakeSimplex implements the adjacent simplex
construction. The analysis of the points p ∈ P is limited by considering only those points which lie
in the outer halfspace with respect to face f (i.e. the halfspace which does not contain the previously
generated simplex that contains the face f ). MakeSimplex selects the point which minimizes the function
dd (Delaunay distance):
with r and c the radius and the center of the circumsphere around f and p. The outer halfspace associated
with f contains no point iff, face f is part of the Convex Hull of the pointset P ; in this case the algorithm
correctly returns no adjacent simplex and, in this case only, M akeSimplex returns null.
"""
function MakeSimplex(f::Array{Int64,1},P::Lar.Points)
	#DA MIGLIORARE
	df = length(f) 	#dimension face
	d = size(P,1)+1 #dimension upper_simplex
	axis = Lar.cross(P[:,f[2]]-P[:,f[1]],P[:,f[3]]-P[:,f[1]])
	off = Lar.dot(axis,P[:,f[1]])
	Pminus,Pplus = AlphaShape.pointsetPartition(P,axis,off)

	simplexPoint = [P[:,v] for v in f]

	if !isempty(Pminus)
		for dim = df+1:d
			radius = [AlphaShape.foundAlpha([simplexPoint...,Pminus[:,i]]) for i = 1:size(Pminus,2)]
	    	minRad = min(filter(p-> !isnan(p) && p!=0 && p!=Inf,radius)...)
	    	ind = findall(x->x == minRad, radius)[1]
	    	p = Pminus[:, ind]
			@assert p ∉ simplexPoint " Planar dataset"
		    index = findall(x -> x == [p...], [P[:,i] for i = 1:size(P,2)])[1]
			t1 = sort([f...,index])
		end
	else t1 = nothing
	end

	if !isempty(Pplus)
		for dim = df+1:d
			radius = [AlphaShape.foundAlpha([simplexPoint...,Pplus[:,i]]) for i = 1:size(Pplus,2)]
	    	minRad = min(filter(p-> !isnan(p) && p!=0 && p!=Inf,radius)...)
	    	ind = findall(x->x == minRad, radius)[1]
	    	p = Pplus[:, ind]
			@assert p ∉ simplexPoint " Planar dataset"
		    index = findall(x -> x == [p...], [P[:,i] for i = 1:size(P,2)])[1]
			t2 = sort([f...,index])
		end
	else t2 = nothing
	end

	return t1,t2
end

"""
	Update(element,list)

Return update list: if element is in list, delete element, altrimenti push the element
"""
function Update(element,list)
    if element ∈ list
        setdiff!(list, [element])
    else push!(list,element)
	end
	return list
end

"""
	DeWall(P::Lar.Points,AFL::Array{Array{Int64,1},1},axis::Array{Float64,1})::Array{Array{Int64,1},1}

 Given a set of points this function returns the tetrahedra list
 of the Delaunay triangulation.
"""
function DeWall(P::Lar.Points,AFL::Array{Array{Int64,1},1},axis::Array{Float64,1})::Array{Array{Int64,1},1}

    @assert size(P,1) == 3  #in R^3
    @assert size(P,2) > 1 #almeno 2 punti

    # 0 - initialization of list
    AFL_α = Array{Int64,1}[]      # (d-1)faces intersected by plane α;
    AFLplus = Array{Int64,1}[]    # (d-1)faces completely contained in PosHalfspace(α);
    AFLminus = Array{Int64,1}[]   # (d-1)faces completely contained in NegHalfspace(α).
    DT = Array{Int64,1}[]

    # 1 - Select the splitting plane α; defined by axis and an origin point `off`
    off = AlphaShape.SplitValue(P,axis)

    # 2 - construct two subsets P− and P+ ;
    Pminus,Pplus = AlphaShape.pointsetPartition(P, axis, off)

	# 3 - construct first tetrahedra if necessary
    if isempty(AFL)
        t = AlphaShape.MakeFirstWallSimplex(P,axis,off) #ToDo da migliorare
        AFL = AlphaShape.Faces(t) # d-1 - faces of t
        push!(DT,t)
    end

    for f in AFL
		inters = AlphaShape.Intersect(P, f, axis, off)
        if inters == 0 #intersected by plane α
            push!(AFL_α,f)
        elseif inters == -1 #in NegHalfspace(α)
            push!(AFLminus,f)
        elseif inters == 1 #in PosHalfspace(α)
            push!(AFLplus,f)
        end
    end

	# 4 - construct Sα, simplexWall
    while !isempty(AFL_α) #The Sα construction terminates when the AFL_α is empty
        f = popfirst!(AFL_α)
        T = AlphaShape.MakeSimplex(f,P) #ne trova 2 devo prendere quello che non sta in DT
		for t in T
			if t != nothing && t ∉ DT
	            push!(DT,t)
	            for ff in setdiff(AlphaShape.Faces(t),[f])
					inters = AlphaShape.Intersect(P, ff, axis, off)
	                if inters == 0
	                    AFL_α = AlphaShape.Update(ff,AFL_α)
	                elseif inters == -1
	                    AFLminus = AlphaShape.Update(ff,AFLminus)
	                elseif inters == 1
	                    AFLplus = AlphaShape.Update(ff,AFLplus)
	                end
	            end
	        end
		end
    end

    newaxis = circshift(axis,1)
    if !isempty(AFLminus)
        DT = union(DT,AlphaShape.DeWall(Pminus,AFLminus,newaxis))
    end
    if !isempty(AFLplus)
        DT = union(DT,AlphaShape.DeWall(Pplus,AFLplus,newaxis))
    end
    return DT
end
