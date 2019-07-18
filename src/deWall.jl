#===============================================================================
#
#	src/deWall.jl
#
#	This File Contains:
#	 - delaunayWall(
#			P::Lar.Points,
#			ax = 1,
#			AFL = Array{Int64,1}[]
#		)::Lar.Cells
#
#	 - firstDeWallSimplex(
#			P::Lar.Points,
#			ax::Int64,
#			off::Float64
#		)::Array{Int64,1}
#
#	 - recursiveDelaunayWall(
# 			P::Lar.Points,
# 			tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
# 			AFL::Array{Array{Int64,1},1},
# 			ax::Int64,
# 			off::Float64,
# 			positive::Bool;
# 			DEBUG = false
# 		)::Lar.Cells
#
#	 - updateAFL!(
#			P::Lar.Points
#			new::Array{Int64,1}[],
#			AFLα = Array{Int64,1}[],
#			AFLplus = Array{Int64,1}[],
#			AFLminus = Array{Int64,1}[],
#			ax::Int64, off::Float64
#		)::Bool
#
#	 - updatelist!(
#			list,
#			element
#		)::Bool
#
#	 - updateTetraDict!(
#			P::Lar.Points,
#			tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
#			AFL::Array{Array{Int64,1},1},
#			σ::Array{Int64,1}
#		)
#
===============================================================================#

"""
	delaunayWall(P::Lar.Points, ax = 1, AFL = Array{Int64,1}[])::Lar.Cells

Return the Delaunay Triangulation of sites `P` via Delaunay Wall algorithm.
The optional argument `ax` specify on wich axis it will build the Wall.
The optional argument `AFL` is used in recursive call.
"""

function delaunayWall(
		P::Lar.Points,
		ax = 1,
		AFL = Array{Int64,1}[],
		tetraDict = DataStructures.Dict{Array{Int64,1},Array{Float64,1}}()
	)::Lar.Cells

	DEBUG = false
	if DEBUG println("DEBUG mode on") end

	# 0 - Data Reading and Container definition
	dim, n = size(P)			# space dimenson and number of points
	DT = Array{Int64,1}[]		# Delaunay Triangulation
	AFLα = Array{Int64,1}[]		# (d-1)faces intersecting the Wall
	AFLplus = Array{Int64,1}[]  # (d-1)faces in positive Wall half-space
	AFLminus = Array{Int64,1}[] # (d-1)faces in positive Wall half-space
	off = AlphaStructures.findMedian(P, ax)

	# 1 - Determine first simplex (if necessary)
	if isempty(AFL)
		σ = sort(AlphaStructures.firstDeWallSimplex(P, ax, off))
		# Update the DT and the Tetra Dictionary
		push!(DT, σ)
		AFL = AlphaStructures.simplexFaces(σ)
		AlphaStructures.updateTetraDict!(P, tetraDict, AFL, σ)
	end

	# 2 - Build `AFL*` according to the axis `ax` with contant term `off`
	AlphaStructures.updateAFL!(
		P, AFL, AFLα, AFLplus, AFLminus, ax, off
	)

	# 4 - Build simplex Wall
	while !isempty(AFLα)
		face = AFLα[1]
		# Get corresponding simplex to `face`
		oppoint = nothing
		for (cell, vertex) in tetraDict
			if face == cell
				oppoint = vertex
				break
			end
		end
		# Find the points in the other halfspace with respect to σ.
		# If σ == nothing then all the points are suitable
		if oppoint == nothing
			Pselection = setdiff([i for i = 1 : n], face)
		else
			Pselection =
				AlphaStructures.oppositeHalfSpacePoints(P, face, oppoint)
		end
		# If there are no such points than the face is part of the convex hull.
		if isempty(Pselection)
			# push!(CH, face)
			@assert AlphaStructures.updatelist!(AFLα, face) == false "ERROR:
				Something unespected happends while trying to remove a face."
		else
			# Find the Closest Point in the other halfspace with respect to σ.
			idxbase =
				AlphaStructures.findClosestPoint(P[:, face], P[:, Pselection])
			if isnothing(idxbase)
				# push!(CH, face)
				@assert AlphaStructures.updatelist!(AFLα, face) == false "ERROR:
					Something unespected happends while removing a face."
			else
				newidx = Pselection[idxbase]
				# Build the new simplex and update the Dictionary
				σ = sort([face; newidx])
				ok = true
				if ok
					push!(DT, σ)
					AFL = AlphaStructures.simplexFaces(σ)
					AlphaStructures.updateTetraDict!(P, tetraDict, AFL, σ)
					# Split σ's Faces according to semi-spaces
					AlphaStructures.updateAFL!(
						P, AFL, AFLα, AFLplus, AFLminus, ax, off
					)
				else
					@assert AlphaStructures.updatelist!(AFLα, face) == false "ERROR:
						Something unespected happends while removing a face."
					println("Discarded ", σ)
				end
			end
		end
	end

	# 5 - Change the axis `ax` and repeat until there are no faces but exposed.
	#      A.K.A. Divide & Conquer phase.
	newaxis = mod(ax, dim) + 1
	if !isempty(AFLminus)
		union!(DT, recursiveDelaunayWall(
			P, tetraDict, AFLminus, newaxis, off, false; DEBUG = DEBUG
		))
	end
	if !isempty(AFLplus)
		union!(DT, recursiveDelaunayWall(
			P, tetraDict, AFLplus, newaxis, off, true; DEBUG = DEBUG
		))
	end

	return DT
