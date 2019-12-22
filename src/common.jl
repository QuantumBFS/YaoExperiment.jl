const max_nbit = Ref(20)
const max_nbatch = Ref(128)
const max_nshots = Ref(128)

_checkbit(x::Int) = x <= max_nbit[] ? x : error("maximum number of qubits is $(max_nbit[]), got $x.")
_checkbit(x::String) = (_checkbit(length(x)); x)
_checkbatch(x::Int) = x <= max_nbatch[] ? x : error("maximum number of nbatch is $(max_nbatch[]), got $x.")
_checkshots(x::Int) = x <= max_nshots[] ? x : error("maximum number of nshots is $(max_nshots[]), got $x.")

_checkreg(a::Symbol) = a
_checkop(a::Symbol) = a

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

function setnbits!(n::Int, state)
    state.parseinfo.nbit = Int(n)
    "qubit number is set to $n"
end

function getnbits(state)
    "qubit number is to $(state.parseinfo.nbit)"
end
