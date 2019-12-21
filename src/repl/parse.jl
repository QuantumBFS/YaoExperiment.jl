# A Using Case:
"""
yao> nqubits(4)

yao> cc = begin
    2 => X
    3 => C, 1=>C, 4=>X
end

yao> nqubits(6)

yao> dc = begin
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
    'h'=>"help",
)

struct YaoREPLState
    regs::Dict{Symbol,Any}
    blocks::Dict{Symbol,Any}
    parseinfo::YaoBlocks.ParseInfo
end
YaoREPLState() = YaoREPLState(Dict{Symbol,Any}(), Dict{Symbol,Any}(), YaoBlocks.ParseInfo(-1, ""))

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

const max_repl_nbit = Ref(20)
const max_repl_nbatch = Ref(128)
const max_repl_nshots = Ref(128)

_checkbit(x::Int) = x <= max_repl_nbit[] ? x : error("maximum number of qubits is $(max_repl_nbit[]), got $x.")
_checkbit(x::String) = (_checkbit(length(x)); x)
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

yaorepl_trans(ex, state) = @match ex begin
    :($x = zero_state($nbit, nbatch=$nbatch)) => :($x = zero_state($(_checkbit(nbit)), nbatch=$(_checkbatch(nbatch))))
    :($x = zero_state($nbit)) => :($x = zero_state($(_checkbit(nbit))))
    :($x = rand_state($nbit, nbatch=$nbatch)) => :($x = rand_state($(_checkbit(nbit)), nbatch=$(_checkbatch(nbatch))))
    :($x = rand_state($nbit)) => :($x = rand_state($(_checkbit(nbit))))
    :($x = [$(args...)]) => :($x = ArrayReg(ComplexF64[$(Float64.(args)...)]))
    :($x = @bit_str $line $val) => :($x = ArrayReg(@bit_str $(_checkbit(val))))
    :($x = $ex) => begin
        blk = YaoBlocks.parse_ex(ex, state.parseinfo)
        :($x = $blk)
    end
    :(expect($a, $b=>$c)) => :(expect($(_checkop(a)), $(_checkreg(b))=>$(_checkop(c))))
    :(expect'($a, $b=>$c)) => :(expect'($(_checkop(a)), $(_checkreg(b))=>$(_checkop(c))))
    :(expect($a, $b)) => :(expect($(_checkop(a)), $(_checkreg(b))))
    :(expect'($a, $b)) => :(expect'($(_checkop(a)), $(_checkreg(b))))
    :(fidelity($a=>$oa, $b=>$ob)) => :(fidelity($(_checkreg(a))=>$(_checkop(oa)), $(_checkreg(b))=>$(_checkop(ob))))
    :(fidelity'($a=>$oa, $b=>$ob)) => :(fidelity'($(_checkreg(a))=>$(_checkop(oa)), $(_checkreg(b))=>$(_checkop(ob))))
    :(fidelity($a, $b)) => :(fidelity($(_checkreg(a)), $(_checkreg(b))))
    :(fidelity'($a, $b)) => :(fidelity'($(_checkreg(a)), $(_checkreg(b))))
    :(measure($a)) => :(measure($(_checkreg(a))))
    :(measure($a, nshots=$nshots)) => :(measure($(_checkreg(a)), nshots=$(_checkshots(nshots))))
    :(measure($op, $a)) => :(measure($(_checkop(op)), $(_checkreg(a))))
    :(measure($op, $a, nshots=$nshots)) => :(measure($(_checkop(op)), $(_checkreg(a)), nshots=$(_checkshots(nshots))))
    :(measure!($a)) => :(measure!($(_checkreg(a))))
    :(measure!($op, $a)) => :(measure!($(_checkop(op)), $(_checkreg(a))))
    :(print($a)) => :(print2str($(_checkreg(a))))
    :(inspect($a)) => :(inspect2str($(_checkreg(a))))
    :($x |> $y) => :(apply!($x, $y))

    :(help()) => :(help())
    :(listvars()) => :(listvars($state))
    :(nbits($n)) => :(setnbits!($n, $state))
    :(nbits()) => :(getnbits($state))
    _ => error("Expression `$ex` can not be translated!")
end

function yaorepl_execute(ex, state)
    @match ex begin
        :($x = $expr) => begin
            var = eval(expr)
            if var isa AbstractRegister
                state.regs[Symbol(x)] = var
            elseif var isa AbstractBlock
                state.blocks[Symbol(x)] = var
            else
                error("incorrect assignment with return value $var.")
            end
            "done"
        end
        :($f($(args...))) => begin
            nargs = [query_state(state, arg) for arg in args]
            res = eval(:($f($(nargs...))))
            if res isa AbstractString
                res
            elseif res isa Nothing
                "done"
            else
                io = IOBuffer()
                Base.show(io, "text/plain", res)
                String(take!(io))
            end
        end
    end
end

function query_state(state::YaoREPLState, arg)
    @match arg begin
        :($a => $b) => :($(query_state(state, a)) => $(query_state(state, b)))
        ::Symbol => begin
            if haskey(state.regs, arg)
                state.regs[arg]
            elseif haskey(state.blocks, arg)
                state.blocks[arg]
            else
                arg
            end
        end
        _ => arg
    end
end

function listvars(state)
    regstr = ["$k ($(nqubits(v)))" for (k,v) in state.regs]
    blkstr = ["$k ($(nqubits(v)))" for (k,v) in state.blocks]
    join(["current nbits = $(state.parseinfo.nbit)\n", "=== registers ===", regstr..., "\n=== blocks ===", blkstr...], "\n")
end

function setnbits!(n::Int, state)
    state.parseinfo.nbit = Int(n)
    "qubit number is set to $n"
end

function getnbits(state)
    "qubit number is to $(state.parseinfo.nbit)"
end

function help()
"""Guide:
=== Basic ===
q: quit
help() | h: print this manual
c cmd: show the julia code of an expression
listvars() | l: list defined register/block table
nbits(n): set the number of qubits to `n` (used in defining a block)
nbits(): show the number of qubits

=== Define a Register ===
reg = rand_state(n): random `n`-qubit state
reg = zero_state(n): zero state
reg = bit"01011": product state

=== Operations ===
expect(op, reg): compute <reg|op|reg>
expect'(op, reg[=>c]): compute ∂<reg|c'*op*c|reg>/∂reg and ∂<reg|c'*op*c|reg>/∂c
fidelity(reg1, reg2): compute <reg1|reg2>
fidelity'(reg1[=>c1], reg2[=>c2]): compute ∂<reg1|c1'*c2|reg2>/∂reg1, ∂<reg1|c1*c2|reg2>/∂c1 ...
reg |> op: apply `op` on `reg`
measure!([op, ]reg) | m! [op] reg: measure `op` inplace.
measure([op, ]reg, [nshots=n]) | m! [op] reg [nshots=n]: measure `op` without collapsing `reg`.

* Note: `n` is integer, `cmd` is command, `reg` is register, `op` is operator or gate (block)."""
end

function inspect(io::IO, b::AbstractBlock)
    Base.show(io, "text/plain", mat(b))
end

function inspect(io::IO, reg::AbstractRegister)
    Base.show(io, "text/plain", statevec(reg))
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

function yaorepl_handler(str::AbstractString, state)
    if length(strip(str)) >=2 && strip(str)[1:2] == "c "
        string(yaorepl_trans(yaorepl_parse(str[3:end]), state))
    else
        yaorepl_execute(yaorepl_trans(yaorepl_parse(str), state), state)
    end
end
