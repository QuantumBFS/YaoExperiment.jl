# patch identity bits
usedbits(::I2Gate) = []
usedbits(p::PutBlock) = [p.addrs[usedbits(p.block)]...]
