
export solve_gusto_cvx!, solve_gusto_jump!#, solve_gusto_jump_nonlinear!

mutable struct SCPParam_GuSTO <: SCPParamSpecial
	Δ0 								# trust region size 
	ω0         				# exact penalty violation
	ω_max
	ε
	ρ0 
	ρ1
  β_succ		   				# trust-region growth factors
  β_fail 	
  γ_fail

  Δ_vec::Vector
  ω_vec::Vector
  ρ_vec::Vector           # trust region ratios
  trust_region_satisfied_vec::Vector  # Bool flags
  convex_ineq_satisfied_vec::Vector  # Bool flags
end

function SCPParam_GuSTO(Δ0, ω0, ω_max, ε, ρ0, ρ1, β_succ, β_fail, γ_fail)
	SCPParam_GuSTO(Δ0, ω0, ω_max, ε, ρ0, ρ1, β_succ, β_fail, γ_fail, [Δ0], [ω0], [0.], [false], [false])
end

##########
# General
##########

# Define this for a dynamics model if model parameters need to be updated
# at each SCP iteration
update_model_params!(SCPP::SCPProblem, traj_prev::Trajectory) = nothing

function trust_region_satisfied_gusto(traj::Trajectory, traj_prev::Trajectory, SCPP::SCPProblem)
  # checks for satisfaction of state trust region constraint
  Δ = SCPP.param.alg.Δ_vec[end]
  max_val = -Inf

  for k in 1:SCPP.N
    val = norm(traj.X[:,k]-traj_prev.X[:,k])^2
    max_val = val > max_val ? val : max_val
  end
  return max_val-Δ <= 0
end

