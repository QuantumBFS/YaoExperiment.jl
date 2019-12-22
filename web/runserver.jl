using YaoExperiment
using YaoExperiment: WEBCONFIG

WEBCONFIG[:maxn_dense] = 10
WEBCONFIG[:maxn_sparse] = 15
WEBCONFIG[:PORT] = 8080
SERVER = run_server(YaoExperiment.naive_handler)
