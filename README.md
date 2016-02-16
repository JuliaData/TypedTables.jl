# Tables

A generic yet type-safe system for implementing data tables (sometimes called data frames, from R) in Julia.

[![Build Status](https://travis-ci.org/andyferris/Tables.jl.svg?branch=master)](https://travis-ci.org/andyferris/Tables.jl)

## Overview

Julia's dynamic-yet-statically-compilable type system is extremely powerful, but
presents some challenges to creating generic storage containers, like tables of
data where each column of the table might have different types. This package
attempts to present a fully-typed `Table` container, where elements (rows,
columns, cells, etc) can be extracted with their correct type annotation at zero
additional run-time overhead. The resulting data can then be manipulated without
any unboxing penalty, or the need to introduce unseemly function barriers,
unlike existing approaches like the popular DataFrames.jl package. Conformance
to the interface presented by DataFrames.jl as well as existing Julia standards,
like indexing and iteration has been maintained.

The main caveat of this approach is that it involves an extra layer of
complication for the programmer and compiler. While convenience of the end-user
has been taken into consideration, there is no getting around that the approach
relies heavily on generated functions and does involve additional compile-time
overhead. 
