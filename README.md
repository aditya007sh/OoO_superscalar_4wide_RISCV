# 4-Wide Out-of-Order Superscalar RISC-V Processor

A 4-wide Out-of-Order (OoO) Superscalar RISC-V processor implemented in Verilog.

The processor is designed to exploit instruction-level parallelism by allowing multiple instructions to be fetched, decoded, renamed, dispatched, issued, executed, and committed in parallel while maintaining correct architectural state through register renaming, dynamic scheduling, and in-order retirement.

## Architecture

The processor follows an out-of-order execution architecture with the following major stages:

    Fetch
      ↓
    Predecode & Branch Prediction
      ↓
    Instruction Queue
      ↓
    Decode
      ↓
    Register Renaming
      ↓
    Rename & Dispatch
      ↓
    Issue Queue
      ↓
    Execution Units
      ├── ALU
      ├── BPU
      ├── AGU
      └── Pipelined Multiplier
      ↓
    CDB / Writeback
      ↓
    ROB
      ↓
    ARF / Commit

Memory instructions are handled through a dedicated Load Store Queue:

    Issue Queue
         ↓
        AGU
         ↓
        LSQ
         ↓
      Main Memory

## Key Features

- 4-wide instruction fetch and dispatch
- Out-of-order instruction execution
- In-order instruction commit
- RV32I integer instruction support
- RV32M multiplication support
- Register renaming using a RAT
- Retirement RAT (RRAT) for committed register mappings
- 64-entry Physical Register File
- Free List for physical register allocation
- 64-entry Issue Queue for dynamic instruction scheduling
- 64-entry Reorder Buffer
- 32-entry Load Store Queue
- Store-to-load forwarding
- Load/store dependency checking
- Dedicated Address Generation Unit
- Branch Processing Unit
- Branch misprediction detection and recovery
- Pipelined multiplier supporting MUL, MULH, MULHSU and MULHU
- Multiple execution/writeback channels
- In-order retirement for maintaining precise architectural state

## Register Renaming

Register renaming allows multiple in-flight versions of an architectural register to coexist in the Physical Register File.

The RAT maintains the current speculative architectural-to-physical register mapping, while the RRAT maintains the committed mapping used during recovery from branch mispredictions.

The Free List manages allocation of available physical registers during instruction renaming.

Register renaming removes false WAR and WAW dependencies and allows independent instructions to execute concurrently.

## Issue Queue

The Issue Queue dynamically schedules instructions based on operand readiness.

Instructions wait until their source operands are available and then issue to the appropriate execution unit.

The execution units include:

- ALUs for integer arithmetic and logical operations
- BPU for branches and jumps
- AGU for effective address calculation
- Pipelined multiplier for RV32M operations

Execution results are broadcast through the CDB/writeback network and used to wake up dependent instructions.

## Load Store Queue

The Load Store Queue (LSQ) manages in-flight load and store instructions and maintains correct memory ordering during out-of-order execution.

The LSQ handles:

- Load and store tracking
- Effective address tracking
- Store data tracking
- Memory dependency checking
- Store-to-load forwarding
- Store commit handling
- Interaction with the memory subsystem

### Store-to-Load Forwarding

When an older store has a known address and its data is available, a younger load accessing the same address can receive the value directly from the store instead of waiting for the value to be written to memory.

This allows loads to execute earlier while maintaining correct memory behavior.

## Reorder Buffer

The Reorder Buffer (ROB) maintains instructions in program order and enables in-order retirement despite out-of-order execution.

ROB entries track information such as:

- Architectural destination register
- Physical destination register
- Old physical register
- Instruction state
- Execution result
- Store information

The processor supports up to 4-wide commit.

At commit, completed instructions update the architectural state and old physical registers can be returned to the Free List.

The ROB also participates in branch misprediction recovery by removing younger speculative instructions.

## Execution Units

### ALU

The ALU is a combinational integer execution unit supporting operations such as:

- ADD
- SUB
- AND
- OR
- XOR
- SLL
- SRL
- SRA
- SLT
- SLTU
- LUI
- AUIPC

### BPU

The Branch Processing Unit evaluates conditional branches and handles jump instructions such as JAL and JALR.

The current implementation uses a simple predict-taken branch prediction strategy and detects mispredictions during branch execution.

### AGU

The Address Generation Unit calculates effective memory addresses:

    Effective Address = Base Register + Immediate

The AGU also forwards store data to the LSQ when the store data is available.

### Pipelined Multiplier

The multiplier implements the RV32M multiplication instructions:

- MUL
- MULH
- MULHSU
- MULHU

The multiplier is pipelined to improve throughput and allow new multiplication operations to enter the pipeline while previous operations are still being processed.

## Writeback / CDB

The writeback network collects results from the execution units and provides them to the appropriate processor structures.

Results include:

- Physical register destination
- ROB index
- Execution result
- Valid information

Multiple execution units can provide results simultaneously through separate writeback channels.

## Verification

The processor was verified using multiple Verilog testbenches, including a comprehensive stress test.

The verification covers:

- x0 behavior
- ADDI instructions
- R-type arithmetic and logical operations
- I-type logical operations
- Shift operations
- Signed and unsigned comparisons
- LUI
- Load/store operations
- Branch execution
- JAL
- Register state verification
- Memory state verification

The stress test checks the final architectural register state and memory contents against expected values and reports PASS/FAIL results.


## Repository Contents

The repository contains:

- Verilog RTL source files
- Verilog testbenches
- Processor datapath diagram
- Project documentation

## Tools Used

- Verilog HDL
- Xilinx Vivado
- Vivado XSim

## Possible Future Improvements

Possible extensions to the current design include:

- Dynamic branch prediction using 2-bit saturating counters
- Branch Target Buffer (BTB)
- Cache hierarchy
- More advanced memory subsystem
- Additional execution units
- Improved exception and interrupt handling
- More extensive automated verification

## Author

Developed as an RTL and processor architecture project to explore out-of-order execution, register renaming, dynamic scheduling, speculative execution, memory dependency handling, and precise instruction retirement.
