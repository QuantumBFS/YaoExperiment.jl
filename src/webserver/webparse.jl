# A Using Case:
# TODO: multiple circuit mode
"""
yao> nbits(4)

yao> begin
    2 => X
    3 => C, 1=>C, 4=>X
end

yao> 2 => C, 5=>X

yao> download_dense()

yao> download_coo()

yao> download_tensornetwork()

yao> download_tensornetwork()

yao> reset()
"""

const WEBCONFIG = Dict{Symbol, Any}(
    :maxn_dense => 10,
    :maxn_sparse => 15,
    :PORT => 8080,
    :LOCALIP => string(Sockets.getipaddr()),
)

mutable struct YaoWSState
    block::ChainBlock
    parseinfo::YaoBlocks.ParseInfo
end
YaoWSState() = YaoWSState(chain(-1), YaoBlocks.ParseInfo(-1, ""))

function yaoweb_parse(str)
      Meta.parse(str)
end

yaoweb_trans(ex, state) = @match ex begin
    :(nbits($n)) => :(setnbits!($n, $state))

    :(download_tensornetwork()) => :(download(Val(:tensornetwork), $(state.block)))
    :(download_dense()) => :(download(Val(:dense), $(state.block)))
    :(download_coo()) => :(download(Val(:coo), $(state.block)))
    :(download_script()) => :(download(Val(:yaoscript), $(state.block)))
    _ => begin
        blk = YaoBlocks.parse_ex(ex, state.parseinfo)
        :(push!($(state.block), $blk))
    end
end

function setnbits!(n::Int, state::YaoWSState)
    state.block = chain(n)
    state.parseinfo.nbit = Int(n)
    "circuit reseted, qubit number is set to $n"
end

function download(::Val{:dense}, b::AbstractBlock{N}) where N
    nmax = WEBCONFIG[:maxn_dense]
    N > nmax && return "Error: circuit size too large to get dense matrix, should be <= $nmax"
    io = IOBuffer()
    writedlm(io, Matrix(b))
    data = String(take!(io))
    return "download::yao-dense.dat::$data"
end

function download(::Val{:coo}, b::AbstractBlock{N}) where N
    nmax = WEBCONFIG[:maxn_sparse]
    N > nmax && return "Error: circuit size too large to get sparse matrix, should be <= $nmax"
    data = join([join((i,j,v), "  ") for (i,j,v) in zip(LuxurySparse.findnz(mat(b))...)], "\n")
    return "download::yao-sparse-coo.dat::$data"
end

function download(::Val{:yaoscript}, b::AbstractBlock)
    data = YaoBlocks.dump_gate(b)
    return "download::yao-script.yao::$data"
end

function download(::Val{:tensornetwork}, b::AbstractBlock)
    data = graph2strings(opennetwork(simplify_blocktypes(b)))
    data = join(data, "::")
    return "download::yao-tensornetwork::$data"
end

function yaoweb_handler(str::AbstractString, state)
    eval(yaoweb_trans(yaoweb_parse(str), state))
end
