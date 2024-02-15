# Copyright (c) 2018 the Arraymancer contributors
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).
# This file may not be copied, modified, or distributed except according to those terms.

import ../tensor
import ./helpers/triangular
import std/sequtils

proc hilbert*(n: int, T: typedesc[SomeFloat]): Tensor[T] =
  ## Generates an Hilbert matrix of shape [N, N]
  result = newTensorUninit[T]([n, n])
  let R = result.unsafe_raw_buf()

  # Reminder: The canonical Hilbert matrix
  #           assumes that i, j starts at 1 instead of 0

  # Base algorithm that exploits symmetry and avoid division half the time
  # for i in 0 ..< n:
  #   for j in i ..< n:
  #     R[i*n+j] = 1 / (i.T + j.T + 1)
  #     R[j*n+i] = R[i*n+j]

  const Tile = 32
  for i in countup(0, n-1, Tile):
    for j in countup(0, n-1, Tile):
      for ii in i ..< min(i+Tile, n):
        for jj in j ..< min(j+Tile, n):
          # Result is triangular and we go through rows first
          if jj >= ii:
            R[ii*n+jj] = 1 / (ii.T + jj.T + 1)
          else:
            R[ii*n+jj] = R[jj*n+ii]

  # TODO: scipy has a very fast hilbert matrix generation
  #       via Hankel Matrix and fancy 2D indexing

proc vandermonde*[T](x: Tensor[T], order: int): Tensor[float] =
  ## Returns a Vandermonde matrix of the input `x` up to the given `order`.
  ##
  ## A vandermonde matrix consists of the input `x` split into multiple
  ## rows where each row contains all powers from 0 to `order` of `x_i`.
  ##
  ## `V_ij = x_i ^ order_j`
  ##
  ## where `order_j` runs from 0 to `order`.
  assert x.squeeze.rank == 1
  let x = x.squeeze.asType(float)
  result = newTensorUninit[float]([x.size.int, order.int])
  let orders = arange(order.float)
  for i, ax in enumerateAxis(result, axis = 1):
    result[_, i] = (x ^. orders[i]).unsqueeze(axis = 1)

proc diagonal*[T](a: Tensor[T], k = 0, anti = false): Tensor[T] {.noInit.} =
  ## Gets the k-th diagonal (or anti-diagonal) of a matrix
  ##
  ## Input:
  ##      - A matrix (which can be rectangular)
  ##      - k: The index k of the diagonal that will be extracted. The default is 0 (i.e. the main diagonal).
  ##        Use k>0 for diagonals above the main diagonal, and k<0 for diagonals below the main diagonal.
  ##      - anti: If true, get the k-th "anti-diagonal" instead of the k-th regular diagonal.
  ## Result:
  ##      - A copy of the diagonal elements as a rank-1 tensor
  assert a.rank == 2, "diagonal() only works on matrices"
  assert k < a.shape[0], &"Diagonal index ({k=}) exceeds the output matrix height ({a.shape[0]})"
  assert k < a.shape[1], &"Diagonal index ({k=}) exceeds the output matrix width ({a.shape[1]})"
  let size = min(a.shape[0], a.shape[1]) - abs(k)
  result = newTensor[T](size)

  if anti:
    if k >= 0:
      let size = min(a.shape[0] - abs(k), a.shape[1])
      result = newTensor[T](size)
      for i in 0 ..< size:
        result[i] = a[a.shape[0]-1-(i+k), i]
    else:
      let size = min(a.shape[0], a.shape[1] - abs(k))
      result = newTensor[T](size)
      for i in 0 ..< size:
        result[i] = a[a.shape[0]-1-i, i-k]
  else:
    if k >= 0:
      let size = min(a.shape[0], a.shape[1] - abs(k))
      result = newTensor[T](size)
      for i in 0 ..< size:
        result[i] = a[i, i+k]
    else:
      let size = min(a.shape[0]-abs(k), a.shape[1])
      result = newTensor[T](size)
      for i in 0 ..< size:
        result[i] = a[i-k, i]

