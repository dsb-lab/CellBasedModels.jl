macro addOne(var, n)

    code = quote
        _nn_ = CellBasedModels.@atomic $var.$n._NAdded[1] += 1     
        _nn_ += $var.$n._N[1]
        if _nn_ > $var.$n._NCache[1]
            _ = CellBasedModels.@atomic $var.$n._NOverflow[1] += 1
            $var._FlagOverflow[1] = true
            _nn_ = 0
        end
    end

    return esc(code)

end

macro markEdge!(ex...)

    if length(ex) != 2
        error("markEdge!: incorrect number of arguments provided. Expected (AgentPolylineObject, edgePosition).")
    end
    var = ex[1]
    e1 = ex[2]

    code = quote
        _threadId_ = @index(Global)
        _n1_, _n2_ = $var.e.nodes[$e1]
        _threadIdWinnerN1_ = Atomix.@atomic $var.n._EventThread[_n1_] = max($var.n._EventThread[_n1_], _threadId_)
        _threadIdWinnerN2_ = Atomix.@atomic $var.n._EventThread[_n2_] = max($var.n._EventThread[_n2_], _threadId_)
        _threadIdWinnerE_ = Atomix.@atomic $var.e._EventThread[$e1] = max($var.e._EventThread[$e1], _threadId_)
        if _threadIdWinnerE_ == _threadId_ && _threadIdWinnerN1_ == _threadId_ && _threadIdWinnerN2_ == _threadId_
            _eventId_ = Atomix.@atomic $var._EventId[$e1] += 1 
            Atomix.@atomic $var.n._EventId[_n1_] = _eventId_
            Atomix.@atomic $var.n._EventId[_n2_] = _eventId_
            Atomix.@atomic $var.e._EventId[$e1] = _eventId_
        end
    end

    return esc(code)

end

macro getEdgeEvent(var, e1)

    code = quote
        _n1_, _n2_ = $var.e.nodes[$e1]
        _eventIdN1_ = $var.n._EventId[_n1_]
        _eventIdN2_ = $var.n._EventId[_n2_]
        _eventIdE_ = $var.e._EventId[$e1]
        _n1_, _n2_, _eventIdN1_ == _eventIdN2_ && _eventIdN1_ == _eventIdE_ && _eventIdN1_ != 0
    end

    return esc(code)

end

macro markEdge2!(ex...)

    if length(ex) != 2
        error("markEdge!: incorrect number of arguments provided. Expected (AgentPolylineObject, edgePosition).")
    end
    var = ex[1]
    e1 = ex[2]

    code = quote
        _threadId_ = @index(Global)
        _n1_, _n2_ = $var.e.nodes[$e1]
        _e1_, _ = $var.n._neighbors[_n1_]
        _, _e2_ = $var.n._neighbors[_n2_]
        _threadIdWinnerN1_ = Atomix.@atomic $var.n._EventThread[_n1_] = max($var.n._EventThread[_n1_], _threadId_)
        _threadIdWinnerN2_ = Atomix.@atomic $var.n._EventThread[_n2_] = max($var.n._EventThread[_n2_], _threadId_)
        _threadIdWinnerE_ = Atomix.@atomic $var.e._EventThread[$e1] = max($var.e._EventThread[$e1], _threadId_)
        _threadIdWinnerE1_ = Atomix.@atomic $var.e._EventThread[_e1_] = max($var.e._EventThread[_e1_], _threadId_)
        _threadIdWinnerE2_ = Atomix.@atomic $var.e._EventThread[_e2_] = max($var.e._EventThread[_e2_], _threadId_)
        if _threadIdWinnerE_ == _threadId_ && _threadIdWinnerN1_ == _threadId_ && _threadIdWinnerN2_ == _threadId_ && _threadIdWinnerE1_ == _threadId_ && _threadIdWinnerE2_ == _threadId_
            _eventId_ = Atomix.@atomic $var._EventId[$e1] += 1 
            Atomix.@atomic $var.n._EventId[_n1_] = _eventId_
            Atomix.@atomic $var.n._EventId[_n2_] = _eventId_
            Atomix.@atomic $var.e._EventId[$e1] = _eventId_
            Atomix.@atomic $var.e._EventId[_e1_] = _eventId_
            Atomix.@atomic $var.e._EventId[_e2_] = _eventId_
        end
    end

    return esc(code)

end

macro getEdgeEvent2(var, e1)

    code = quote
        _n1_, _n2_ = $var.e.nodes[$e1]
        _e1_, _ = $var.n._neighbors[_n1_]
        _, _e2_ = $var.n._neighbors[_n2_]
        _eventIdN1_ = $var.n._EventId[_n1_]
        _eventIdN2_ = $var.n._EventId[_n2_]
        _eventIdE_ = $var.e._EventId[$e1]
        _eventIdE1_ = $var.e._EventId[_e1_]
        _eventIdE2_ = $var.e._EventId[_e2_]
        _n1_, _n2_, _e1_, _e2_, _eventIdN1_ == _eventIdN2_ && _eventIdN1_ == _eventIdE_ && _eventIdN1_ == _eventIdE1_ && _eventIdN1_ == _eventIdE2_ && _eventIdN1_ != 0
    end

    return esc(code)

end 

macro markAgent!(ex...)

    if length(ex) != 2
        error("markAgent!: incorrect number of arguments provided. Expected (AgentPolylineObject, agentIndex).")
    end
    var = ex[1]
    agentIndex = ex[2]

    code = quote
        _threadId_ = @index(Global)
        _suceed_ = true
        # Tag edges
        for _e1_ in iterateOverAgentEdges($var, $agentIndex)
            _threadIdWinnerN1_ = Atomix.@atomic $var.n._EventThread[_n1_] = max($var.n._EventThread[_n1_], _threadId_)
            succeed_ = succeed_ && (_threadIdWinnerN1_ == _threadId_)
        end
        # Tag nodes
        for _n1_ in iterateOverAgentNodes($var, $agentIndex)
            _threadIdWinnerE_ = Atomix.@atomic $var.e._EventThread[_e1_] = max($var.e._EventThread[_e1_], _threadId_)
            succeed_ = succeed_ && (_threadIdWinnerE_ == _threadId_)
        end
        #Tag agent
        if _suceed_
            Atomix.@atomic $var.a._EventThread[$agentIndex] = max($var.a._EventThread[$agentIndex], _threadId_)
        end
    end

    return esc(code)
end
