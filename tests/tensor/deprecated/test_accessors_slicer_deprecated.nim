# Copyright 2017 Mamy André-Ratsimbazafy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ../../../src/arraymancer
import unittest, math


suite "Testing indexing and slice syntax":
  const
    a = @[1, 2, 3, 4, 5]
    b = @[1, 2, 3, 4, 5]

  var
    vandermonde: seq[seq[int]]
    row: seq[int]

  vandermonde = newSeq[seq[int]]()

  for i, aa in a:
    row = newSeq[int]()
    vandermonde.add(row)
    for j, bb in b:
      vandermonde[i].add(aa^bb)

  let t_van = vandermonde.toTensor(Cpu)

  # Tensor of shape 5x5 of type "int" on backend "Cpu"
  # |1      1       1       1       1|
  # |2      4       8       16      32|
  # |3      9       27      81      243|
  # |4      16      64      256     1024|
  # |5      25      125     625     3125|
  test "Basic indexing - foo[2, 3]":
    check: t_van[2, 3] == 81

  test "Basic indexing - foo[1+1, 2*2*1]":
    check: t_van[1+1, 2*2*1] == 243

  ## TODO: The following checks fails because return value
  ## is a Tensor not a scalar
  # test "Indexing from end - foo[^1, 3]":
  #     check: t_van[^1, 3] == 625
  # test "Indexing from end - foo[^(1*2), 3]":
  #     check: t_van[^1, 3] == 256
  test "Basic slicing - foo[1..2, 3]":
    let test = @[@[16],@[81]]
    check: t_van[1..2, 3] == test.toTensor(Cpu)

  test "Basic slicing - foo[1+1..4, 3-2..2]":
    let test = @[@[9,27],@[16, 64],@[25, 125]]
    check: t_van[1+1..4, 3-2..2] == test.toTensor(Cpu)

  test "Span slices - foo[_, 3]":
    let test = @[@[1],@[16],@[81],@[256],@[625]]
    check: t_van[_, 3] == test.toTensor(Cpu)

  test "Span slices - foo[1.._, 3]":
    let test = @[@[16],@[81],@[256],@[625]]
    check: t_van[1.._, 3] == test.toTensor(Cpu)

    ## Check with extra operators
    check: t_van[0+1.._, 3] == test.toTensor(Cpu)

  test "Span slices - foo[_..3, 3]":
    let test = @[@[1],@[16],@[81],@[256]]
    check: t_van[_..3, 3] == test.toTensor(Cpu)

    ## Check with extra operators
    check: t_van[_..5-2, 3] == test.toTensor(Cpu)

  test "Span slices - foo[_.._, 3]":
    let test = @[@[1],@[16],@[81],@[256],@[625]]
    check: t_van[_.._, 3] == test.toTensor(Cpu)

  test "Stepping - foo[1..3|2, 3]":
    let test = @[@[16],@[256]]
    check: t_van[1..3|2, 3] == test.toTensor(Cpu)
    check: t_van[1..3|+2, 3] == test.toTensor(Cpu)
    check: t_van[1*(0+1)..2+1|(5-3), 3] == test.toTensor(Cpu)

  test "Span stepping - foo[_.._|2, 3]":
    let test = @[@[1],@[81],@[625]]
    check: t_van[_.._|2, 3] == test.toTensor(Cpu)

  test "Span stepping - foo[_.._|+2, 3]":
    let test = @[@[1],@[81],@[625]]
    check: t_van[_.._|+2, 3] == test.toTensor(Cpu)

  test "Span stepping - foo[1.._|1, 2..3]":
    let test = @[@[8, 16],@[27, 81],@[64, 256], @[125, 625]]
    check: t_van[1.._|1, 2..3] == test.toTensor(Cpu)

  test "Span stepping - foo[_..<4|2, 3]":
    let test = @[@[1],@[81]]
    check: t_van[_..<4|2, 3] == test.toTensor(Cpu)

  test "Slicing until at n from the end - foo[0..^4, 3]":
    let test = @[@[1],@[16]]
    check: t_van[0..^4, 3] == test.toTensor(Cpu)
    ## Check with extra operators
    check: t_van[0..^2+2, 3] == test.toTensor(Cpu)

  test "Span Slicing until at n from the end - foo[_..^2, 3]":
    let test = @[@[1],@[16],@[81],@[256]]
    check: t_van[_..^2, 3] == test.toTensor(Cpu)
    ## Check with extra operators
    check: t_van[_..^1+1, 3] == test.toTensor(Cpu)

  test "Stepped Slicing until at n from the end - foo[1..^1|2, 3]":
    let test = @[@[16],@[256]]
    check: t_van[1..^1|2, 3] == test.toTensor(Cpu)
    ## Check with extra operators
    check: t_van[1..^1|(1+1), 3] == test.toTensor(Cpu)

  test "Slice from the end - foo[^1..0|-1, 3]":
    let test = @[@[625],@[256],@[81],@[16],@[1]]
    check: t_van[^1..0|-1, 3] == test.toTensor(Cpu)
    ## Check with extra operators
    let test2 = @[@[256],@[81],@[16],@[1]]
    check: t_van[^(4-2)..0|-1, 3] == test2.toTensor(Cpu)

  test "Slice from the end - expect non-negative step error - foo[^1..0, 3]":
    expect(IndexError):
      discard t_van[^1..0, 3]

  test "Slice from the end - foo[^(2*2)..2*2, 3]":
    let test = @[@[16],@[81],@[256],@[625]]
    check: t_van[^(2*2)..2*2, 3] == test.toTensor(Cpu)

  test "Slice from the end - foo[^3..^2, 3]":
    let test = @[@[81],@[256]]
    check: t_van[^3..^2, 3] == test.toTensor(Cpu)