proc set_diagonal*[T](a: var Tensor[T], d: Tensor[T], k = 0, anti = false) =
  ## Sets a diagonal of a matrix (in place)
  ##
  ## Input:
  ##      - The matrix that will be changed in place.
  ##      - Rank-1 tensor containg the elements that will be copied into the selected diagonal.
  ##      - k: The index k of the diagonal that will be changed. The default is 0 (i.e. the main diagonal).
  ##        Use k>0 for diagonals above the main diagonal, and k<0 for diagonals below the main diagonal.
  ##      - anti: If true, set the k-th "anti-diagonal" instead of the k-th regular diagonal.
  assert a.rank == 2, "set_diagonal() only works on matrices"
  assert d.rank == 1, "The diagonal passed to set_diagonal() must be a rank-1 tensor"
  assert k < a.shape[0], &"Diagonal index ({k=}) exceeds input matrix height ({a.shape[0]})"
  assert k < a.shape[1], &"Diagonal index ({k=}) exceeds input matrix width ({a.shape[1]})"
  if anti:
    if k >= 0:
      when compileOption("boundChecks"):
        let size = min(a.shape[0] - abs(k), a.shape[1])
        doAssert size == d.size, &"Diagonal input size ({d.size}) does not match the {k}-th upper anti-diagonal size ({size})"
      for i in 0 ..< d.size:
        a[a.shape[0]-1-(i+k), i] = d[i]
    else:
      when compileOption("boundChecks"):
        let size = min(a.shape[0], a.shape[1] - abs(k))
        doAssert size == d.size, &"Diagonal input size ({d.size}) does not match the {-k}-th lower anti-diagonal size ({size})"
      for i in 0 ..< d.size:
        a[a.shape[0]-1-i, i-k] = d[i]
  else:
    if k >= 0:
      when compileOption("boundChecks"):
        let size = min(a.shape[0], a.shape[1] - abs(k))
        doAssert size == d.size, &"Diagonal input size ({d.size}) does not match the {k}-th upper diagonal size ({size})"
      for i in 0 ..< d.size:
        a[i, i+k] = d[i]
    else:
      when compileOption("boundChecks"):
        let size = min(a.shape[0] - abs(k), a.shape[1])
        doAssert size == d.size, &"Diagonal input size ({d.size}) does not match the {-k}-th lower diagonal size ({size})"
      for i in 0 ..< d.size:
        a[i-k, i] = d[i]

proc with_diagonal*[T](a: Tensor[T], d: Tensor[T], k = 0, anti = false): Tensor[T] {.noInit.} =
  ## Copy the input matrix, changing one of its diagonals into the elements of the rank-1 input tensor d
  ##
  ## Input:
  ##      - The matrix that will copied into the output.
  ##      - Rank-1 tensor containg the elements that will be copied into the selected diagonal.
  ##      - k: The index k of the diagonal that will be changed. The default is 0 (i.e. the main diagonal).
  ##        Use k>0 for diagonals above the main diagonal, and k<0 for diagonals below the main diagonal.
  ##      - anti: If true, set the k-th "anti-diagonal" instead of the k-th regular diagonal.
  result = a
  set_diagonal(result, d, k, anti=anti)

proc diag*[T](d: Tensor[T], k = 0, anti = false): Tensor[T] {.noInit.} =
  ## Creates new square diagonal matrix from an rank-1 input tensor
  ##
  ## Input:
  ##      - Rank-1 tensor containg the elements of the diagonal
  ##      - k: The index of the diagonal that will be set. The default is 0.
  ##        Use k>0 for diagonals above the main diagonal, and k<0 for diagonals below the main diagonal.
  ##      - anti: If true, set the k-th "anti-diagonal" instead of the k-th regular diagonal.
  ## Result:
  ##      - The constructed, square diagonal matrix
  doAssert d.rank == 1, "Diagonal must be a rank-1 tensor"
  let size = d.size + abs(k)
  result = zeros[T](size, size)
  result.set_diagonal(d, k=k, anti=anti)

proc identity*[T](n: int): Tensor[T] {.noInit.} =
  ## Return an identity matrix (i.e. 2-D tensor) of size `n`
  ##
  ## The identity matrix is a square 2-D tensor with ones on the main diagonal and zeros elsewhere.
  ## This is basically the same as calling `eye(n, n)`.
  ##
  ## Input:
  ##      - Number of rows / columns in the output.
  ## Result:
  ##      - The constructed indentity 2-D tensor
  result = diag(ones[T](n))

proc eye*[T](shape: varargs[int]): Tensor[T] {.noInit.} =
  ## Return a 2-D tensor with ones on the diagonal and zeros elsewhere
  ##
  ## Input:
  ##      - The shape of the output matrix
  ## Result:
  ##      - The constructed, rank-2 diagonal tensor
  doAssert shape.len == 2, "eye() takes exactly two arguments"
  result = zeros[T](shape)
  result.set_diagonal(ones[T](min(shape)))

