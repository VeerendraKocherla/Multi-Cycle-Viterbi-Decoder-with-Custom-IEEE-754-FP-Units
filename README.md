# Multi-Cycle Viterbi Decoder with Custom IEEE-754 FP-Units
### Introduction
This project was developed as part of the course CS6230: CAD for VLSI Systems at the Indian Institute of Technology (IIT) Madras.

The Viterbi algorithm is a dynamic programming technique commonly used with Hidden
Markov Models(HMM). Given a sequence of observations, it computes the most likely
sequence of hidden states that could have generated these observations.
The objective is to design a Viterbi Decoder that implements the Viterbi algorithm to
solve a generic Hidden Mark Model (HMM) problem. The decoder takes in the sequences
of observations and uses predefined transmission and emission probabilities to output the
most probable sequence of hidden states, along with its probability score (in natural logarithmic form).

This project contains 4 parts:
1. RTL Design using Bluespec SystemVerilog
2. Optimization
3. Synthesis using SAED32nm EDK (ss corner)
4. Verification based on any programming language (I chose python)

**I/0 files:**
1. N.dat: This file contains two values: N and M.
  • N is the number of states, stored as a 32-bit integer. The state set is defined as
  Q = q1, q2, . . . , qN, with two additional special states: the start state q0 and the end
  state qend. Each state is represented by a 32-bit integer.
  • M is the number of possible observations. The observation set is given by O =
  o1, o2, . . . , oM, with each observation represented as a 32-bit integer.
2. A.dat: This file contains the transition probability matrix
A = {a_01, a_02, . . . , aN1, . . . , aNN}.
It consists of (N + 1) × N entries, capturing state transitions both from the start state
q0 and between states. All entries are stored as natural logarithms of the probabilities,
using IEEE single-precision floating-point format.
3. B.dat
This file stores the emission probabilities
B = bi(ot),
arranged in the order b1(o1), b1(o2), . . . , b1(oM), b2(o1), . . . , bN(oM).
Each probability value is stored in natural logarithmic form, using IEEE single-precision
floating-point format.
4. Input.dat
This file contains multiple sequences of input observations. Each observation is a 32-bit
integer. The marker FFFFFFFF indicates the end of one sequence. The final sequence is
terminated with 32’hFFFFFFFF followed by 32’h0.
5. Output.dat
This file stores the results produced by the hardware simulation. For each input sequence,
the following are written: The most probable sequence of states. The probability of this sequence, given in natural logarithmic form. The marker 32’hFFFFFFFF. The very last result must end with 32’h0.

The project directory contains two sample test cases in the test-cases subdirectory:
’small’ and ’huge’.

Note: The maximum number of entries in any probability matrix (transitions or emissions) is limited to 1024.
All states and observations are considered 1-indexed for the input and output sequences.

### RTL design using Bluespec SystemVerilog
Entire design process is explained clearly in [the Report](Report.pdf). RTL design includes:

1. Design of IEEE-754 single precision floating point adder module.
2. Design of IEEE-754 single precision floating point comparator module.
3. Design of Viterbi Decoder module.
4. Write testbenches for all the above three modules.
   
To run the the bluespec file, change TOPFILE and TOPMODULE instances in ```Makefile``` appropriately. 

**Makefile description:**

```make b_sim``` runs the simlation.

```make generate_verilog``` outputs synthesizable verilog files

```make clean ``` clears all files that above make statements created

### Optimization
Optimization process is also discussed in [the Report](Report.pdf). Acheived a PPA metric of (3.7ns, 11654 um<sup>2,</sup> , 579.686 uW) on a multi-cycled implementation of Viterbi decoder using FIFOs (i.e, on [Version-3](BSV_RTL_design/version3)).

### Synthesis
The design was synthesized using **Synopsys Design Compiler** targeting the **SAED 32nm EDK** (Educational Design Kit). Logic mapping was performed using the Low-Threshold Voltage (LVT) standard cell library. To ensure timing closure under worst-case scenarios, the synthesis targeted the Slow-Slow (SS) process corner at a supply voltage of 0.75V and an operating temperature of 25°C.

### Python Verification
A golden reference model is designed in python to validate the hardware implementation. [Detailed description](Report.pdf). 

