export @fixture
export yield_fixture

function yield_fixture(args...)
  error("yield_fixture must be in the top level of scope within @fixture function")
end

function flatten_nested_block(ex::Expr)
  if ex.head==:block && length(ex.args)==1 && ex.args[1].head==:block
    return flatten_nested_block(ex.args[1])
  elseif ex.head==:block && length(ex.args)==2 && ex.args[1].head==:line && ex.args[2].head==:block
    return flatten_nested_block(ex.args[2])
  elseif ex.head==:block && length(ex.args)==2 && ex.args[2].head==:block
    return flatten_nested_block(Expr(:block, ex.args[1], ex.args[2].args...))
  else
    return ex
  end
end

macro fixture(ex::Expr)
  if (ex.head == :function || ex.head == :(=)) && ex.args[1].head == :call
    if length(ex.args[1].args)>=2 && isa(ex.args[1].args[2],Expr) && ex.args[1].args[2].head==:parameters
      # Add ecbf47d557eb469c9fc755f8e07f11f7::Function between the parameters and the other arguments
      ex.args[1].args = Any[ex.args[1].args[1:2]..., :(ecbf47d557eb469c9fc755f8e07f11f7::Function), ex.args[1].args[3:]...]
    else
      # Add ecbf47d557eb469c9fc755f8e07f11f7::Function between the name and the other arguments
      ex.args[1].args = Any[ex.args[1].args[1], :(ecbf47d557eb469c9fc755f8e07f11f7::Function), ex.args[1].args[2:]...]
    end
  elseif ex.head == :-> && length(ex.args) == 1
    # Add ecbf47d557eb469c9fc755f8e07f11f7::Function there are no other arguments
    ex.args = Any[:(ecbf47d557eb469c9fc755f8e07f11f7::Function), ex.args...]
  elseif ex.head == :-> && isa(ex.args[1], Symbol) || ex.args[1].head!=:tuple
    # Add ecbf47d557eb469c9fc755f8e07f11f7::Function before the (single) other argument
    ex.args[1] = Expr(:tuple, :(ecbf47d557eb469c9fc755f8e07f11f7::Function), ex.args[1])
  elseif (ex.head == :function || ex.head == :->) && ex.args[1].head == :tuple
    # Add ecbf47d557eb469c9fc755f8e07f11f7::Function as the first argument
    ex.args[1].args = Any[:(ecbf47d557eb469c9fc755f8e07f11f7::Function), ex.args[1].args...]
  else
    error("@fixture can only be applied to methods/functions/lambdas")
  end

  const body = flatten_nested_block(ex.args[end])
  if body.head == :block
    const i = findfirst(body.args) do v
      if isa(v, Expr) && v.head==:call && v.args[1]==:yield_fixture
        true
      else
        false
      end
    end
    if i>0
      # Copy the call so that we get any arguments
      const call_expr = copy(body.args[i])
      call_expr.args[1] = :ecbf47d557eb469c9fc755f8e07f11f7

      body.args = Any[body.args[1:(i-1)]...,
                     quote
                       try
                         return $call_expr
                       finally
                         $(Expr(:block, body.args[(i+1):end]...))
                       end
                     end
                  ]
    else
      body.args = Any[body.args..., :(ecbf47d557eb469c9fc755f8e07f11f7())]
    end
  else
    error("Expected a :block got a $(body.head)")
  end

  # Put the new body in
  ex.args[end] = body

  return esc(ex)
end
