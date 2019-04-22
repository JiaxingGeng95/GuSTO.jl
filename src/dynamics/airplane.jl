export Airplane
export init_traj_straightline, init_traj_feasible_sos, init_traj_line_sos

mutable struct Airplane <: DynamicsModel
  # state: (x,y,z,ψ,v,γ,ϕ,α)
  # pos- xyz, heading- ψ, speed- v, flight path angle- γ, roll- ϕ, angle of attack- α,
  # control: (u_acc, u_ϕ_d, u_α_d)
  x_dim
  u_dim

  x_min
  x_max

  goal_min
  goal_max

  u_min
  u_max

  clearance

  f::Vector
  A::Vector
  B
end
function Airplane(robot::Plane)
  x_dim,u_dim = 8,3

  x_min = [0.;0;0]
  x_max = [120; 120; 28]
  goal_min = [x_max[1:2]; 15] - [10; 10; 10]
  goal_max = x_max 
  
  u_max = [robot.acc_lim; robot.ϕ_d_lim; robot.α_d_lim]
  u_min = -u_max
  clearance = 25. 
  return Airplane(x_dim, u_dim, x_min, x_max, goal_min, goal_max, u_min, u_max, clearance, [], [], [])
end

function SCPParam(model::Airplane, fixed_final_time::Bool)
  convergence_threshold = 0.1

  SCPParam(fixed_final_time, convergence_threshold)
end

function SCPParam_GuSTO(model::Airplane)
  # Straight line in workspace 
  Δ0 = 10000. 
  ω0 = 1.
  ω_max = 100.
  ε = 1.
  ρ0 = 0.1
  ρ1 = 0.4
  β_succ = 2. 
  β_fail = 0.5
  γ_fail = 5. 
  
  # Dynamically feasible
  Δ0 = 20000. 
  ω0 = 1.
  ω_max = 100.
  ε = 1.
  ρ0 = 0.01
  ρ1 = 0.1
  β_succ = 2. 
  β_fail = 0.5
  γ_fail = 8. 

  # Dynamically feasible, collision free
  Δ0 = 5000. 
  ω0 = 1.
  ω_max = 1000.
  ε = 1.
  ρ0 = 0.01
  ρ1 = 0.1
  β_succ = 2. 
  β_fail = 0.5
  γ_fail = 8. 

  SCPParam_GuSTO(Δ0, ω0, ω_max, ε, ρ0, ρ1, β_succ, β_fail, γ_fail)
end

function SCPParam_Mao(model::Airplane)
  # Straight line in workspace 
  ρ = [-5.; -2; 0.5]
  Δ_u0 = 10000. 
  λ = 1.
  α = 2.
  
  # Dynamically feasible
  ρ = [-5.; -2; 0.5]
  Δ_u0 = 10000. 
  λ = 5.
  α = 2.

  # Dynamically feasible, collision free
  ρ = [-5.; -2; 0.5]
  Δ_u0 = 100. 
  λ = 1.
  α = 2.

  SCPParam_Mao(ρ, Δ_u0, λ, α)
end

function SCPParam_TrajOpt(model::Airplane)
  # Straight line in workspace 
  μ0 = 1.
  s0 = 10000.
  c = 0.25 
  τ_plus = 2. 
  τ_minus = 0.5
  k = 8. 
  ftol = 0.01
  xtol = 0.1
  ctol = 0.01
  max_penalty_iteration = 5
  max_convex_iteration = 5
  max_trust_iteration = 5
  
  # Dynamically feasible
  μ0 = 1.
  s0 = 10000.
  c = 0.25 
  τ_plus = 2. 
  τ_minus = 0.5
  k = 5. 
  ftol = 0.01
  xtol = 0.1
  ctol = 0.01
  max_penalty_iteration = 5
  max_convex_iteration = 5
  max_trust_iteration = 5

  # Dynamically feasible, collision free
  μ0 = 1.
  s0 = 10000.
  c = 0.25 
  τ_plus = 2. 
  τ_minus = 0.5
  k = 5. 
  ftol = 0.01
  xtol = 0.1
  ctol = 0.01
  max_penalty_iteration = 5
  max_convex_iteration = 5
  max_trust_iteration = 5

  SCPParam_TrajOpt(μ0, s0, c, τ_plus, τ_minus, k, ftol, xtol, ctol,max_penalty_iteration,max_convex_iteration,max_trust_iteration)
