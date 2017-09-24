Data Read/Write
---------------

Data read or write occurs between the arithmetic registers A,B,C,D and memory. These
transfers have a size and an alignment defined by the current field:

- DATn=A f      Write A to memory at address Dn with field f
- C=DATn f      Read from meory at address Dn and deposit the result with field f in C

Let's say a M field operand has to be read from memory:

15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
- | M11 | M10 | M9 | M8 | M7 | M6 | M5 | M4 | M3 | M2 | M1 | M0| - | - | - 


The port is 16 bits wide, 4 nibbles. Depending on which address the read takes place, 
say at address 0x0000, a shift can occur.

Data in memory
3 | 2 | 1 | 0
--- | --- | --- | ---
M3 | M2 | M1 | M0
M7 | M6 | M5 | M4
M11 | M10 | M9 | M8

The data is in memory aligned so only 3 accesses are needed, it has to be shifted
into position before it can be used.

