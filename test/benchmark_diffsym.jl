using CellBasedModels
using BenchmarkTools
using Statistics
using MacroTools

println("=" ^ 70)
println("Benchmarking @diffsym: COMPILE TIME + RUNTIME")
println("=" ^ 70)

# Helper to measure compile time by evaluating a fresh function definition
function measure_compile_time(make_expr::Function, n_runs=5)
    times = Float64[]
    for i in 1:n_runs
        fname = Symbol("test_func_$(i)_$(rand(UInt32))")
        expr = make_expr(fname)
        t = @elapsed eval(expr)
        push!(times, t)
    end
    return times
end

N = 100_000
x_data = rand(N)
y_data = rand(N)
z_data = rand(N)
w_data = rand(N)
α_param = 0.5
out_diffsym = zeros(N)
out_explicit = zeros(N)

# =============================================================================
# Test 1: Simple polynomial derivative (2 derivatives)
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 1: Simple polynomial x² + y² (2 derivatives)")
println("=" ^ 70)

# Define diffsym version
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
        dc_dx = 2 * x
        dc_dy = 2 * y
        out_arr[i] = dc_dx + dc_dy
    end
end

# Measure compile time
println("\nCompile time (5 runs):")
times1 = measure_compile_time(5) do fname
    quote
        function $fname(x_arr, y_arr, out_arr, N)
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
    end
end
println("  Times: $(round.(times1 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times1)*1000, digits=1)) ms")

# Warm up and verify
compute_with_diffsym(x_data, y_data, out_diffsym, N)
compute_explicit(x_data, y_data, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Results don't match!"

println("\nRuntime:")
print("  DiffSym:  "); @btime compute_with_diffsym($x_data, $y_data, $out_diffsym, $N)
print("  Explicit: "); @btime compute_explicit($x_data, $y_data, $out_explicit, $N)

# =============================================================================
# Test 2: Trigonometric (2 derivatives)
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 2: Trigonometric sin(x)² + cos(y)² (2 derivatives)")
println("=" ^ 70)

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
        dc_dx = 2 * sin(x) * cos(x)
        dc_dy = -2 * cos(y) * sin(y)
        out_arr[i] = dc_dx + dc_dy
    end
end

println("\nCompile time (5 runs):")
times2 = measure_compile_time(5) do fname
    quote
        function $fname(x_arr, y_arr, out_arr, N)
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
    end
end
println("  Times: $(round.(times2 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times2)*1000, digits=1)) ms")

out_diffsym .= 0; out_explicit .= 0
compute_trig_diffsym(x_data, y_data, out_diffsym, N)
compute_trig_explicit(x_data, y_data, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Trig results don't match!"

println("\nRuntime:")
print("  DiffSym:  "); @btime compute_trig_diffsym($x_data, $y_data, $out_diffsym, $N)
print("  Explicit: "); @btime compute_trig_explicit($x_data, $y_data, $out_explicit, $N)

# =============================================================================
# Test 3: Complex nested (2 derivatives)
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 3: Complex (x² + y²)*exp(-(x² + y²)) (2 derivatives)")
println("=" ^ 70)

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
        r2 = x^2 + y^2
        e_neg_r2 = exp(-r2)
        dc_dx = 2 * x * e_neg_r2 * (1 - r2)
        dc_dy = 2 * y * e_neg_r2 * (1 - r2)
        out_arr[i] = dc_dx + dc_dy
    end
end

println("\nCompile time (5 runs):")
times3 = measure_compile_time(5) do fname
    quote
        function $fname(x_arr, y_arr, out_arr, N)
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
    end
end
println("  Times: $(round.(times3 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times3)*1000, digits=1)) ms")

out_diffsym .= 0; out_explicit .= 0
compute_complex_diffsym(x_data, y_data, out_diffsym, N)
compute_complex_explicit(x_data, y_data, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, atol=1e-10)) "Complex results don't match!"

println("\nRuntime:")
print("  DiffSym:  "); @btime compute_complex_diffsym($x_data, $y_data, $out_diffsym, $N)
print("  Explicit: "); @btime compute_complex_explicit($x_data, $y_data, $out_explicit, $N)

# =============================================================================
# Test 4: 6 derivatives
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 4: E = r²*exp(-α*r²) with 6 derivatives")
println("=" ^ 70)

function compute_many_diffsym(x_arr, y_arr, z_arr, w_arr, out_arr, N, α_param)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        zz = z_arr[i]
        ww = w_arr[i]
        α = α_param
        @diffsym begin
            r2 = x^2 + y^2 + zz^2 + ww^2
            E = r2 * exp(-α * r2)
        end derivatives=(
            dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz), dE_dw = (E, ww),
            dE_dα = (E, α), dr2_dx = (r2, x)
        )
        out_arr[i] = dE_dx + dE_dy + dE_dz + dE_dw + dE_dα + dr2_dx
    end
