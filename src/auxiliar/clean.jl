"""
Cleans a complex expression. It is very helpful for debuging the compiled model evolve function after parsing everything.

# Arguments
 - **a** (Expr) Expression to be cleaned

# Returns

nothing
"""
function clean(a)
    m = string(a)
    m = replace(m,"=# "=>"=#\n\t\t\t\t")
    l = split(m,"\n")
    f = ""
    counter = 1
    for i in l
        if occursin("begin",i)
            counter += 4
        else
            if occursin("end",i) && length(i) == 3+counter-5
                counter -= 4
            else
                i = i[counter:end]
                if occursin("#=",i) && occursin("=#",i)
                    1
                else
                    f = string(f,"\t",i,"\n")
                end
            end
        end
    end
    
    return f
end