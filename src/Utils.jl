# James W. Barnett
# jbarnet4@tulane.edu
# Some general purpose functions related to processing
# Gromacs files

module Utils

export pbc, 
       dih_angle,
	   bond_angle,
       rdf,
       prox_rdf,
	   box_vol,
       dist,
       dist2

# Adjusts for periodic boundary condition. Input is a three-dimensional
# vector (the position) and the box ( 3 x 3 Array). A 3d vector is returned.
function pbc(a::Array{Float32,1},box::Array{Float32,2}) 

    b = Array(Float64,3)
	box_inv = Array(Float64,3)
	shift = Float64

    box_inv[1] = 1.0/box[1,1]
    box_inv[2] = 1.0/box[2,2]
    box_inv[3] = 1.0/box[3,3]

    # z
    shift = iround(a[3] * box_inv[3])
    b[3] = a[3] - box[3,3] * shift
    b[2] = a[2] - box[3,2] * shift
    b[1] = a[1] - box[3,1] * shift

    # y
    shift = iround(a[2] * box_inv[2])
    b[2] = a[2] - box[2,2] * shift
    b[1] = a[1] - box[2,1] * shift

    # x
    shift = iround(a[1] * box_inv[1])
    b[1] = a[1] - box[1,1] * shift

	return b

end

# Sometimes we need to pass a float64 to the above function.
function pbc(a::Array{Float64,1},box::Array{Float32,2})
    return pbc(float32(a),box)
end

# Calculates the distance squared between two atoms
function dist2(gmx,frame::Int,atomi::Int,atomj::Int,grpi::String,grpj::String)
    dr = Array(Float32,3)
    dr = gmx.x[grpi][frame][:,atomi] - gmx.x[grpj][frame][:,atomj]
    dr = pbc(dr,gmx.box[frame])
    r2 = dot(dr,dr)
    return r2
end

# Also gets the distance squared with the arguments being the two vectors of the
# atoms and the box.
function dist2(atomi::Array{Float32,1},atomj::Array{Float32,1},box::Array{Float32,2})
    dr = Array(Float32,3)
    dr = atomi - atomj
    dr = pbc(dr,box)
    r2 = dot(dr,dr)
end

# Calculates the distance between two atoms
function dist(gmx,frame::Int,atomi::Int,atomj::Int,grpi::String,grpj::String)
    return sqrt(dist2(gmx,frame,atomi,atomj,grpi,grpj))
end

function dist(atomi::Array{Float32,1},atomj::Array{Float32,1},box::Array{Float32,2})
    return sqrt(dist2(atomi,atomj,box))
end

# Returns bond angle using the input of three atoms' coordinates. Angle
# is in radians
function bond_angle(i::Array{Float32,1},j::Array{Float32,1},
                    k::Array{Float32,1},box::Array{Float32,2})

    bond1 = Array(Float64,3)
    bond2 = Array(Float64,3)

    bond1 = j - i
    bond1 = pbc(bond1,box)

    bond2 = j - k
    bond2 = pbc(bond2,box)

    bond1mag = sqrt(dot(bond1,bond1))
    bond2mag = sqrt(dot(bond2,bond2))

    angle = acos(dot(bond1,bond2)/(bond1mag * bond2mag))

    return angle

end

function bond_angle(a::Array{Float32,2},box::Array{Float32,2})

    angle = Array(Float64,size(a,2)-2)

	for i in 1:size(a,2)-2
		angle[i] = bond_angle(a[:,i],a[:,i+1],a[:,i+2],box)
	end

	return angle

end

bond_angle(gmx,group::String,frame::Int) = bond_angle(gmx.x[group][frame],gmx.box[frame])

# Cycles through all frames
function bond_angle(f::Array{Any,1},box::Array{Any,1})


    angles = Array(Float64,(size(f[1],2)-2,1),size(f,1))

	for i in 1:size(f,1)

		angles[:,i] = bond_angle(f[i],box[i])

	end

    return angles

end

# Alternative call to cycle through frames.
bond_angle(gmx,group::String) = bond_angle(gmx.x[group],gmx.box)

#= 
   Function calculates the torsion / dihedral angle from four atoms'
   positions. Source: Blondel and Karplus, J. Comp. Chem., Vol. 17, No. 9, 1
   132-1 141 (1 996). Note that it returns in radians.
