"""
Cleans a complex expression. It is very helpful for debuging the compiled model evolve function after parsing everything.

# Arguments
 - **a** (Expr) Expression to be cleaned

# Returns

nothing
"""
function clean(a)
    a = string(a)
    v = split(a,"\n")
    s = ""
    for i in v
        v2 = split(i,"=#")
        for j in v2
            if !contains(j,"#=")
                s = string(s,"\n",j)
            end
        end
    end

    println(s[2:end])

    return
end