proc tri*[T](shape: Metadata, k: static int = 0, upper: static bool = false): Tensor[T] {.noInit.} =
  ## Return a 2-D tensor with ones at and below the given diagonal and zeros elsewhere
  ##
  ## Inputs:
  ##      - The (rank-2) shape of the output matrix.
  ##      - k: The sub-diagonal at and below which the tensor will be filled with ones.
  ##           The default is 0.
  ##      - upper: If true, the tensor will be filled with ones at and above the given
  ##               diagonal. The default is false.
  ## Result:
  ##      - The constructed, rank-2 triangular tensor.
  assert shape.len == 2, &"tri() requires a rank-2 shape as it's input but a shape of rank {shape.len} was passed"
  assert k < shape[0], &"tri() received a diagonal index ({k=}) which exceeds the output matrix height ({shape[0]})"
  assert k < shape[1], &"tri() received a diagonal index ({k=}) which exceeds the output matrix width ({shape[1]})"

  result = ones[T](shape)
  when upper:
    result = triu(result, k = k)
  else:
    result = tril(result, k = k)

proc tri*[T](shape_ax1, shape_ax0: int, k: static int = 0, upper: static bool = false): Tensor[T] {.noInit, inline.} =
  ## Return a 2-D tensor with ones at and below the given diagonal and zeros elsewhere
  ##
  ## Inputs:
  ##      - The shape of the output matrix.
  ##      - k: The sub-diagonal at and below which the tensor will be filled with ones.
  ##           The default is 0.
  ##      - upper: If true, the tensor will be filled with ones at and above the given
  ##               diagonal. The default is false.
  ## Result:
  ##      - The constructed, rank-2 triangular tensor
  tri[T](toMetadata(shape_ax1, shape_ax0), k = k, upper = upper)

# Also export the tril and triu functions which are also part of numpy's API
# and which are implemented in helpers/triangular.nim
export tril, triu

type MeshGridIndexing* = enum xygrid, ijgrid

proc meshgrid*[T](t_list: varargs[Tensor[T]], indexing = MeshGridIndexing.xygrid):
    seq[Tensor[T]] {.noinit.} =
  ## Return a sequence of coordinate matrices from coordinate vectors.
  ##
  ## Make N-D coordinate tensors for vectorized evaluations of N-D scalar/vector
  ## fields over N-D grids, given one-dimensional coordinate tensors x1, x2,..., xn.
  ##
  ## Inputs:
  ## - xi: The coordinate tensors. Each vector must be a rank-1 tensor.
  ## - indexing: Cartesian (`xygrid`, default) or matrix (`ijgrid`) indexing of the output.
  ##             The indexing mode only affects the first 2 output Tensors.
  ##             In the 2-D case with inputs of length M and N, the outputs are of shape
  ##             (N, M) for `xygrid` indexing and (M, N) for `ijgrid` indexing.
  ##             In the 3-D case with inputs of length M, N and P, outputs are of shape
  ##             (N, M, P) for `xygrid` indexing and (M, N, P) for `ijgrid` indexing.
  ## Result:
  ## - List of N meshgrid N-dimensional Tensors
  ##   For tensors x1, x2,..., xn with lengths Ni=len(xi), returns (N1, N2, N3,..., Nn)
  ##   shaped tensors if indexing=`ijgrid` or (N2, N1, N3,..., Nn) shaped tensors if
  ##   indexing=`xygrid` with the elements of xi repeated to fill the matrix along
  ##   the first dimension for x1, the second for x2 and so on.
  ##
  ## Notes:
  ## - This function follows and implements the `numpy.meshgrid` API.

  let t_list = if indexing == MeshGridIndexing.xygrid:
      # In xy mode, the first two dimensions are swapped before broadcasting
      @[t_list[1], t_list[0]] & t_list[2..^1]
    else:
      t_list.toSeq
  result = newSeq[Tensor[T]](t_list.len)
  var out_shape = t_list.mapIt(it.size.int)
  let dims = repeat(1, t_list.len)
  var n = 0
  for t in t_list:
    var item_shape = dims
    item_shape[n] = t.size.int
    result[n] = broadcast(t.reshape(item_shape), out_shape)
    inc n
  if indexing == MeshGridIndexing.xygrid:
    # In xy mode, we must swap back the first two dimensions after broadcast
    result = @[result[1], result[0]] & result[2..^1]
