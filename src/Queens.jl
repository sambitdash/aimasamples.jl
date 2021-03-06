module Queens

export  solveNQueensProblemRBFS,
        solveNQueensProblemGSU,
        solveNQueensProblemGSBF,
        solveNQueensProblemGSAS,
        solveNQueensProblemHCS,
        solveNQueensProblemSAS,
        solveNQueensProblemGAS,
        solveNQueensProblemGAS9

using AIMACore

import AIMACore: search, goal_test, step_cost, actions,
                 result, heuristic, state_value, successor_states,
                 mutate, reproduce, random_state
import Base: ==, show, convert, hash

const E_INVALID_INPUT_LENGTH = "The input parameter is of a wrong length"
const E_INVALID_INPUT = "The input parameter is invalid"
const E_INVALID_STATE = "The state is invalid"
const E_INVALID_ACTION = "The action is invalid"

const SIZE = 8

mutable struct Grid{T} <: State
    qloc::Vector{Int}
    function Grid{T}(loc::Vector{Int}) where T
        @assert length(loc) == T E_INVALID_INPUT_LENGTH
        new(loc)
    end
end

# This heuristic is not relevant as this is the same for every step
h(g::Grid{T}) where T = T - count(x->x > 0, g.qloc)

Grid(T::Int) = Grid{T}(zeros(Int, T))

function convert(::Type{BitArray{2}}, g::Grid{T}) where T
    m = BitArray{2}(undef, T, T)
    l = g.qloc
    for i = 1:T
        l[i] == 0 && continue
        m[l[i],i] = true
    end
    return m
end

BitArray{2}(g::Grid{T}) where T = convert(BitArray{2}, g)

==(g1::Grid, g2::Grid) = hash(g1) == hash(g2)

hash(g::Grid{T}, h::UInt) where T =
    xor(sum([UInt(g.qloc[i])*UInt(T+1)^UInt(i) for i=1:T]), h)

function show(io::IO, g::Grid{T}) where T
    m = BitArray{2}(g)
    a = [ m[i,j] ? 'Q' : 'x' for i=1:T,j=1:T]
    for j = 1:T-1
        show(io, a[j,:])
        println(io, "")
    end
    show(io, a[T,:])
end

struct Place <: Action
    location::Tuple{Int,Int}
end

mutable struct NQueensProblem{SA <: SearchAlgorithm, T} <: Problem
    initial_state::Grid{T}
    search_algorithm::SA
    h::Function
end

function result(problem::NQueensProblem,
                state::Grid{T}, action::Place) where T
    qloc = copy(state.qloc)
    x, y = action.location
    qloc[x] = y
    return Grid{T}(qloc)
end

step_cost(problem::NQueensProblem, state::Grid, action::Place) = 1

heuristic(problem::NQueensProblem, state::Grid) = problem.h(state)

goal_test(problem::NQueensProblem, state::Grid{T}) where T =
    count(x->x > 0, state.qloc) == T && state_value(problem, state) == div(T*(T-1), 2)

cannot_place(x, y, i, j) = x == i || y == j || x + j == y + i || x + y == i + j

function cannot_place(state::Grid{T}, i, j) where T
    for k = 1:T
        state.qloc[k] == 0 && continue
        cannot_place(k, state.qloc[k], i, j) && return true
    end
    return false
end

actions(problem::NQueensProblem, state::Grid{T}) where T =
    Place.([(i, j) for i=1:T for j=1:T if !cannot_place(state, i, j)])

function solveNQueensProblem(obj::SA,
    h::Function, init_state::Grid=Grid(SIZE)) where {SA <: SearchAlgorithm}
    problem = NQueensProblem(init_state, obj, h)
    path = search(problem)
    path isa Symbol && return path
    path isa State && return path
    ret=[]
    count = 0
    for iter in path
        push!(ret, iter.state)
    end
    return ret
end