=#
function dih_angle(i::Array{Float32,1}, j::Array{Float32,1},
                   k::Array{Float32,1}, l::Array{Float32,1},
                   box::Array{Float32,2})

    H = Array(Float64,3)
    G = Array(Float64,3)
    F = Array(Float64,3)
    A = Array(Float64,3)
    B = Array(Float64,3)
    cross_BA = Array(Float64,3)

    H = k - l
    H = pbc(H,box)

    G = k - j
    G = pbc(G,box)
        
    F = j - i
    F = pbc(F,box)

    # Cross products
    A = cross(F,G)
    B = cross(H,G)
    cross_BA = cross(B,A)

    Amag = sqrt(dot(A,A))
    Bmag = sqrt(dot(B,B))
    Gmag = sqrt(dot(G,G))

    sin_phi = dot(cross_BA,G)/(Amag * Bmag * Gmag)
    cos_phi = dot(A,B)/(Amag * Bmag)

    #The torsion / dihedral angle, atan2 takes care of the sign
    # Argument 1 determines the sign
    phi = atan2(sin_phi,cos_phi)

    return phi

end

# Cycles through sequence of dihedral angles
function dih_angle(a::Array{Float32,2},box::Array{Float32,2})

    angle = Array(Float64,size(a,2)-3)

	for i in 1:size(a,2)-3

		angle[i] = dih_angle(a[:,i],a[:,i+1],a[:,i+2],a[:,i+3],box)

	end

	return angle

end

dih_angle(gmx,group::String,frame::Int) = dih_angle(gmx.x[group][frame],gmx.box[frame])

# Cycles through all frames
function dih_angle(f::Array{Any,1},box::Array{Any,1})


    angles = Array(Float64,(size(f[1],2)-3,size(f,1)))

	for i in 1:size(f,1)
		angles[:,i] = dih_angle(f[i],box[i])
	end

    return angles

end

dih_angle(gmx,group::String) = dih_angle(gmx.x[group],gmx.box)

function box_vol(box::Array{Float32,2})

    vol = (box[1,1] * box[2,2] * box[3,3] +
           box[1,2] * box[2,3] * box[3,1] +
           box[1,3] * box[2,1] * box[3,2] - 
           box[1,3] * box[2,2] * box[3,1] +
           box[1,2] * box[2,1] * box[3,3] +
           box[1,1] * box[2,3] * box[3,2] )

    return vol

end

function bin_rdf(g,atom_i,atom_j,box,nbins::Int,bin_width::Float64,r_excl2::Float64)

    dx = atom_i - atom_j
    dx = pbc(float32(dx),box)
    r2 = dot(dx,dx)
    if (r2 > r_excl2) then
        ig = iround(ceil(sqrt(r2)/bin_width))
        if ig <= nbins
            g[ig] += 1.0
        end
    end

    return g

end 

function normalize_rdf(g,gmx,nbins::Int,bin_width::Float64,group1::String,group2::String)

    bin_vols = zeros(Float64, nbins)
    for i in 1:nbins
        r = float(i)  + 0.5
        bin_vol = r^3 - (r-1.0)^3
        bin_vol *= 4.0/3.0 * pi * (bin_width)^3 
		# TODO: only works if we have a constant volume with a cubic box
        if group1 == group2
            g[i] *= float64(box_vol(gmx.box[1])) / ( (gmx.natoms[group1] - 1) * gmx.natoms[group2] * bin_vol * gmx.no_frames) 
        else
            g[i] *= float64(box_vol(gmx.box[1])) / ( gmx.natoms[group1] * gmx.natoms[group2] * bin_vol * gmx.no_frames) 
        end
    end

    bin = Array(Float64,size(g,1))

    for i in 1:size(g,1)
        bin[i] = float(i) * bin_width
    end

    return bin,g

end

function do_rdf_binning(g,gmx,nbins::Int,bin_width::Float64,r_excl2::Float64,group1::String,group2::String)

    for frame in 1:gmx.no_frames

        if frame % 1000 == 0
		    print(char(13),"Binning frame: ",frame)
        end

        for i in 1:gmx.natoms[group1]

            atom_i = gmx.x[group1][frame][:,i]

            for j in 1:gmx.natoms[group2]

                atom_j = gmx.x[group2][frame][:,j]

                bin_rdf(g,atom_i,atom_j,gmx.box[frame],nbins,bin_width,r_excl2)

            end

        end

    end 

    return g

end

# Radial distribution function
# TODO: this is only for a constant volume cubic box
function rdf(gmx,group1::String,group2::String,bin_width=0.002::Float64,r_excl=0.1::Float64)

    println("WARNING: this function only works for a constant volume cubic box.")
    r_excl2 = r_excl^2

    nbins =  iround( gmx.box[1][1,1] / (2.0 * bin_width) )

    g = zeros(Float64,nbins)

    g = do_rdf_binning(g,gmx,nbins,bin_width,r_excl2,group1,group2)

    println(char(13),"Binning complete.        ")
    g = normalize_rdf(g,gmx,nbins,bin_width,group1,group2)

    return g

end

function rdf(gmx,group1::String,bin_width=0.002::Float64,r_excl=0.1::Float64)

    g = rdf(gmx,group1,group1,bin_width,r_excl)

    return g

end

end