end

###############
# Gurobi stuff
###############
function cost_true(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane}) where T
  U,N = traj.U, SCPP.N
  dtp = traj_prev.dt
  Jm = 0
  for k in 1:N-1
    Jm += dtp*norm(U[:,k])^2
  end
  return Jm
end

function cost_true_convexified(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
	cost_true(traj, traj_prev, SCPP)
end

#############################
# Trajectory Initializations
#############################
function init_traj_straightline(TOP::TrajectoryOptimizationProblem{Plane{T}, Airplane, E}) where {T,E}
	model, x_init, x_goal = TOP.PD.model, TOP.PD.x_init, TOP.PD.x_goal
	x_dim, u_dim, N, tf_guess = model.x_dim, model.u_dim, TOP.N, TOP.tf_guess

	X = hcat(range(x_init, stop=x_goal, length=N)...)
	U = zeros(u_dim,N)

  for k in 1:3
    X[k,:] = collect(range(X[k,1], stop=X[k,end], length=N))
  end
  for k in 4:8
    X[k,:] = X[k,1]*ones(N)
  end
	Trajectory(X, U, tf_guess)
end

function init_traj_feasible_sos(TOP::TrajectoryOptimizationProblem{Plane{T}, Airplane, E}) where {T,E}
	model, x_init, x_goal = TOP.PD.model, TOP.PD.x_init, TOP.PD.x_goal
	x_dim, u_dim, N, tf_guess = model.x_dim, model.u_dim, TOP.N, TOP.tf_guess

  vars = matread(joinpath(Pkg.dir("GuSTO"), "src", "dynamics","init_feasible_sos.mat"))
  Xfull, Ufull, Tsfull = vars["X"], vars["U"], vars["t_ref"]
  tf_guess = Tsfull[end]

  Nidx = length(Tsfull) 
  if Nidx < N
    warn("Initial seed in file has fewer nodes than reqeusted!")
    quit()
  end

  # downsample
  idx = [round(Int,i) for i in collect(range(1, stop=Nidx, length=N))]
  return Trajectory(Xfull[:,idx],Ufull[:,idx[1:end-1]],tf_guess)
end

function init_traj_line_sos(TOP::TrajectoryOptimizationProblem{Plane{T}, Airplane, E}) where {T,E}
	model, x_init, x_goal = TOP.PD.model, TOP.PD.x_init, TOP.PD.x_goal
	x_dim, u_dim, N, tf_guess = model.x_dim, model.u_dim, TOP.N, TOP.tf_guess

  vars = matread(joinpath(Pkg.dir("GuSTO"), "src", "dynamics","init_straight_line_sos.mat"))
  Xfull, Ufull, Tsfull = vars["X"], vars["U"], vars["t_ref"]
  tf_guess = Tsfull[end]

  Nidx = length(Tsfull) 
  if Nidx < N
    warn("Initial seed in file has fewer nodes than reqeusted!")
    quit()
  end

  # downsample
  idx = [round(Int,i) for i in collect(range(1, stop=Nidx, length=N))]
  Xfull = Xfull[:,idx]
  Ufull = Ufull[:,idx[1:end-1]]

  return Trajectory(Xfull, Ufull ,tf_guess)
end

#######################
# Constraint-adding
#######################
function initialize_model_params!(SCPP::SCPProblem{Plane{T}, Airplane, E}, traj_prev::Trajectory) where {T,E}
  N, robot, model = SCPP.N, SCPP.PD.robot, SCPP.PD.model
  x_dim, u_dim = model.x_dim, model.u_dim
  Xp, Up = traj_prev.X, traj_prev.U

  model.f, model.A, model.B = [], [], B_dyn(Xp[:,1],robot,model)
  for k = 1:N-1
    push!(model.f, f_dyn(Xp[:,k],Up[:,k],robot,model))
    push!(model.A, A_dyn(Xp[:,k],robot,model))
  end
end

function update_model_params!(SCPP::SCPProblem{Plane{T}, Airplane, E}, traj_prev::Trajectory) where {T,E}
  N, robot, model = SCPP.N, SCPP.PD.robot, SCPP.PD.model
  Xp, Up, f, A = traj_prev.X, traj_prev.U, model.f, model.A

  for k = 1:N-1
    update_f!(f[k], Xp[:,k], Up[:,k], robot, model)
    update_A!(A[k], Xp[:,k], robot, model)
  end
end

macro constraint_abbrev_airplane(traj, traj_prev, SCPP)
	quote
		X, U, Tf = $(esc(traj)).X, $(esc(traj)).U, $(esc(traj)).Tf
    Xp, Up, Tfp, dtp = $(esc(traj_prev)).X, $(esc(traj_prev)).U, $(esc(traj_prev)).Tf, $(esc(traj_prev)).dt
    robot, model, WS, x_init, x_goal = $(esc(SCPP)).PD.robot, $(esc(SCPP)).PD.model, $(esc(SCPP)).WS, $(esc(SCPP)).PD.x_init, $(esc(SCPP)).PD.x_goal
    x_dim, u_dim, N, dh = model.x_dim, model.u_dim, $(esc(SCPP)).N, $(esc(SCPP)).dh
    X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh
	end
end

## Dynamics constraints
function dynamics_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	# Where i is the state index, and k is the timestep index
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  fp, Ap, Bp = get_f(k, model), get_A(k, model), get_B(k, model)
  if k == N-1
    return Tf*fp + Tfp*(Ap*(X[:,k]-Xp[:,k]) + Bp*(U[:,k]-Up[:,k])) - (X[:,k+1]-X[:,k])/dh
  else
    return 0.5*(Tf*(fp + get_f(k+1, model)) + Tfp*(Ap*(X[:,k]-Xp[:,k]) + Bp*(U[:,k]-Up[:,k])) +
      Tfp*(Ap*(X[:,k+1]-Xp[:,k+1]) + Bp*(U[:,k+1]-Up[:,k+1]))) - (X[:,k+1]-X[:,k])/dh
  end
end

# Get current dynamics structures for a time step
get_f(k::Int, model::Airplane) = model.f[k]
get_A(k::Int, model::Airplane) = model.A[k]
get_B(k::Int, model::Airplane) = model.B

# Generate full dynamics structures for a time step
function f_dyn(x::Vector, u::Vector, robot::Robot, model::Airplane)
  x_dim = model.x_dim
  f = zeros(x_dim)
  update_f!(f, x, u, robot, model)
  return f
end

function update_f!(f, x::Vector, u::Vector, robot::Robot, model::Airplane)
  # pos- xyz, heading- ψ, speed- v, flight path angle- γ, roll- ϕ, angle of attack- α,
  rx, ry, rz, ψ, v, γ, ϕ, α = x
  u_a, u_ϕd, u_αd = u
  g, ρ, Area, mass = robot.g, robot.ρ, robot.Area, robot.mass
  Cd0, Kd, α_0 = robot.Cd0, robot.Kd, robot.α_0
  Fl = π*ρ*Area*v^2*α
  Fd = ρ*Area*v^2*(Cd0 + 4*π^2*Kd*α^2)

  f[1] = v*cos(ψ)*cos(γ)
  f[2] = v*sin(ψ)*cos(γ)
  f[3] = v*sin(γ)
  f[4] = -Fl*sin(ϕ)/(mass*v*cos(γ))
  f[5] = u_a - Fd/mass - g*sin(γ)
  f[6] = Fl*cos(ϕ)/(mass*v) - g*cos(γ)/v
  f[7] = u_ϕd
  f[8] = u_αd
end

function A_dyn(x::Vector, robot::Robot, model::Airplane)
  x_dim = model.x_dim
  A = zeros(x_dim, x_dim)
  update_A!(A, x, robot, model)
  return A
end

function update_A!(A, x::Vector, robot::Robot, model::Airplane)
  rx, ry, rz, ψ, v, γ, ϕ, α = x
  g, ρ, Area, mass = robot.g, robot.ρ, robot.Area, robot.mass
  Cd0, Kd = robot.Cd0, robot.Kd

  # See scripts/symbolic_math.m for derivation of these equations
  A[1,4:6] = [-v*cos(γ)*sin(ψ) cos(γ)*cos(ψ) -v*cos(ψ)*sin(γ)]
  A[2,4:6] = [ v*cos(γ)*cos(ψ) cos(γ)*sin(ψ) -v*sin(γ)*sin(ψ)]
  A[3,5:6] = [                       sin(γ)           v*cos(γ)]
  A[4,5] = -(π*Area*α*ρ*sin(ϕ))/(mass*cos(γ))
  A[4,6] = -(π*Area*α*ρ*v*sin(γ)*sin(ϕ))/(mass*cos(γ)^2)
  A[4,7] = -(π*Area*α*ρ*v*cos(ϕ))/(mass*cos(γ))
  A[4,8] = -(π*Area*ρ*v*sin(ϕ))/(mass*cos(γ))
  A[5,5] = -(2*Area*ρ*v*((39.4784*Kd*α^2)/ + Cd0))/mass
  A[5,6] = -g*cos(γ)
  A[5,8] = -(78.9568*Area*Kd*α*ρ*v^2)/mass
  A[6,5] = (g*cos(γ))/v^2 + (π*Area*α*ρ*cos(ϕ))/mass
  A[6,6] = (g*sin(γ))/v
  A[6,7] = -(π*Area*α*ρ*v*sin(ϕ))/mass
  A[6,8] = (π*Area*ρ*v*cos(ϕ))/mass
end

function B_dyn(x::Vector, robot::Robot, model::Airplane)
  x_dim, u_dim = model.x_dim, model.u_dim
  B = zeros(x_dim, u_dim)
  B[5,1], B[7,2], B[8,3] = 1., 1., 1.
  return B
end

## Convex state inequality constraints
# X: (x,y,z,ψ,v,γ,ϕ, α)
function csi_goal_region_min_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	# Where i is the state index, and k is the timestep index
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return model.goal_min[i] - X[i,N] 
end

function csi_goal_region_max_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return X[i,N] - model.goal_max[i]
end

function csi_v_max_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return X[5,k]-robot.v_max
end

function csi_v_min_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return -X[5,k]+robot.v_min
end

function csi_γ_max_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return X[6,k]-robot.γ_max
end

function csi_γ_min_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return -X[6,k]-robot.γ_max
end

function csi_ϕ_max_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return X[7,k]-robot.γ_max
end

function csi_ϕ_min_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
	X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return -X[7,k]-robot.γ_max
end

## Nonconvex state inequality constraints
function ncsi_obstacle_avoidance_constraints(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)

  rb_idx, env_idx = 1, i
  env_ = WS.btenvironment_keepout

  clearance = model.clearance 

  r = X[1:3,k]
  dist,xbody,xobs = BulletCollision.distance(env_,rb_idx,r,env_idx)

  # See Eq. 12b in "Convex optimization for proximity maneuvering of a spacecraft with a robotic manipulator"
  return clearance - dist
end

## Nonconvex state inequality constraints (convexified)
function ncsi_obstacle_avoidance_constraints_convexified(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)

  rb_idx, env_idx = 1,i
  env_ = WS.btenvironment_keepout

  clearance = model.clearance 

  r0 = get_workspace_location(traj_prev, SCPP, k, rb_idx)
  dist, xbody, xobs = BulletCollision.distance(env_, rb_idx, r0, env_idx)

  if dist < SCPP.param.obstacle_toggle_distance
    r = get_workspace_location(traj, SCPP, k, rb_idx)

    # See Eq. 12b in "Convex optimization for proximity maneuvering of a spacecraft with a robotic manipulator"
    nhat = dist > 0 ?
      (xbody-xobs)./norm(xbody-xobs) :
      (xobs-xbody)./norm(xobs-xbody)

    return clearance - (dist + nhat'*(r-r0))
  else
    return 0
  end
end

## State trust region inequality constraints
function stri_state_trust_region(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)

  return norm(X[:,k]-Xp[:,k])^2
end

## Trust region inequality constraints
function ctri_control_trust_region(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  return norm(U[:,k]-Up[:,k])
end

function get_workspace_location(traj, SCPP::SCPProblem{Plane{T}, Airplane, E}, k::Int, i::Int) where {T,E}
  return traj.X[1:3,k]
end

function SCPConstraints(SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
	model = SCPP.PD.model
	x_dim, u_dim, N = model.x_dim, model.u_dim, SCPP.N
  WS = SCPP.WS

	SCPC = SCPConstraints()

	## Dynamics constraints
  for k = 1:N-1
    push!(SCPC.dynamics, (dynamics_constraints, k, 0))
  end

	## Convex state equality constraints
	# Init and goal
	for i = 1:x_dim
    push!(SCPC.convex_state_eq, (cse_init_constraints, 0, i))
  end

    # toggle hard equality or box constraints
  for i = 1:x_dim
    push!(SCPC.convex_state_eq, (cse_goal_constraints, 0, i))
  end

	## Convex state inequality constraints
  for i = 1:3
    # push!(SCPC.convex_state_ineq, (csi_goal_region_min_constraints, 0, i))
    # push!(SCPC.convex_state_ineq, (csi_goal_region_max_constraints, 0, i))
  end

	# State bounds
	for k = 1:N
		push!(SCPC.convex_state_ineq, (csi_v_max_constraints, k, 0))
		push!(SCPC.convex_state_ineq, (csi_v_min_constraints, k, 0))
		push!(SCPC.convex_state_ineq, (csi_γ_max_constraints, k, 0))
		push!(SCPC.convex_state_ineq, (csi_γ_min_constraints, k, 0))
		push!(SCPC.convex_state_ineq, (csi_ϕ_max_constraints, k, 0))
		push!(SCPC.convex_state_ineq, (csi_ϕ_min_constraints, k, 0))
	end

	## Nonconvex state equality constraints
  nothing

	## Nonconvex state inequality constraints
  env_ = WS.btenvironment_keepout
  for k = 1:N, i = 1:length(env_.convex_env_components)
    push!(SCPC.nonconvex_state_ineq, (ncsi_obstacle_avoidance_constraints, k, i))
  end

  ## Nonconvex state equality constraints (convexified)
  nothing

	## Nonconvex state inequality constraints (convexified)
  env_ = WS.btenvironment_keepout
  for k = 1:N, i = 1:length(env_.convex_robot_components)
    push!(SCPC.nonconvex_state_ineq, (ncsi_obstacle_avoidance_constraints_convexified, k, i))
  end

  ## Convex control equality constraints
  nothing

	## Convex control inequality constraints
	for k = 1:N-1, i = 1:u_dim
    push!(SCPC.convex_control_ineq, (cci_max_bound_constraints, k, i))
    push!(SCPC.convex_control_ineq, (cci_min_bound_constraints, k, i))
	end

	## State trust region ineqality constraints
  for k = 1:N
    push!(SCPC.state_trust_region_ineq, (stri_state_trust_region, k, 0))
  end

  ## Constrol trust region inequality constraints
  for k = 1:N-1
    push!(SCPC.control_trust_region_ineq, (ctri_control_trust_region, k, 0))
  end

	return SCPC 
end

function trust_region_ratio_gusto(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
  # Where i is the state index, and k is the timestep index
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  fp, Ap = model.f, model.A
  num,den = 0, 0 
  env_ = WS.btenvironment_keepout

  for k in 1:N-1
    linearized = fp[k] + Ap[k]*(X[:,k]-Xp[:,k])
    num += norm(f_dyn(X[:,k],U[:,k],robot,model) - linearized)
    den += norm(linearized)
  end
  
  clearance = model.clearance 

  for k in 1:N
    r0,r = Xp[1:3,k], X[1:3,k]
    for (rb_idx,body_point) in enumerate(env_.convex_robot_components)
      for (env_idx,convex_env_component) in enumerate(env_.convex_env_components)
        dist,xbody,xobs = BulletCollision.distance(env_,rb_idx,r0,env_idx)
        nhat = dist > 0 ?
          (xbody-xobs)./norm(xbody-xobs) :
          (xobs-xbody)./norm(xobs-xbody) 
        linearized = clearance - (dist + nhat'*(r-r0))
        
        dist,xbody,xobs = BulletCollision.distance(env_,rb_idx,r,env_idx)

        num += abs((clearance-dist) - linearized) 
        den += abs(linearized) 
      end
    end
  end
  return num/den
end

function trust_region_ratio_trajopt(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
  # Where i is the state index, and k is the timestep index
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  fp = model.f
  num, den = 0, 0
  env_ = WS.btenvironment_keepout
  dt = traj.dt

  for k in 1:N-1
    ϕ_old = norm(fp[k] - (Xp[:,k]-Xp[:,k])/dtp, 1)
    ϕ_new = norm(f_dyn(X[:,k],U[:,k],robot,model) - (X[:,k]-X[:,k])/dt, 1)
    ϕ_hat_new = norm(dynamics_constraints(traj,traj_prev,SCPP,k,0), 1)
    num += (ϕ_old-ϕ_new)
    den += (ϕ_old-ϕ_hat_new) 
  end

  clearance = model.clearance

  for k in 1:N
    r0,r = Xp[1:3,k], X[1:3,k]
    for (rb_idx,body_point) in enumerate(env_.convex_robot_components)
      for (env_idx,convex_env_component) in enumerate(env_.convex_env_components)
        dist,xbody,xobs = BulletCollision.distance(env_,rb_idx,r0,env_idx)
        ϕ_old = clearance-dist
        
        dist,xbody,xobs = BulletCollision.distance(env_,rb_idx,r,env_idx)
        nhat = dist > 0 ?
          (xbody-xobs)./norm(xbody-xobs) :
          (xobs-xbody)./norm(xobs-xbody) 
        ϕ_new = clearance-dist
        ϕ_hat_new = clearance - (dist + nhat'*(r-r0))

        num += (ϕ_old-ϕ_new)
        den += (ϕ_old-ϕ_hat_new) 
      end
    end
  end

  return num/den
end

function trust_region_ratio_mao(traj, traj_prev::Trajectory, SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
  # Where i is the state index, and k is the timestep index
  X,U,Tf,Xp,Up,Tfp,dtp,robot,model,WS,x_init,x_goal,x_dim,u_dim,N,dh = @constraint_abbrev_airplane(traj, traj_prev, SCPP)
  num,den = 0, 0

  cost_true_prev = cost_true(traj_prev, traj_prev, SCPP)
  cost_true_new = cost_true(traj, traj, SCPP)
  for k in 1:N-1
    cost_true_prev += norm(dynamics_constraints(traj_prev, traj_prev, SCPP, k, 0), Inf)
    cost_true_new += norm(dynamics_constraints(traj, traj, SCPP, k, 0), Inf)
  end
  cost_linearized_new = cost_true(traj, traj, SCPP)
  return (cost_true_prev-cost_true_new)/(cost_true_prev-cost_linearized_new)
end

##################
# Shooting Method
##################
function get_dual_cvx(prob::Convex.Problem, SCPP::SCPProblem{Plane{T}, Airplane, E}, solver) where {T,E}
  if solver == "Mosek"
    return -MathProgBase.getdual(prob.model)[1:SCPP.PD.model.x_dim]
  else
    return []
  end
end

function get_dual_jump(SCPS::SCPSolution, SCPP::SCPProblem{Plane{T}, Airplane, E}) where {T,E}
  @show -MathProgBase.getconstrduals(SCPS.solver_model.internalModel)[1:SCPP.PD.model.x_dim]
end

##################
# Dynamics 
##################
function simEOM(traj, SCPP::SCPProblem{Plane{T}, Airplane, E}, dt_prop=0.01) where {T,E}
  X,U,Tf = traj.X, traj.U, traj.Tf
  N, dt = SCPP.N, traj.dt
  rb = SCPP.PD.robot
  
  x_dim = SCPP.PD.model.x_dim
  u_dim = SCPP.PD.model.u_dim

  Ufull = Matrix(u_dim,0)
  for k in 1:N-1
    Ufull = [Ufull repmat(U[:,k], 1, Int(round(dt/dt_prop)))]
  end

  x0 = X[:,1]
  Xs = repmat(x0,1,N)

  for k = 1:N-1
    U = Ufull[:,k]
    k1 = fAir(x0,U,rb)
    x2 = x0 + 0.5*dt_prop*k1
    k2 = fAir(x2,U,rb)
    x3 = x0 + 0.5*dt_prop*k2
    k3 = fAir(x3,U,rb)
    x4 = x0 + dt_prop*k3
    k4 = fAir(x4,U,rb)
    x0 = x0 + 1/6*dt_prop*(k1 + 2*k2 + 2*k3 + k4)
    Xs[:,k+1] = x0
  end
  return Xs
end