suite "Slice mutations":
  const
    a = @[1, 2, 3, 4, 5]
    b = @[1, 2, 3, 4, 5]

  var
    vandermonde: seq[seq[int]]
    row: seq[int]

  vandermonde = newSeq[seq[int]]()

  for i, aa in a:
    row = newSeq[int]()
    vandermonde.add(row)
    for j, bb in b:
      vandermonde[i].add(aa^bb)

  let t_van_immut = vandermonde.toTensor(Cpu)

  # Tensor of shape 5x5 of type "int" on backend "Cpu"
  # |1      1       1       1       1|
  # |2      4       8       16      32|
  # |3      9       27      81      243|
  # |4      16      64      256     1024|
  # |5      25      125     625     3125|

  test "Immutability - let variables cannot be changed":
    when compiles(t_van_immut[1..2,3..4] = 999):
      check false
    when compiles(t_van_immut[0..1,0..1] = [111, 222, 333, 444]):
      check false
    when compiles(t_van_immut[0..1,0..1] = t_van_immut[111, 222, 333, 444]):
      check false

  test "Setting a slice to a single value":
    var t_van = t_van_immut.clone
    let test =  @[@[1,  1,   1,   1,    1],
            @[2,  4,   8, 999,  999],
            @[3,  9,  27, 999,  999],
            @[4, 16,  64, 256, 1024],
            @[5, 25, 125, 625, 3125]]

    let t_test = test.toTensor(Cpu)
    t_van[1..2, 3..4] = 999
    check: t_van == t_test

  test "Setting a slice to an array/seq of values":
    var t_van = t_van_immut.clone
    let test =  @[@[111,  222,   1,   1,    1],
            @[333,  444,   8,  16,   32],
            @[  3,    9,  27,  81,  243],
            @[  4,   16,  64, 256, 1024],
            @[  5,   25, 125, 625, 3125]]

    let t_test = test.toTensor(Cpu)
    t_van[0..1,0..1] = [[111, 222], [333, 444]]
    check: t_van == t_test

  test "Setting a slice from a different Tensor":
    var t_van = t_van_immut.clone
    let test =  @[@[1,  1,     1,   1,   1],
            @[2,  4,     8,  16,  32],
            @[3,  9,    27,  81, 243],
            @[4, 16,  3125, 625, 125],
            @[5, 25,  1024, 256,  64]]

    let t_test = test.toTensor(Cpu)
    t_van[^2..^1,2..4] = t_van_immut[^1..^2|-1, 4..2|-1]
    check: t_van == t_test

  # Deprecated with reference semantics
  #
  # test "Setting a slice from a view of the same Tensor":
  #   var t_van = t_van_immut.clone
  #   let test =  @[@[1,  1,     1,   1,   1],
  #           @[2,  4,     8,  16,  32],
  #           @[3,  9,    27,  81, 243],
  #           @[4, 16,  3125, 625, 125],
  #           @[5, 25,  1024, 256, 64]]

  #   let t_test = test.toTensor(Cpu)
  #   t_van[^2..^1,2..4] = t_van[^1..^2|-1, 4..2|-1]
  #   check: t_van == t_test
  
  test "Bounds checking":
    var t_van = t_van_immut
    expect(IndexError):
      t_van[0..1,0..1] = [111, 222, 333, 444, 555]
    expect(IndexError):
      t_van[0..1,0..1] = [111, 222, 333]
    expect(IndexError):
      t_van[^2..^1,2..4] = t_van[1, 4..2|-1]
    expect(IndexError):
      t_van[^2..^1,2..4] = t_van[^1..^3|-1, 4..2|-1]
  
  test "Chained slicing - foo[1..^2,1..2][1..^1, 0]":
    let t_van = t_van_immut
    check: t_van[1..^2,1..2][1..^1, 0] == [[9],[16]].toTensor(Cpu)