end

function compute_many_explicit(x_arr, y_arr, z_arr, w_arr, out_arr, N, α_param)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        zz = z_arr[i]
        ww = w_arr[i]
        α = α_param
        r2 = x^2 + y^2 + zz^2 + ww^2
        exp_neg_αr2 = exp(-α * r2)
        factor = exp_neg_αr2 * (1 - α*r2)
        dE_dx = 2*x * factor
        dE_dy = 2*y * factor
        dE_dz = 2*zz * factor
        dE_dw = 2*ww * factor
        dE_dα = -r2^2 * exp_neg_αr2
        dr2_dx = 2*x
        out_arr[i] = dE_dx + dE_dy + dE_dz + dE_dw + dE_dα + dr2_dx
    end
end

println("\nCompile time (5 runs):")
times4 = measure_compile_time(5) do fname
    quote
        function $fname(x_arr, y_arr, z_arr, w_arr, out_arr, N, α_param)
            @inbounds for i in 1:N
                x = x_arr[i]
                y = y_arr[i]
                zz = z_arr[i]
                ww = w_arr[i]
                α = α_param
                @diffsym begin
                    r2 = x^2 + y^2 + zz^2 + ww^2
                    E = r2 * exp(-α * r2)
                end derivatives=(
                    dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz), dE_dw = (E, ww),
                    dE_dα = (E, α), dr2_dx = (r2, x)
                )
                out_arr[i] = dE_dx + dE_dy + dE_dz + dE_dw + dE_dα + dr2_dx
            end
        end
    end
end
println("  Times: $(round.(times4 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times4)*1000, digits=1)) ms")

out_diffsym .= 0; out_explicit .= 0
compute_many_diffsym(x_data, y_data, z_data, w_data, out_diffsym, N, α_param)
compute_many_explicit(x_data, y_data, z_data, w_data, out_explicit, N, α_param)
@assert all(isapprox.(out_diffsym, out_explicit, rtol=1e-10)) "6-deriv results don't match!"

println("\nRuntime:")
print("  DiffSym:  "); @btime compute_many_diffsym($x_data, $y_data, $z_data, $w_data, $out_diffsym, $N, $α_param)
print("  Explicit: "); @btime compute_many_explicit($x_data, $y_data, $z_data, $w_data, $out_explicit, $N, $α_param)

# =============================================================================
# Test 5: 9 derivatives (polynomial)
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 5: Polynomial with 9 derivatives")
println("=" ^ 70)

function compute_poly_diffsym(x_arr, y_arr, z_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        zz = z_arr[i]
        @diffsym begin
            u = x^3 + 2*x^2*y + 3*x*y^2 + 4*y^3 + zz^2
            v = x^2*zz + y^2*zz + x*y*zz + zz^3
            E = u + v
        end derivatives=(
            du_dx = (u, x), du_dy = (u, y), du_dz = (u, zz),
            dv_dx = (v, x), dv_dy = (v, y), dv_dz = (v, zz),
            dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz)
        )
        out_arr[i] = du_dx + du_dy + du_dz + dv_dx + dv_dy + dv_dz + dE_dx + dE_dy + dE_dz
    end
end

function compute_poly_explicit(x_arr, y_arr, z_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        zz = z_arr[i]
        du_dx = 3*x^2 + 4*x*y + 3*y^2
        du_dy = 2*x^2 + 6*x*y + 12*y^2
        du_dz = 2*zz
        dv_dx = 2*x*zz + y*zz
        dv_dy = 2*y*zz + x*zz
        dv_dz = x^2 + y^2 + x*y + 3*zz^2
        dE_dx = du_dx + dv_dx
        dE_dy = du_dy + dv_dy
        dE_dz = du_dz + dv_dz
        out_arr[i] = du_dx + du_dy + du_dz + dv_dx + dv_dy + dv_dz + dE_dx + dE_dy + dE_dz
    end
end

println("\nCompile time (5 runs):")
times5 = measure_compile_time(5) do fname
    quote
        function $fname(x_arr, y_arr, z_arr, out_arr, N)
            @inbounds for i in 1:N
                x = x_arr[i]
                y = y_arr[i]
                zz = z_arr[i]
                @diffsym begin
                    u = x^3 + 2*x^2*y + 3*x*y^2 + 4*y^3 + zz^2
                    v = x^2*zz + y^2*zz + x*y*zz + zz^3
                    E = u + v
                end derivatives=(
                    du_dx = (u, x), du_dy = (u, y), du_dz = (u, zz),
                    dv_dx = (v, x), dv_dy = (v, y), dv_dz = (v, zz),
                    dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz)
                )
                out_arr[i] = du_dx + du_dy + du_dz + dv_dx + dv_dy + dv_dz + dE_dx + dE_dy + dE_dz
            end
        end
    end
