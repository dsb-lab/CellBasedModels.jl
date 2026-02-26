using CellBasedModels
using BenchmarkTools
using CUDA
using KernelAbstractions

println("=" ^ 60)
println("Benchmarking @diffsym vs explicit expressions")
println("=" ^ 60)

# =============================================================================
# Test 1: Simple polynomial derivative
# =============================================================================
println("\n--- Test 1: Simple polynomial x^2 + y^2 ---")

function compute_with_diffsym(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        @diffsym begin
            a = x ^ 2
            b = y ^ 2
            c = a + b
        end derivatives=(dc_dx = (c, x), dc_dy = (c, y))
        
        out_arr[i] = dc_dx + dc_dy
    end
end

function compute_explicit(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        # Explicit derivative: d(x^2 + y^2)/dx = 2x, d/dy = 2y
        dc_dx = 2 * x
        dc_dy = 2 * y
        
        out_arr[i] = dc_dx + dc_dy
    end
end

N = 100_000
x = rand(N)
y = rand(N)
out_diffsym = zeros(N)
out_explicit = zeros(N)

# Warm up
compute_with_diffsym(x, y, out_diffsym, N)
compute_explicit(x, y, out_explicit, N)

# Verify correctness
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Results don't match!"

println("DiffSym version:")
@btime compute_with_diffsym($x, $y, $out_diffsym, $N)

println("Explicit version:")
@btime compute_explicit($x, $y, $out_explicit, $N)

# =============================================================================
# Test 2: More complex expression with sin, cos
# =============================================================================
println("\n--- Test 2: Trigonometric - sin(x)^2 + cos(y)^2 ---")

function compute_trig_diffsym(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        @diffsym begin
            a = sin(x) ^ 2
            b = cos(y) ^ 2
            c = a + b
        end derivatives=(dc_dx = (c, x), dc_dy = (c, y))
        
        out_arr[i] = dc_dx + dc_dy
    end
end

function compute_trig_explicit(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        # Explicit: d(sin(x)^2)/dx = 2*sin(x)*cos(x) = sin(2x)
        # d(cos(y)^2)/dy = 2*cos(y)*(-sin(y)) = -sin(2y)
        dc_dx = 2 * sin(x) * cos(x)
        dc_dy = -2 * cos(y) * sin(y)
        
        out_arr[i] = dc_dx + dc_dy
    end
end

out_diffsym .= 0
out_explicit .= 0
compute_trig_diffsym(x, y, out_diffsym, N)
compute_trig_explicit(x, y, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Trig results don't match!"

println("DiffSym version:")
@btime compute_trig_diffsym($x, $y, $out_diffsym, $N)

println("Explicit version:")
@btime compute_trig_explicit($x, $y, $out_explicit, $N)

# =============================================================================
# Test 3: Exponential with chain rule
# =============================================================================
println("\n--- Test 3: Exponential - exp(x*y) ---")

function compute_exp_diffsym(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        @diffsym begin
            c = exp(x * y)
        end derivatives=(dc_dx = (c, x), dc_dy = (c, y))
        
        out_arr[i] = dc_dx + dc_dy
    end
end

function compute_exp_explicit(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        # Explicit: d(exp(x*y))/dx = y*exp(x*y), d/dy = x*exp(x*y)
        e_xy = exp(x * y)
        dc_dx = y * e_xy
        dc_dy = x * e_xy
        
        out_arr[i] = dc_dx + dc_dy
    end
end

out_diffsym .= 0
out_explicit .= 0
compute_exp_diffsym(x, y, out_diffsym, N)
compute_exp_explicit(x, y, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Exp results don't match!"

println("DiffSym version:")
@btime compute_exp_diffsym($x, $y, $out_diffsym, $N)

println("Explicit version:")
@btime compute_exp_explicit($x, $y, $out_explicit, $N)

# =============================================================================
# Test 4: Complex nested expression
# =============================================================================
println("\n--- Test 4: Complex - (x^2 + y^2)*exp(-x^2 - y^2) ---")

function compute_complex_diffsym(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        @diffsym begin
            r2 = x^2 + y^2
            c = r2 * exp(-r2)
        end derivatives=(dc_dx = (c, x), dc_dy = (c, y))
        
        out_arr[i] = dc_dx + dc_dy
    end
end

function compute_complex_explicit(x_arr, y_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        
        # d/dx[(x^2+y^2)*exp(-(x^2+y^2))] = 2x*exp(-r2) + r2*exp(-r2)*(-2x)
        #                                = 2x*exp(-r2)*(1 - r2)
        r2 = x^2 + y^2
        e_neg_r2 = exp(-r2)
        dc_dx = 2 * x * e_neg_r2 * (1 - r2)
        dc_dy = 2 * y * e_neg_r2 * (1 - r2)
        
        out_arr[i] = dc_dx + dc_dy
    end
end

out_diffsym .= 0
out_explicit .= 0
compute_complex_diffsym(x, y, out_diffsym, N)
compute_complex_explicit(x, y, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Complex results don't match!"

println("DiffSym version:")
@btime compute_complex_diffsym($x, $y, $out_diffsym, $N)

println("Explicit version:")
@btime compute_complex_explicit($x, $y, $out_explicit, $N)

# =============================================================================
# Summary
# =============================================================================
println("\n" * "=" ^ 60)
println("Summary: @diffsym generates code at compile time, so runtime")
println("performance should be nearly identical to explicit expressions.")
println("Any differences are likely due to the optimizer making different")
println("choices for the generated vs hand-written code.")
println("=" ^ 60)