function convex_ineq_satisfied_gusto(traj::Trajectory, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
  # checks for satisfaction of convex state inequalities and nonconvex->convexified state inequalities
	for (f, k, i) in (SCPC.convex_state_ineq..., SCPC.nonconvex_state_convexified_ineq...)
		if f(traj, traj_prev, SCPP, k, i) > SCPP.param.alg.ε
			return false
		end
	end
  return true
end

########
# JuMP
########

function solve_gusto_jump!(SCPS::SCPSolution, SCPP::SCPProblem, solver="Ipopt", max_iter=50, force=false; kwarg...)
	# Solves a sequential convex programming problem
	# Inputs:
	#		SCPS - SCP solution structure, including an initial trajectory
	#		SCPP - SCP problem definition structure
	#   max_iter - Set to enforce a maximum number of iterations (0 = unlimited)
	#   force - Set true to force further refinement iterations despite convergence	

	N = SCPP.N
	param, model = SCPP.param, SCPP.PD.model

	param.alg = SCPParam_GuSTO(model)
	Δ0, ω0, ω_max, ρ0, ρ1 = param.alg.Δ0, param.alg.ω0, param.alg.ω_max, param.alg.ρ0, param.alg.ρ1
	β_succ, β_fail, γ_fail = param.alg.β_succ, param.alg.β_fail, param.alg.γ_fail
	Δ_vec, ω_vec, ρ_vec = param.alg.Δ_vec, param.alg.ω_vec, param.alg.ρ_vec
	trust_region_satisfied_vec, convex_ineq_satisfied_vec = param.alg.trust_region_satisfied_vec, param.alg.convex_ineq_satisfied_vec

	# TODO: Modify constraints rather than creating new problem
	iter_cap = SCPS.iterations + max_iter
	SCPV = SCPVariables{JuMP.VariableRef, Array{JuMP.VariableRef}}()
	SCPC = SCPConstraints(SCPP)

	initialize_model_params!(SCPP, SCPS.traj)
	push!(SCPS.J_true, cost_true(SCPS.traj, SCPS.traj, SCPP))
	push!(ρ_vec, trust_region_ratio_gusto(SCPS.traj, SCPS.traj, SCPP))
	param.obstacle_toggle_distance = Δ_vec[end]/8 + model.clearance # TODO: Generalize clearance

	first_time = true
	while (SCPS.iterations < iter_cap)
		time_start = time_ns()

		# Set up, solve problem
		# SCPS.solver_model = Model(with_optimizer(SCS.Optimizer))
		# SCPS.solver_model = Model(with_optimizer(MosekOptimizer))
		SCPS.solver_model = Model(with_optimizer(Ipopt.Optimizer))
		update_model_params!(SCPP, SCPS.traj)
		add_variables_jump!(SCPS, SCPV, SCPP)
		add_objective_gusto_jump!(SCPS, SCPV, SCPC, SCPP)
		add_constraints_gusto_jump!(SCPS, SCPV, SCPC, SCPP)
		# @show SCPV.X[2,4]
		# @show typeof(SCPV.X[2,4])
		# @show SCPV.X[2,4].index
		# set_start_value(SCPV.X[2,4], 1.0)

		# model = SCPP.PD.model
  # 	x_dim, u_dim = model.x_dim, model.u_dim

		# @variable(SCPS.solver_model, X[1:x_dim, 1:N])
		# @variable(SCPS.solver_model, U[1:u_dim, 1:N])
		# @variable(SCPS.solver_model, Tf)

		# SCPP.param.fixed_final_time ? JuMP.fix(Tf, SCPP.tf_guess) : nothing

		# SCPV.X, SCPV.U, SCPV.Tf = X, U, Tf
		# set_start_value(SCPV.X[2,4], 1.0)
		# set_start_value.(SCPV.X, SCPS.traj.X)
		# set_start_value.(SCPV.U, SCPS.traj.U)
		

		# set_start_value.(SCPV.X, SCPS.traj.X)
		# set_start_value.(SCPV.U, SCPS.traj.U)
		JuMP.optimize!(SCPS.solver_model)
		first_time = false

		@show termination_status(SCPS, SCPP)
		push!(SCPS.prob_status, termination_status(SCPS, SCPP))
		if SCPS.prob_status[end] != :Optimal
		  warn("GuSTO SCP iteration failed to find an optimal solution")
		  push!(SCPS.iter_elapsed_times, (time_ns() - time_start)/10^9) 
		  return
		end

		new_traj = Trajectory(getvalue(SCPV.X), getvalue(SCPV.U), SCPS.traj.Tf)
		push!(SCPS.convergence_measure, convergence_metric(new_traj, SCPS.traj, SCPP))

		SCPS.dual = get_dual_jump(SCPS, SCPP)


		# Recover solution
		# new_traj = Trajectory(SCPV.X.value, SCPV.U.value, SCPV.Tf.value[1])
		# push!(SCPS.convergence_measure, convergence_metric(new_traj, SCPS.traj, SCPP))
		# push!(SCPS.J_full, prob.optval)
		# SCPS.dual = get_dual_cvx(prob, SCPP, solver)
		
		# Check trust regions
		push!(trust_region_satisfied_vec, trust_region_satisfied_gusto(new_traj, SCPS.traj, SCPP))
		push!(convex_ineq_satisfied_vec, convex_ineq_satisfied_gusto(new_traj, SCPS.traj, SCPC, SCPP))

		if trust_region_satisfied_vec[end]
			push!(ρ_vec, trust_region_ratio_gusto(new_traj, SCPS.traj, SCPP))			
			if ρ_vec[end] > ρ1
				push!(SCPS.accept_solution, false)
				push!(Δ_vec, β_fail*Δ_vec[end])
				push!(ω_vec, ω_vec[end])
			else
				push!(SCPS.accept_solution, true)
				ρ_vec[end] < ρ0 ? push!(Δ_vec, min(β_succ*Δ_vec[end], Δ0)) : push!(Δ_vec, Δ_vec[end])
				!convex_ineq_satisfied_vec[end] ? push!(ω_vec, γ_fail*ω_vec[end]) : push!(ω_vec, ω0)
			end
		else
			push!(SCPS.accept_solution, false)
			push!(Δ_vec, Δ_vec[end])
			push!(ω_vec, γ_fail*ω_vec[end])
		end

		if SCPS.accept_solution[end]
			push!(SCPS.J_true, cost_true(new_traj, SCPS.traj, SCPP))
			copy!(SCPS.traj, new_traj)	# TODO(ambyld): Maybe deepcopy not needed?
		else
			push!(SCPS.J_true, SCPS.J_true[end])
		end

		param.obstacle_toggle_distance = Δ_vec[end]/8 + model.clearance

		iter_elapsed_time = (time_ns() - time_start)/10^9
		push!(SCPS.iter_elapsed_times, iter_elapsed_time)
		SCPS.total_time += iter_elapsed_time
		SCPS.iterations += 1

		if ω_vec[end] > ω_max
			warn("GuSTO SCP omegamax exceeded")
			break
		end
		!SCPS.accept_solution[end] ? continue : nothing

		if SCPS.convergence_measure[end] <= param.convergence_threshold
			SCPS.converged = true
			convex_ineq_satisfied_vec[end] && (SCPS.successful = true)
			force ? continue : break
		end
	end
end

function add_variables_jump!(SCPS::SCPSolution, SCPV::SCPVariables, SCPP::SCPProblem)
	solver_model = SCPS.solver_model
	model = SCPP.PD.model
  x_dim, u_dim, N = model.x_dim, model.u_dim, SCPP.N

	@variable(solver_model, X[1:x_dim, 1:N])
	@variable(solver_model, U[1:u_dim, 1:N])
	@variable(solver_model, Tf)

	SCPP.param.fixed_final_time ? JuMP.fix(Tf, SCPP.tf_guess) : nothing

	SCPV.X, SCPV.U, SCPV.Tf = X, U, Tf
end

function add_constraints_gusto_jump!(SCPS::SCPSolution, SCPV::SCPVariables, SCPC::SCPConstraints, SCPP::SCPProblem)
	solver_model, traj_prev = SCPS.solver_model, SCPS.traj

	update_model_params!(SCPP, traj_prev)

	for (f, k, i) in (SCPC.convex_state_eq..., SCPC.dynamics...)
		@constraint(solver_model, f(SCPV, traj_prev, SCPP, k, i) .== 0.)
	end

	for (f, k, i) in SCPC.convex_control_ineq
		@constraint(solver_model, f(SCPV, traj_prev, SCPP, k, i)  <= 0.)
	end

	if !SCPP.param.fixed_final_time
		@constraint(solver_model, SCPV.Tf >= 0.1)
	end

	# if i == 0 # vector constraint
  #   	@constraint(solver_model, f(SCPV, traj_prev, SCPP, k, i) .== 0.)
  #   else 	  # scalar constraint
  #   	@constraint(solver_model, f(SCPV, traj_prev, SCPP, k, i)  == 0.)
  #   end
end

function add_objective_gusto_jump!(SCPS::SCPSolution, SCPV::SCPVariables, SCPC::SCPConstraints, SCPP::SCPProblem)
	solver_model, traj_prev = SCPS.solver_model, SCPS.traj
	robot, model = SCPP.PD.robot, SCPP.PD.model
	x_dim, u_dim, N = model.x_dim, model.u_dim, SCPP.N
	ω, Δ = SCPP.param.alg.ω_vec[end], SCPP.param.alg.Δ_vec[end]

	U = SCPV.U
	N, dt = SCPP.N, SCPP.tf_guess/SCPP.N

	# Add penalized constraints:
	N_stri = length(SCPC.state_trust_region_ineq)
	N_csi = length(SCPC.convex_state_ineq)
	N_ncsci = length(SCPC.nonconvex_state_convexified_ineq)

	@variable(solver_model, C_stri[1:N_stri] >= 0.)
	@variable(solver_model, C_csi[1:N_csi] >= 0.)
	@variable(solver_model, C_ncsci[1:N_ncsci] >= 0.)

	for j in 1:N_stri
		(f, k, i) = SCPC.state_trust_region_ineq[j]
		@constraint(solver_model, ω*f(SCPV, traj_prev, SCPP, k, i) - Δ <= C_stri[j])
	end

	for j in 1:N_csi
		(f, k, i) = SCPC.convex_state_ineq[j]
		@constraint(solver_model, ω*f(SCPV, traj_prev, SCPP, k, i) <= C_csi[j])
	end

	for j in 1:N_ncsci
		(f, k, i) = SCPC.nonconvex_state_convexified_ineq[j]
		@constraint(solver_model, ω*f(SCPV, traj_prev, SCPP, k, i) <= C_ncsci[j])
	end

	cost_expr = cost_true_convexified(SCPV, traj_prev, SCPP)

	@objective(solver_model, Min, cost_expr + sum(C_stri[i] for i in 1:N_stri)
		 + sum(C_csi[i] for i in 1:N_csi) + sum(C_ncsci[i] for i in 1:N_ncsci))

end

######
# CVX 
######

function solve_gusto_cvx!(SCPS::SCPSolution, SCPP::SCPProblem, solver="Mosek", max_iter=50, force=false; kwarg...)
	# Solves a sequential convex programming problem
	# Inputs:
	#		SCPS - SCP solution structure, including an initial trajectory
	#		SCPP - SCP problem definition structure
	#   max_iter - Set to enforce a maximum number of iterations (0 = unlimited)
	#   force - Set true to force further refinement iterations despite convergence

	if solver == "Mosek"
		default_solver = MosekSolver(; kwarg...)
	elseif solver == "Gurobi"
		default_solver = GurobiSolver(; kwarg...)
  else
		default_solver = SCSSolver(; kwarg...)
	end
	
	N = SCPP.N
	param, model = SCPP.param, SCPP.PD.model

	param.alg = SCPParam_GuSTO(model)
	Δ0, ω0, ω_max, ρ0, ρ1 = param.alg.Δ0, param.alg.ω0, param.alg.ω_max, param.alg.ρ0, param.alg.ρ1
	β_succ, β_fail, γ_fail = param.alg.β_succ, param.alg.β_fail, param.alg.γ_fail
	Δ_vec, ω_vec, ρ_vec = param.alg.Δ_vec, param.alg.ω_vec, param.alg.ρ_vec
  trust_region_satisfied_vec, convex_ineq_satisfied_vec = param.alg.trust_region_satisfied_vec, param.alg.convex_ineq_satisfied_vec

	iter_cap = SCPS.iterations + max_iter
	SCPV = SCPVariables{Convex.Variable,Convex.Variable}(SCPP)
	SCPC = SCPConstraints(SCPP)

	initialize_model_params!(SCPP, SCPS.traj)
  push!(SCPS.J_true, cost_true(SCPS.traj, SCPS.traj, SCPP))
	push!(ρ_vec, trust_region_ratio_gusto(SCPS.traj, SCPS.traj, SCPP))
	param.obstacle_toggle_distance = Δ_vec[end]/8 + model.clearance # TODO: Generalize clearance

  first_time = true
  prob = minimize(0.)
	while (SCPS.iterations < iter_cap)
		time_start = time_ns()

		# Set up, solve problem
		update_model_params!(SCPP, SCPS.traj)
		prob.objective = cost_full_convexified_gusto_cvx(SCPV, SCPS.traj, SCPC, SCPP)
		prob.constraints = add_constraints_gusto_cvx(SCPV, SCPS.traj, SCPC, SCPP)
		Convex.solve!(prob, default_solver, warmstart=!first_time)
		first_time = false

		push!(SCPS.prob_status, prob.status)
    if prob.status != :Optimal
      warn("GuSTO SCP iteration failed to find an optimal solution")
      push!(SCPS.iter_elapsed_times, (time_ns() - time_start)/10^9) 
      return
    end

		# Recover solution
		new_traj = Trajectory(SCPV.X.value, SCPV.U.value, SCPV.Tf.value[1])
		push!(SCPS.convergence_measure, convergence_metric(new_traj, SCPS.traj, SCPP))
		push!(SCPS.J_full, prob.optval)
		SCPS.dual = get_dual_cvx(prob, SCPP, solver)
		
		# Check trust regions
		push!(trust_region_satisfied_vec, trust_region_satisfied_gusto(new_traj, SCPS.traj, SCPP))
		push!(convex_ineq_satisfied_vec, convex_ineq_satisfied_gusto(new_traj, SCPS.traj, SCPC, SCPP))

    if trust_region_satisfied_vec[end]
    	push!(ρ_vec, trust_region_ratio_gusto(new_traj, SCPS.traj, SCPP))			
			if ρ_vec[end] > ρ1
				push!(SCPS.accept_solution, false)
				push!(Δ_vec, β_fail*Δ_vec[end])
				push!(ω_vec, ω_vec[end])
			else
				push!(SCPS.accept_solution, true)
				ρ_vec[end] < ρ0 ? push!(Δ_vec, min(β_succ*Δ_vec[end], Δ0)) : push!(Δ_vec, Δ_vec[end])
				!convex_ineq_satisfied_vec[end] ? push!(ω_vec, γ_fail*ω_vec[end]) : push!(ω_vec, ω0)
			end
		else
			push!(SCPS.accept_solution, false)
			push!(Δ_vec, Δ_vec[end])
			push!(ω_vec, γ_fail*ω_vec[end])
		end

		if SCPS.accept_solution[end]
			push!(SCPS.J_true, cost_true(new_traj, SCPS.traj, SCPP))
			copy!(SCPS.traj, new_traj)	# TODO(ambyld): Maybe deepcopy not needed?
		else
			push!(SCPS.J_true, SCPS.J_true[end])
		end
		param.obstacle_toggle_distance = Δ_vec[end]/8 + model.clearance

		iter_elapsed_time = (time_ns() - time_start)/10^9
		push!(SCPS.iter_elapsed_times, iter_elapsed_time)
		SCPS.total_time += iter_elapsed_time
		SCPS.iterations += 1

		if ω_vec[end] > ω_max
			warn("GuSTO SCP omegamax exceeded")
			break
		end
		!SCPS.accept_solution[end] ? continue : nothing

		if SCPS.convergence_measure[end] <= param.convergence_threshold
			SCPS.converged = true
			convex_ineq_satisfied_vec[end] && (SCPS.successful = true)
			force ? continue : break
		end
	end
end

function add_constraints_gusto_cvx(SCPV::SCPVariables, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	constraints = Convex.Constraint[]

	for (f, k, i) in (SCPC.convex_state_eq..., SCPC.dynamics...)
		constraints += f(SCPV, traj_prev, SCPP, k, i) == 0.
	end

	for (f, k, i) in SCPC.convex_control_ineq
		constraints += f(SCPV, traj_prev, SCPP, k, i) <= 0.
	end

	if !SCPP.param.fixed_final_time
		constraints += SCPV.Tf > 0.1
	end

	return constraints
end

function cost_convex_penalty_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	ω, Δ = SCPP.param.alg.ω_vec[end], SCPP.param.alg.Δ_vec[end]
	J = 0.
	for (f, k, i) in SCPC.convex_state_ineq
		J += ω*max(f(traj, traj_prev, SCPP, k, i), 0.)
	end
	for (f, k, i) in SCPC.state_trust_region_ineq
		J += ω*max(f(traj, traj_prev, SCPP, k, i) - Δ, 0.)
	end
	return J
end

function cost_nonconvex_penalty_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	ω = SCPP.param.alg.ω_vec[end]
	J = 0.
	for (f, k, i) in SCPC.nonconvex_state_ineq
		J += ω*max(f(traj, traj_prev, SCPP, k, i), 0.)
	end
	return J
end

function cost_nonconvex_penalty_convexified_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	ω = SCPP.param.alg.ω_vec[end]
	J = 0.
	for (f, k, i) in SCPC.nonconvex_state_convexified_ineq
		J += ω*max(f(traj, traj_prev, SCPP, k, i), 0.)
	end
	return J
end

function cost_penalty_full_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	cost_convex_penalty_gusto_cvx(traj, traj_prev, SCPC, SCPP) + cost_nonconvex_penalty_gusto_cvx(traj, traj_prev, SCPC, SCPP)
end

function cost_penalty_full_convexified_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	cost_convex_penalty_gusto_cvx(traj, traj_prev, SCPC, SCPP) + cost_nonconvex_penalty_convexified_gusto_cvx(traj, traj_prev, SCPC, SCPP)
end

function cost_full_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	cost_true(traj, traj_prev, SCPP) + cost_penalty_full_gusto_cvx(traj, traj_prev, SCPC, SCPP)
end

function cost_full_convexified_gusto_cvx(traj, traj_prev::Trajectory, SCPC::SCPConstraints, SCPP::SCPProblem)
	cost_true_convexified(traj, traj_prev, SCPP) + cost_penalty_full_convexified_gusto_cvx(traj, traj_prev, SCPC, SCPP)
end
