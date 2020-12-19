function clean(a)
    a = string(a)
    v = split(a,"\n")
    s = ""
    for i in v
        if !contains(i,"#=")
            s = string(s,"\n",i)
        end
    end

    println(s[2:end])

    return
end