end

#-------------------------------------------------------------------------------

"""
function firstDeWallSimplex(
		P::Lar.Points,
		ax::Int64,
		off::Float64
	)::Array{Int64,1}

Returns the indices array of the points in `P` that form the first thetrahedron
built over the Wall if the `ax` axes with contant term `off`.

# Examples
```jldoctest

julia> V = [
	0.0 1.0 0.0 0.0 2.0
	0.0 0.0 1.0 0.0 2.0
	0.0 0.0 0.0 1.0 2.0
];

julia> firstDeWallSimplex(V, 1, AlphaStructures.findMedian(V,1))
4-element Array{Int64,1}:
 1
 2
 3
 4

```
"""

function firstDeWallSimplex(
		P::Lar.Points,
		ax::Int64,
		off::Float64
	)::Array{Int64,1}

	dim = size(P, 1)
    n = size(P, 2)

    # the first point of the simplex is the one with coordinate `ax` maximal
    #  such that it is less than `off` (closer to α from minus)
	Pselection = findall(x -> x < off, P[ax, :])
	# it gives an error if no point are less than `off`
	#  in fact it means that all the points are located on the median,
	#  with respect to `ax`.
	@assert !isempty(Pselection) "ERROR: not able to build the first Delaunay
		dimplex; all the points have the same `ax` coordinate."
    newidx = Pselection[findmax(P[ax, Pselection])[2]]
    # indices will store the indices of the simplex ...
    indices = [newidx]                      #Array{Int64,1}
    # ... and `Psimplex` will store the corresponding points
    Psimplex = P[:, newidx][:,:]    #Array{Float64,2}

    # the second point must be seeken across those with coordinate `ax`
    #  grater than `off`
    Pselection = findall(x -> x > off, P[ax, :])

    for d = 1 : dim
		idxbase = AlphaStructures.findClosestPoint(Psimplex, P[:, Pselection])
		@assert !isnothing(idxbase) "ERROR:
			not able to determine first Delaunay Simplex"
        newidx = Pselection[idxbase]
        indices = [indices; newidx]
        Psimplex = [Psimplex P[:, newidx]]
        Pselection = [i for i = 1 : n if i ∉ indices]
    end

    # Correctness check
	radius, center = AlphaStructures.findRadius(Psimplex, true)
    for i = 1 : n
		@assert Lar.norm(center - P[:, i]) >= radius "ERROR:
			Unable to find first Simplex."
	end

	return indices
end

#-------------------------------------------------------------------------------

