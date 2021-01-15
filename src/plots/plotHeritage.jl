mutable struct pos
    wave::Int
    pos::Float64
    ndaughters::Int
end

function plotDivisionTree(c::CommunityInTime, color::Symbol, cmap::String="Reds")

fate = c[color]
fate = floor.(99 .*(fate .-minimum(fate))./(maximum(fate)-minimum(fate))).+1


d = Dict{Int,pos}
s = 0

figure = linesegments([0],[0])

for (t,com) in enumerate(c.com)
    id = Int.(com[:id_])
    parent = Int.(com[:parent_])
    
    for (i,j) in zip(id,parent)
        if !(i in key(d))
            if j == -1
                d[i] = pos(0,s,0)
                s += 1
                figure = linesegments!(t:t+1,[s,s])
            else
                wave = d[j].wave+1
                d[j].daughters += 1
                son = d[j].daughters
                posnew = d[j].pos+(-1)^d[j].daughters*0.25/wave
                d[i] = pos(wave,d[j][1]*0.25,0)
                figure = linesegments!(t:t+1,[posnew,posnew])                    
            end
        else
            figure = linesegments!(t:t+1,[d[i][2],d[i][2]])
        end
    end
end

return figure
end