end
println("  Times: $(round.(times5 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times5)*1000, digits=1)) ms")

out_diffsym .= 0; out_explicit .= 0
compute_poly_diffsym(x_data, y_data, z_data, out_diffsym, N)
compute_poly_explicit(x_data, y_data, z_data, out_explicit, N)
@assert all(isapprox.(out_diffsym, out_explicit, rtol=1e-10)) "9-deriv results don't match!"

println("\nRuntime:")
print("  DiffSym:  "); @btime compute_poly_diffsym($x_data, $y_data, $z_data, $out_diffsym, $N)
print("  Explicit: "); @btime compute_poly_explicit($x_data, $y_data, $z_data, $out_explicit, $N)

# =============================================================================
# Test 6: 12 derivatives (stress test)
# =============================================================================
println("\n" * "=" ^ 70)
println("Test 6: Mixed expressions with 12 derivatives (stress test)")
println("=" ^ 70)

function compute_stress_diffsym(x_arr, y_arr, z_arr, w_arr, out_arr, N)
    @inbounds for i in 1:N
        x = x_arr[i]
        y = y_arr[i]
        zz = z_arr[i]
        ww = w_arr[i]
        @diffsym begin
            r2 = x^2 + y^2 + zz^2 + ww^2
            u = x^2*y + y^2*zz + zz^2*ww + ww^2*x
            v = sin(x*y) * cos(zz*ww)
            E = u * exp(-r2) + v
        end derivatives=(
            dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz), dE_dw = (E, ww),
            du_dx = (u, x), du_dy = (u, y), du_dz = (u, zz), du_dw = (u, ww),
            dv_dx = (v, x), dv_dy = (v, y), dv_dz = (v, zz), dv_dw = (v, ww)
        )
        out_arr[i] = dE_dx + dE_dy + dE_dz + dE_dw + du_dx + du_dy + du_dz + du_dw + dv_dx + dv_dy + dv_dz + dv_dw
    end
end

println("\nCompile time (3 runs):")
times6 = measure_compile_time(3) do fname
    quote
        function $fname(x_arr, y_arr, z_arr, w_arr, out_arr, N)
            @inbounds for i in 1:N
                x = x_arr[i]
                y = y_arr[i]
                zz = z_arr[i]
                ww = w_arr[i]
                @diffsym begin
                    r2 = x^2 + y^2 + zz^2 + ww^2
                    u = x^2*y + y^2*zz + zz^2*ww + ww^2*x
                    v = sin(x*y) * cos(zz*ww)
                    E = u * exp(-r2) + v
                end derivatives=(
                    dE_dx = (E, x), dE_dy = (E, y), dE_dz = (E, zz), dE_dw = (E, ww),
                    du_dx = (u, x), du_dy = (u, y), du_dz = (u, zz), du_dw = (u, ww),
                    dv_dx = (v, x), dv_dy = (v, y), dv_dz = (v, zz), dv_dw = (v, ww)
                )
                out_arr[i] = dE_dx + dE_dy + dE_dz + dE_dw + du_dx + du_dy + du_dz + du_dw + dv_dx + dv_dy + dv_dz + dv_dw
            end
        end
    end
end
println("  Times: $(round.(times6 .* 1000, digits=1)) ms")
println("  Median: $(round(median(times6)*1000, digits=1)) ms")

compute_stress_diffsym(x_data, y_data, z_data, w_data, out_diffsym, N)
println("\nRuntime:")
print("  DiffSym:  "); @btime compute_stress_diffsym($x_data, $y_data, $z_data, $w_data, $out_diffsym, $N)

# =============================================================================
# Summary Table
# =============================================================================
println("\n" * "=" ^ 70)
println("SUMMARY")
println("=" ^ 70)
println("| Test | # Derivs | Compile (ms) |")
println("|------|----------|--------------|")
println("| 1    | 2        | $(lpad(round(median(times1)*1000, digits=1), 12)) |")
println("| 2    | 2        | $(lpad(round(median(times2)*1000, digits=1), 12)) |")
println("| 3    | 2        | $(lpad(round(median(times3)*1000, digits=1), 12)) |")
println("| 4    | 6        | $(lpad(round(median(times4)*1000, digits=1), 12)) |")
println("| 5    | 9        | $(lpad(round(median(times5)*1000, digits=1), 12)) |")
println("| 6    | 12       | $(lpad(round(median(times6)*1000, digits=1), 12)) |")
println("=" ^ 70)
