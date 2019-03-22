struct WaveReg <: AbstractRegister{1, ComplexF64}
    nbits::Int
    nt::Int
    wave::Matrix{Float64}
end

function WaveReg(nbits::Int, nt::Int)
    WaveReg(nbits, zeros(Float64, nt, nbits))
end

function instruct!(wr::WaveReg, loc::Int)
    t = t0(wr, loc)
    wavelet!(view(wr, t+1:t+wavelet_length(wr), loc))
end

wavelet_length(::Val{:X}) = 100
function wavelet!(v::AbstractVector, ::Val{:X})
end
