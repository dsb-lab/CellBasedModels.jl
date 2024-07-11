using Random
using LinearAlgebra

# Function to generate a random direction
function random_direction()
    theta = rand() * 2π  # Azimuthal angle
    phi = rand() * π  # Polar angle
    [sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi)]
end

# Function to generate a new direction with persistence
function new_direction_with_persistence(direction, persistence)
    random_dir = random_direction()
    new_dir = persistence * direction + (1 - persistence) * random_dir
    new_dir / norm(new_dir)  # Normalize the vector
end

# Recursive function to generate the tree
function generate_fractal_tree(point, direction, depth; max_depth=10, base_branch_length=1, sparsity=0.5, persistence=0.7, n_branches=5, stop_ratio=0.9)
    # Lists to store the nodes and their connections
    nodes = Vector{Vector{Float64}}()
    edges = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()
    
    generate_fractal_tree!(nodes, edges, point, direction, depth, 
                        max_depth=max_depth, base_branch_length=base_branch_length, 
                        sparsity=sparsity, persistence=persistence, n_branches=n_branches, stop_ratio=stop_ratio)

    return nodes, edges
end

function generate_fractal_tree!(nodes, edges, point, direction, depth; max_depth=10, base_branch_length=1, sparsity=0.5, persistence=0.7, n_branches=4, stop_ratio=0.9)

    if depth > max_depth || rand() > stop_ratio
        return
    end

    # Randomize branch length
    branch_length = base_branch_length# * (0.5 + rand() * 1.0)

    # Calculate the end point of the current branch
    end_point = point .+ branch_length .* direction

    # Store the branch connection
    push!(nodes, point)
    push!(nodes, end_point)
    push!(edges, (point, end_point))

    # Calculate new direction for branches with persistence
    new_direction = new_direction_with_persistence(direction, persistence)
    generate_fractal_tree!(nodes, edges, end_point, new_direction, depth + 1, 
                        max_depth=max_depth, base_branch_length=base_branch_length, 
                        sparsity=sparsity, persistence=persistence, n_branches=n_branches, stop_ratio=stop_ratio)

    # New branches
    # Randomize the number of branches
    num_branches = rand(1:n_branches)
    for _ in 1:num_branches
        # Determine whether to create a new branch based on sparsity
        if rand() > sparsity
            continue
        end

        # Calculate new direction for branches with persistence
        new_direction = new_direction_with_persistence(direction, persistence)

        # Recursive call to generate new branches
        generate_fractal_tree!(nodes, edges, end_point, new_direction, depth + 1, max_depth=max_depth, base_branch_length=base_branch_length, sparsity=sparsity, persistence=persistence, n_branches=n_branches)
    end
end
