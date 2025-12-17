# ziffe
Experimental Zig library for the SPIFFE Workload API 

# Goals
Rough parity with the [go-spiffe](https://github.com/spiffe/go-spiffe) library, in Zig. 

Because Zig's standard library and memory model are so different from Go, full public package interface
parity would be neither practical nor possible. We aim to provide parity in three areas:

1. Types - we aim to expose the same public struct types
2. Methods - we aim to implement the same struct member functions where helpful
3. SDK features - we aim to provide the same SDK methods for initiating a mTLS connection etc.