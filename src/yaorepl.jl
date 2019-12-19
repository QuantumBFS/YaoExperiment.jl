# A Using Case:
"""
yao> cc = let nqubits=4
    2 => X
    3 => C, 1=>C, 4=>X
end

yao> dc = let nqubits=6
    subroutine(1,5,2,3) cc
    3=>Rx(:θ)   # symbolic input
end

yao> reg = bit"000000"

yao> reg |> d

yao> p(rintln) reg

yao> p(rintln) c  # print summary

yao> s(how) reg

yao> c(ode) s reg

yao> m(easure!) [op] reg

yao> reset!(reg, 0)

yao> e(xpect) dc reg

yao> e(xpect)' dc reg

yao> f(idelity)' reg reg

yao> i(nspect) c     # show matrix

yao> l(istvars)    # list symbol table

yao> q(uit)
"""

CmdTable = Dict(
    # query
    'p'=>"print",
    'i'=>"inspect",
    # compute
    'e'=>"expect",
    'f'=>"fidelity",
    'r'=>"reset",
    'm'=>"measure",
    # interactive command
    'l'=>"listvars",
    'c'=>"code",
    'q'=>"quit",
    'h'=>"help",
)

"""
expand shortcuts.
"""
function yaorepl_parse(str)
    length(str) == 0 && return nothing
    str = strip(str, [' ', '\n'])
    if haskey(CmdTable, str[1]) && (length(str) == 1 || str[2] in [' ', '!', '\''])
        args = filter(x-> x!="", split(str, ' '))
        func = get(CmdTable, args[1][1], "noshortcut")
        str = func*args[1][2:end]*'('*join(args[2:end], ", ")*')'
    end
    Meta.parse(str)
end

using Yao, YaoBlocks, MLStyle

const max_repl_nbit = Ref(20)
const max_repl_nbatch = Ref(128)
const max_repl_nshots = Ref(128)

_checkbit(x::Int) = x <= max_repl_nbit[] ? x : error("maximum number of qubits is $(max_repl_nbit[]), got $x.")
_checkbit(x::String) = _checkbit(lengh(x))
_checkbatch(x::Int) = x <= max_repl_nbatch[] ? x : error("maximum number of nbatch is $(max_repl_nbatch[]), got $x.")
_checkshots(x::Int) = x <= max_repl_nshots[] ? x : error("maximum number of nshots is $(max_repl_nshots[]), got $x.")
function _checkfunc(f)
    sf = string(f)
    if sf in values(CmdTable)
        return f
    elseif sf[end] == '!' && sf[1:end-1] in values(CmdTable)
        return f
    else
        error("Expression `$f` can not be parsed to a known function!")
    end
end

_checkreg(a::Symbol) = a
_checkop(a::Symbol) = a

yaorepl_trans(ex) = @match ex begin
    :($x = zero_state($nbit; nbatch=$nbatch)) => :($x = zero_state($(_checkbit(nbit)); nbatch=$(_checkbatch(nbatch))))
    :($x = zero_state($nbit)) => :($x = zero_state($(_checkbit(nbit))))
    :($x = rand_state($nbit; nbatch=$nbatch)) => :($x = rand_state($(_checkbit(nbit)); nbatch=$(_checkbatch(nbatch))))
    :($x = rand_state($nbit)) => :($x = rand_state($(_checkbit(nbit))))
    :($x = [$(args...)]) => :($x = ArrayReg([$(Float64.(args)...)]))
    :($x = @bit_str $line $val) => :($x = @bit_str $(_checkbit(val)))
    :($x = let $(head...); $(body...) end) => :($x = $(YaoBlocks.parse_ex(:(let $(head...); $(body...) end))))
    :(expect($a, $b)) => :(expect($(_checkop(a)), $(_checkreg(b))))
    :(expect'($a, $b)) => :(expect'($(_checkop(a)), $(_checkreg(b))))
    :(fidelity($a, $b)) => :(fidelity($(_checkreg(a)), $(_checkreg(b))))
    :(fidelity'($a, $b)) => :(fidelity'($(_checkreg(a)), $(_checkreg(b))))
    :(measure($a)) => :(measure($(_checkreg(a))))
    :(measure($a; nshots=$nshots)) => :(measure($(_checkreg(a)); nshots=$(_checkshots(nshots))))
    :(measure!($a)) => :(measure!($(_checkreg(a))))
    :(print($a)) => :(print2str($(_checkreg(a))))
    :(inspect($a)) => :(inspect2str($(_checkreg(a))))

    :(code($a)) => :(print2str($(QuoteNode(yaorepl_trans(yaorepl_parse(a))))))
    :(quit()) => :(quit())
    :(help()) => :(help())
    :(listvars($a)) => :(measure($(_checkreg(a))))
    _ => error("Expression `$ex` can not be parsed!")
end

using Test
@testset "yaorepl_parse" begin
    @test yaorepl_parse("e op reg") == :(expect(op, reg))
    @test yaorepl_parse("e' op reg") == :(expect'(op, reg))
    @test yaorepl_parse("m! reg") == :(measure!(reg))
    @test yaorepl_parse("c x") == :(code(x))
    @test yaorepl_parse("c ") == :(code())
    @test yaorepl_parse("cr(x)") == :(cr(x))
    @test yaorepl_parse("3=>X") == :(3=>X)
end

@testset "yaorepl_trans" begin
    @test yaorepl_trans(:(expect(op, reg))) == :(expect(op, reg))
    @test yaorepl_trans(:(expect'(op, reg))) == :(expect'(op, reg))
    @test yaorepl_trans(:(measure!(reg))) == :(measure!(reg))
    @test yaorepl_trans(:(code("e X reg"))) == :(print2str($(QuoteNode(:(expect(X, reg))))))
    @test yaorepl_trans(:(help())) == :(help())
    @test_throws ErrorException yaorepl_trans(:(code())) == :(code())
    @test_throws ErrorException yaorepl_trans(:(cr(x)))
    @test yaorepl_trans(:(reg = zero_state(5))) == :(reg = zero_state(5))
    @test yaorepl_trans(:(reg = zero_state(5; nbatch=10))) == :(reg = zero_state(5; nbatch=10))
end

function yaorepl_execute(ex, session_dict)
    @match ex begin
        :($x = $expr) => begin
            session_dict[Symbol(x)] = eval(expr)
            nothing
        end
        :($f($(args...))) => begin
            nargs = [haskey(session_dict, arg) ? session_dict[arg] : arg for arg in args]
            eval(:($f($(nargs...))))
        end
    end
end

function help()
    return "this is help!"
end

function inspect(io::IO, b::AbstractBlock)
    print(io, mat(b))
end

function inspect(io::IO, reg::AbstractRegister)
    print(io, statevec(reg))
end

function print2str(obj)
    io = IOBuffer()
    print(io, obj)
    String(take!(io))
end

function inspect2str(obj)
    io = IOBuffer()
    inspect(io, obj)
    String(take!(io))
end

function yaorepl_handler(str::String, session_dict::Dict{Symbol, Any})
    yaorepl_execute(yaorepl_trans(yaorepl_parse(str)), session_dict)
end

function yaorepl()
    d = Dict{Symbol,Any}()
    while true
        printstyled(stdout, "\nws|client input >  ", color=:green)
        msg = readline(stdin)
        try
            res = yaorepl_handler(msg, d)
            if res isa String
                println(res)
            elseif res === false
                break
            elseif res === nothing
            else
                error("fail to explain output $res")
            end
        catch e
            print(e)
        end
    end
end
