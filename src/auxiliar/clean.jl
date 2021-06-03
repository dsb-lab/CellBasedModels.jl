"""
    function clean(a)

Cleans the complex print of an expression to make it more clear to see.
"""
function clean(a::Expr)
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