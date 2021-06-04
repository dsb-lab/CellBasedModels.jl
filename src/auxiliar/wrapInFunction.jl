"""
    function wrapInFunction_(name, code)

Return **code** wrapped in a function called **name** and which returns nothing.
"""
function wrapInFunction_(name::Symbol, code::Expr)
    code = 
        :(function $name(ARGUMENTS_)
            $code
            return nothing
        end
        )

    return code
end