const GSD = GraphSearchDepth(Grid(SIZE))
const GSU = GraphSearchUniformCost(Grid(SIZE))
const GSBF = GraphSearchBestFirst(Grid(SIZE))
const GSAS = GraphSearchAStar(Grid(SIZE))
const RBFS = RecursiveBestFirstSearch(Grid(SIZE))

solveNQueensProblemGSU() = solveNQueensProblem(GSU, h)
solveNQueensProblemGSBF() = solveNQueensProblem(GSBF, h)
solveNQueensProblemGSAS() = solveNQueensProblem(GSAS, h)
solveNQueensProblemRBFS() = solveNQueensProblem(RBFS, h)

function queen_pair_score(g::Grid{T}) where T
    l = g.qloc
    return div(T*(T-1),2) -
        sum([l[j] > 0 && l[i] > 0 && cannot_place(j, l[j], i, l[i]) for i=1:T for j=i+1:T])
end

random_state(T::Int) = Grid{T}([rand(1:T) for i = 1:T])

state_value(problem::NQueensProblem, state::Grid) = queen_pair_score(state)

function successor_states(problem::NQueensProblem, state::Grid{T}) where T
    v = Vector{Grid{T}}()
    for i = 1:T
        s = [j for j = 1:T if j != state.qloc[i]]
        for n in s
            l = copy(state.qloc)
            l[i] = n
            push!(v, Grid{T}(l))
        end
    end
    return v
end

HCS = HillClimbingSearch(Grid(SIZE), 100)
SAS = SimulatedAnnealingSearch(Grid(SIZE))

solveNQueensProblemHCS() = solveNQueensProblem(HCS, h, random_state(SIZE))
solveNQueensProblemSAS() = solveNQueensProblem(SAS, h, random_state(SIZE))

random_state(s::Grid{T}) where T = random_state(T)

const BIT_OPERATION = true

function to_bits(s1::Grid{8}; mutate=false)
    b1 = BitArray(undef, 24)
    l = s1.qloc
    it = 0
    for i = 1:8
        n = l[i] - 1
        b1[it+=1] = (n & 1 != 0)
        b1[it+=1] = (n & 2 != 0)
        b1[it+=1] = (n & 4 != 0)
    end
    if (mutate)
        c = rand(1:24)
        b1[c] = !b1[c]
    end
    return b1
end

function from_bits(b::BitArray)
    l = zeros(Int, 8)
    it = 0
    for i = 1:8
        n = 1
        n += b[it+=1] ? 1 : 0
        n += b[it+=1] ? 2 : 0
        n += b[it+=1] ? 4 : 0
        l[i] = n
    end
    return Grid{8}(l)
end

bit_mutate(s::Grid{8}) = to_bits(s, mutate=true) |> from_bits

function bit_reproduce(s1::Grid{8}, s2::Grid{8})
    b1 = to_bits(s1)
    b2 = to_bits(s2)
    c = rand(1:24)
    copyto!(b1[c+1:24], b2[c+1:24])
    return from_bits(b1)
end

function mutate(s::Grid{T}) where T
    BIT_OPERATION && T == 8 && return bit_mutate(s)
    l = copy(s.qloc)
    l[rand(1:T)] = rand(1:T)
    return Grid{T}(l)
end

function reproduce(s1::Grid{T}, s2::Grid{T}) where T
    BIT_OPERATION && T == 8 && return bit_reproduce(s1, s2)
    c = rand(1:T)
    l = copy(s1.qloc)
    copyto!(l[c+1:T], s2.qloc[c+1:T])
    return Grid{T}(l)
end

GAS = GeneticAlgorithmSearch(Grid(SIZE), queen_pair_score)
solveNQueensProblemGAS() = solveNQueensProblem(GAS, h, random_state(SIZE))

GAS9 = GeneticAlgorithmSearch(Grid(9), queen_pair_score)
solveNQueensProblemGAS9() = solveNQueensProblem(GAS9, h, random_state(9))

end
