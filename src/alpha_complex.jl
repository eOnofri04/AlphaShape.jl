using DataStructures,Combinatorics

"""
	delaunayTriangulation(V::Lar.Points)

Return highest level simplices of Delaunay triangulation.
"""
function delaunayTriangulation(V::Lar.Points)
	dim = size(V, 1)
	@assert dim > 0 "Error: V do not contains points."
	@assert dim < 4 "Error: Function not yet Programmed."

	if dim == 1
		vertices = vcat(V...)
		p = sortperm(vertices)
		upper_simplex = [[p[i],p[i+1]] for i=1:length(p)-1]

	elseif dim == 2
		vertices = convert(Array{Float64,2},V')
		points_map = Array{Int64,1}(collect(1:1:size(vertices)[1]))
		@assert size(vertices, 1) > 3
		upper_simplex = Triangle.basic_triangulation(vertices, points_map)

	elseif dim == 3
		# To Do
	end

	sort!.(upper_simplex)

	return sort(upper_simplex)
end

"""
	found_alpha(T::Array{Array{Float64,1},1})::Float64

Return the value of the circumball radius of the given points.
If three or more points are collinear it returns `Inf`.
"""
function found_alpha(T::Array{Array{Float64,1},1})::Float64
	@assert length(T) > 0 "ERROR: at least one points is needed."
	dim = length(T[1])
	@assert dim < 4 "Error: Function not yet Programmed."
	k = length(T) - 1
	@assert k <= dim +1 "ERROR: too much points."

	if k == 1
		#for each dimension
		alpha = round(Lar.norm(T[1]-T[2])/2., sigdigits = 14) #approssimazione dei numeri

	elseif k == 2
        	# radius of circle from 3 points in R^n
			a = Lar.norm(T[1] - T[2])
			b = Lar.norm(T[2] - T[3])
			c = Lar.norm(T[3] - T[1])
			s = (a + b + c) / 2.
			area = sqrt(s * (s - a) * (s - b) * (s - c))
			alpha = round(a * b * c / (4. * area), sigdigits = 14) #approssimazione dei numeri

	elseif k == 3
		if dim == 3
			#radius of the circumsphere of a tetrahedron
			#https://www.ics.uci.edu/~eppstein/junkyard/circumcenter.html
			num = Lar.norm(Lar.norm(T[4]-T[1])^2*Lar.cross(T[2]-T[1],T[3]-T[1])+
				Lar.norm(T[3]-T[1])^2*Lar.cross(T[4]-T[1],T[2]-T[1])+
				Lar.norm(T[2]-T[1])^2*Lar.cross(T[3]-T[1],T[4]-T[1]))
			M = [T[2]-T[1] T[3]-T[1] T[4]-T[1]]
			den = abs(2*Lar.det(M))
			alpha = round(num/den, sigdigits = 14) #approssimazione dei numeri
		end
	end

	return alpha
end

"""
	vertex_in_circumball(T::Array{Array{Float64,1},1}, alpha_char::Float64, point::Array{Float64,2})

Determine if a point is inner of the circumball determined by `T` points and radius `alpha_char`.

"""
function vertex_in_circumball(T::Array{Array{Float64,1},1}, alpha_char::Float64, point::Array{Float64,2})::Bool
	@assert length(T) > 0 "ERROR: at least one points is needed."
	dim = length(T[1])
	@assert dim < 4 "Error: Function not yet Programmed."
	k = length(T)-1

	if k == 1
		#for each dimension
		center = (T[1] + T[2])/2

	elseif k == 2
		if dim == 3
			#https://www.ics.uci.edu/~eppstein/junkyard/circumcenter.html
			#circumcenter of a triangle in R^3
			num = Lar.norm(T[3]-T[1])^2*Lar.cross(Lar.cross(T[2]-T[1],T[3]-T[1]),T[2]-T[1])+
					Lar.norm(T[2]-T[1])^2*Lar.cross(T[3]-T[1],Lar.cross(T[2]-T[1],T[3]-T[1]))
			den = 2*Lar.norm(Lar.cross(T[2]-T[1],T[3]-T[1]))^2
			center = T[1] + num/den
		end
	end

	return Lar.norm(point - center) <= alpha_char
end

"""
	contains(sup_simpl::Array{Int64,1}, simpl::Array{Int64,1})::Bool

Determine if a `d`-simplex is in a `d+1`-simplex.
"""
function contains(sup_simpl::Array{Int64,1}, simpl::Array{Int64,1})::Bool
	#Esiste issubset che fa la stessa cosa
	flag = true
	for point in simpl
		if (point ∉ sup_simpl)
			flag = false
		end
	end
	return flag
end

"""
	AlphaFilter(V::Lar.Points)

Return ordered collection of pairs `(alpha charatteristic, complex)`.

# Examples
```jldoctest
julia> V = [1. 2. 1. 2.; 0. 0. 1. 2. ]
2×4 Array{Float64,2}:
 1.0  2.0  1.0  2.0
 0.0  0.0  1.0  2.0

julia> AlphaShape.AlphaFilter(V)
DataStructures.SortedDict{Float64,Array{Array{Int64,1},N} where N,Base.Order.ForwardOrdering} with 5 entries:
  0.0      => Array{Int64,1}[[1], [2], [3], [4]]
  0.5      => Array{Int64,1}[[1, 2], [1, 3]]
  0.707107 => Array{Int64,1}[[2, 3], [3, 4], [1, 2, 3]]
  1.0      => Array{Int64,1}[[2, 4], [2, 3, 4]]

```
"""
function AlphaFilter(V::Lar.Points)::DataStructures.SortedDict{}

	dim = size(V, 1)

	# 1 - Delaunay triangulation of ``V``

	Cells = [Array{Array{Int64,1},1}() for i=1:dim]  #Generalize definition
	Cells[dim] = delaunayTriangulation(V)

	# 2 - 1..d-1 Cells Construction
	# Cells[d] = Array{Int64}[]
	for d = dim-1 : -1 : 1
		for cell in Cells[dim]
			# It gives back combinations in natural order
			newCells = collect(Combinatorics.combinations(cell, d+1))
			push!(Cells[d], newCells...)
		end
		Cells[d] = unique(sort(Cells[d]))
	end

	# 3 - Evaluate Circumballs Radius

	alpha_char = [ zeros(length(Cells[i])) for i in 1 : dim ]
	for d = 1 : dim
		for i = 1 : length(Cells[d]) # simplex in Cells[d]
			simplex = Cells[d][i]
			T = [ V[:, v] for v in simplex ] #coordinates of the points of the simplex
			alpha_char[d][i] = found_alpha(T);
		end
	end

	# 4 - Evaluate Charatteristical Alpha

	for d = dim-1 : -1 : 1
		for i = 1 : length(Cells[d])    # simplex in Cells[d]
			simplex = Cells[d][i]
			for j = 1 : length(Cells[d+1])  # up_simplex in Cells[d+1]
				up_simplex = Cells[d+1][j]
				if issubset(simplex, up_simplex) #contains(up_simplex, simplex)
					point = V[:, setdiff(up_simplex, simplex)]
					T = [ V[:, v] for v in simplex ]
					if vertex_in_circumball(T, alpha_char[d][i], point)
						alpha_char[d][i] = alpha_char[d+1][j]
					end
				end
			end
		end
	end

	# 5 - Sorting Complex by Alpha
	filtration = DataStructures.SortedDict{Float64,Array{Array{Int64,1}}}()

	#each point => alpha_char = 0.
	filtration[0.] = [[i] for i=1:size(V,2)]

	for d = 1 : dim
		for i = 1 : length(Cells[d])
			if haskey(filtration, alpha_char[d][i]) #if dict has key => push
				push!(filtration[alpha_char[d][i]], Cells[d][i])
			else
				filtration[alpha_char[d][i]] = [Cells[d][i]] #if dict has no key => new pair
			end
		end
	end

	return filtration
end


"""
	AlphaSimplex(V::Lar.Points, filtration::DataStructures.SortedDict{}, alphaValue = 0.02)

Return collection of all `d`-simplex, for `d ∈ [0,dimension]`, with characteristic alpha less than a given value.
"""
function AlphaSimplex(V::Lar.Points, filtration::DataStructures.SortedDict{}, alphaValue = 0.02)

	dim = size(V, 1)
	simplexCollection = [ Array{Array{Int64,1},1}() for i=1:dim+1 ] #[VV,EV,FV,CV,...]

	for key in collect(keys(filtration))
		if key <= alphaValue
			for i = 1:length(filtration[key])
				push!( simplexCollection[length(filtration[key][i])], filtration[key][i] )
			end
		end
	end

	return simplexCollection
end
