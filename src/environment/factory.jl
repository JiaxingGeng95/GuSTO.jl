export Factory

mutable struct Factory{T<:AbstractFloat} <: Environment
  worldAABBmin::Vector{T}
  worldAABBmax::Vector{T}
  keepin_zones::Vector
  keepout_zones::Vector
  obstacle_set::Vector
end

function Factory{T}() where T
  worldAABBmin = -1000 .* ones(T,3) 
  worldAABBmax = 1000 .* ones(T,3)

  keepin_zones = Vector{HyperRectangle}(undef,0)
  push!(keepin_zones,
    HyperRectangle(Vec3f0(worldAABBmin),Vec3f0(worldAABBmax-worldAABBmin)))

  keepout_zones = Vector{GeometryTypes.GeometryPrimitive}(undef,0)

  obstacle_set = Vector{GeometryTypes.GeometryPrimitive}(undef,0)

  return Factory{T}(worldAABBmin, worldAABBmax, keepin_zones, keepout_zones, obstacle_set)
end
Factory(::Type{T} = Float64; kwargs...) where {T} = Factory{T}(; kwargs...)
