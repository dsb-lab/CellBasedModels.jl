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