using PyCall

export quil_run

pushfirst!(PyVector(pyimport("sys")["path"]), ".")
qr = pyimport("quil_run")
const quil_run = qr.quil_run