"""
	recursiveDelaunayWall(
		P::Lar.Points,
		tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
		AFL::Array{Array{Int64,1},1},
		ax::Int64,
		off::Float64,
		positive::Bool;
		DEBUG = false
	)::Lar.Cells

Utility function that prepeares the Divide phase for Delaunay Wall.
Returns the Delaunay Triangulation for the positve or negative subspace of `P`
(according to `positive`) determined by the hyperplane with normal `ax` and
constant term `off`.
"""
function recursiveDelaunayWall(
		P::Lar.Points,
		tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
		AFL::Array{Array{Int64,1},1},
		ax::Int64,
		off::Float64,
		positive::Bool;
		DEBUG = false
	)::Lar.Cells

	Psubset = findall(x -> x > off == positve, P[ax, :])
	if DEBUG println("$positive in") end
	DT = AlphaStructures.delaunayWall(
			P[:, Psubset],
			ax,
			[[findall(Psubset.==p)[1] for p in σ] for σ in AFL],
			Dict([
				[findall(Psubset.==p)[1] for p in k] => v
				for (k,v) in tetraDict
					if k ⊆ Psubset
			])
		)
	if DEBUG println("+ out") end

	return [[Psubset[i] for i in σ] for σ in DT]
end

#-------------------------------------------------------------------------------

"""
	updateAFL!(
		P::Lar.Points
		new::Array{Int64,1}[],
		AFLα = Array{Int64,1}[],
		AFLplus = Array{Int64,1}[],
		AFLminus = Array{Int64,1}[],
		ax::Int64, off::Float64
	)::Bool

Modify the `AFL*` lists of faces by adding to them the faces inside `new`
(that refers to the points `P`) according to their position with respect
to the axis defined by the normal direction `ax` and the contant term `off`.
The function returns a Bool value that states if the operation was succesfully.
"""
function updateAFL!(
		P::Lar.Points,
		newσ::Array{Array{Int64,1},1},
		AFLα::Array{Array{Int64,1},1},
		AFLplus::Array{Array{Int64,1},1},
		AFLminus::Array{Array{Int64,1},1},
		ax::Int64, off::Float64
	)::Bool

	for face in newσ
		inters = AlphaStructures.planarIntersection(P, face, ax, off)
    	if inters == 0 # intersected by plane α
			AlphaStructures.updatelist!(AFLα, face)
		elseif inters == -1 # in NegHalfspace(α)
        	AlphaStructures.updatelist!(AFLminus, face)
    	elseif inters == 1 # in PosHalfspace(α)
        	AlphaStructures.updatelist!(AFLplus, face)
    	else
			return false
		end
	end

	return true

end

#-------------------------------------------------------------------------------

"""
	updatelist!(list, element)::Bool

If `element` is in `list` then it is removed (returns `false`);
If `element` is not in `list` then it is added (returns `true`).

# Examples
```jldoctest
julia> list = [[1, 2, 3, 4], [2, 3, 4, 5]]
2-element Array{Array{Int64,1},1}:
 [1, 2, 3, 4]
 [2, 3, 4, 5]

julia> updatelist!(list, [1, 2, 4, 5])
true

julia> list
3-element Array{Array{Int64,1},1}:
 [1, 2, 3, 4]
 [2, 3, 4, 5]
 [1, 2, 4, 5]

julia> updatelist!(list, [1, 2, 4, 5])
false

julia> list
2-element Array{Array{Int64,1},1}:
 [1, 2, 3, 4]
 [2, 3, 4, 5]

```
"""

function updatelist!(list, element)::Bool
	if element ∈ list
		setdiff!(list, [element])
		return false
	else
		push!(list, element)
		return true
	end
end

"""
	updateTetraDict!(
		P::Lar.Points,
		tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
		AFL::Array{Array{Int64,1},1},
		σ::Array{Int64,1}
	)

Update the content of `tetraDict` by adding the outer points of the faces of `σ`
in the dictionary.
"""
function updateTetraDict!(
		P::Lar.Points,
		tetraDict::DataStructures.Dict{Array{Int64,1},Array{Float64,1}},
		AFL::Array{Array{Int64,1},1},
		σ::Array{Int64,1}
	)
	for cell in AFL
		point = setdiff(σ, cell)
		@assert length(point) == 1 "Error during update of TetraDict"
		tetraDict[ cell ] = P[:, point[1]]
	end
end
