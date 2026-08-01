default:
	@just --list

build:
	julia --project=docs docs/make.jl

instantiate:
	julia --project=docs -e 'using Pkg; Pkg.instantiate()'
