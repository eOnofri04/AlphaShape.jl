include("../src/AlphaShape.jl")
using Plasm, LinearAlgebraicRepresentation, DataStructures
Lar = LinearAlgebraicRepresentation

filename = "examples/OBJ/teapot.obj";
V,EVs,FVs = Lar.obj2lar(filename)
Plasm.view(V,[[i] for i = 1:size(V,2)])
Plasm.view(V,EVs[1])
Plasm.view(V,FVs[1])

filename = "examples/OBJ/cat.obj";
V,EVs,FVs = Lar.obj2lar(filename)

Plasm.view(V,[[i] for i = 1:size(V,2)])
Plasm.view(V,EVs[1])
Plasm.view(V,FVs[1])

filename = "examples/OBJ/lowpolytree.obj";
V,EVs,FVs = Lar.obj2lar(filename)

Plasm.view(V,[[i] for i = 1:size(V,2)])

#prima dobbiamo riempire con i punti interni

AFL = Array{Int64,1}[]
axis = [1.,0.,0.]
tetraDict = DataStructures.Dict{Array{Array{Int64,1},1},Array{Int64,1}}()
DT = AlphaShape.DeWall(V,V,AFL,axis,tetraDict)
