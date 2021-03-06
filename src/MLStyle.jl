module MLStyle

# Flags
export @use, use, @used
# Match Implementation
export @match, gen_match
# DataTypes
export @data
# Pervasive Patterns
export Many, Do
# Active Patterns
export @active
# Extensibilities
export def_pattern_def_app_pattern_def_gapp_pattern_mk_pattern_mk_app_pattern_mk_gapp_pattern
# Exceptions
export PatternUnsolvedException, InternalException, SyntaxError, UnknownExtension, @syntax_err
# Syntax Sugars
export @λ, gen_lambda
export @when, gen_when


include("Err.jl")
using MLStyle.Err

include("Extension.jl")
using MLStyle.Extension

include("toolz.jl")

include("Render.jl")

include("MatchCore.jl")
using MLStyle.MatchCore

include("Infras.jl")
using MLStyle.Infras

include("Pervasives.jl")
using MLStyle.Pervasives


include("StandardPatterns.jl")
using MLStyle.StandardPatterns

include("DataType.jl")
using MLStyle.DataType

"""
Code generation for `@λ`.
The first argument must be something like
- `a -> b`
- `begin a -> b; (c -> d)... end`
"""
function gen_lambda(cases, source :: LineNumberNode, _ :: Module)
    TARGET = gensym("λ")
    @match cases begin
        :($a -> $(b...)) =>
                @format [TARGET, source, case=a, body=Expr(:block, b...)] quote
                    source
                    function (TARGET)
                        $MLStyle.@match source TARGET begin
                            case => body
                        end
                    end
                end

        Do(stmts=[]) &&
        :(begin
            $(Many(:($a -> $(b...)) &&
            Do(push!(stmts, :($a => begin $(b...) end))) ||

            (a :: LineNumberNode) && Do(push!(stmts , a))
            )...)
          end) =>
            @format [TARGET, source, cases = Expr(:block, stmts...)] quote
                source
                function (TARGET)
                    $MLStyle.@match source TARGET cases
                end
            end
        _ => @syntax_err "Syntax error in lambda case definition. Check if your arrow is `->` but not `=>`!"

    end
end

"""
Code generation for `@when`.
You should pass an `Expr(:let, ...)` as the first argument.
"""
function gen_when(let_expr, source :: LineNumberNode, mod :: Module)
    @match let_expr begin
        Expr(:let, Expr(:block, bindings...) ||  a && Do(bindings = [a]), ret) =>
            foldr(bindings, init=ret) do each, last
                @match each begin
                    :($a = $b) =>
                        @format [a, b, last, source] quote
                            $MLStyle.@match source b begin
                                a => last
                                _ => nothing
                            end
                        end
                    a => :(let $a; $last end)
                end
            end

        Expr(a, _...) => @syntax_err "Expect a let-binding, but found a `$a` expression."
        _ => @syntax_err "Expect a let-binding."
    end
end

"""
1. Allow destructuring in binding sequences of let syntax.

In binding sequences,
- For the bindings with the form `a = b`, you can use destructuring here.
- For others like `@inline f(x) = 1`, it's the same as the original let binding.

@when let (a, 1) = x,
          [b, c, 5] = y
        (a, b, c)
end

2. For a regular assignment, like
```
@when (a, 2) = x begin
    # dosomething
end
```
It's nothing different with
```
@match x begin
    (a, 2) => # dosomething
    _ => nothing
end
```
"""
macro when(let_expr)
    gen_when(let_expr, __source__, __module__) |> esc
end

macro when(assignment, ret)
    @match assignment begin
        :($_ = $_) =>
            let let_expr = Expr(:let, Expr(:block, assignment), ret)
                gen_when(let_expr, __source__, __module__) |> esc
            end
        _ => @syntax_err "Not match the form of `@when a = b expr`"
    end
end

"""
Lambda cases.
e.g.
map((@λ (1, x) -> x), xs)

(2, 3) |> @λ begin
    1 -> 2
    2 -> 7
    (a, b) -> a + b
end

# 5
"""
macro λ(cases)
    gen_lambda(cases, __source__, __module__) |> esc
end

macro stagedexpr(exp)
    __module__.eval(exp)
end


end # module