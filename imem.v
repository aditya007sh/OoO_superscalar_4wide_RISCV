module INSTRUCTION_MEMORY(
input [31:0] address,
output reg [31:0] instruction_out1,
output reg [31:0] instruction_out2,
output reg [31:0] instruction_out3,
output reg [31:0] instruction_out4,
output reg [31:0] address_out
    );
    
    reg [31:0] instructions_list [31:0];
    
    initial begin 
    
                instructions_list[ 0] = 32'h00a00093; // ADDI x1, x0, 10
        instructions_list[ 1] = 32'h00300113; // ADDI x2, x0, 3
        instructions_list[ 2] = 32'hffb00193; // ADDI x3, x0, -5
        instructions_list[ 3] = 32'h00208233; // ADD  x4, x1, x2
        instructions_list[ 4] = 32'h402082b3; // SUB  x5, x1, x2
        instructions_list[ 5] = 32'h0020f333; // AND  x6, x1, x2
        instructions_list[ 6] = 32'h0020e3b3; // OR   x7, x1, x2
        instructions_list[ 7] = 32'h0020c433; // XOR  x8, x1, x2
        instructions_list[ 8] = 32'h002094b3; // SLL  x9, x1, x2
        instructions_list[ 9] = 32'h0020d533; // SRL  x10, x1, x2
        instructions_list[10] = 32'h4021d5b3; // SRA  x11, x3, x2
        instructions_list[11] = 32'h0011a633; // SLT  x12, x3, x1
        instructions_list[12] = 32'h0030b6b3; // SLTU x13, x1, x3
        instructions_list[13] = 32'h0060f713; // ANDI x14, x1, 6
        instructions_list[14] = 32'h0050e793; // ORI  x15, x1, 5
        instructions_list[15] = 32'h00f0c813; // XORI x16, x1, 15
        instructions_list[16] = 32'h00409893; // SLLI x17, x1, 4
        instructions_list[17] = 32'h0010d913; // SRLI x18, x1, 1
        instructions_list[18] = 32'h4021d993; // SRAI x19, x3, 2
        instructions_list[19] = 32'h12345a37; // LUI  x20, 0x12345
        instructions_list[20] = 32'h00102023; // SW   x1, 0(x0)
        instructions_list[21] = 32'h00402223; // SW   x4, 4(x0)
        instructions_list[22] = 32'h00002a83; // LW   x21, 0(x0)
        instructions_list[23] = 32'h00402b03; // LW   x22, 4(x0)
        instructions_list[24] = 32'h00108463; // BEQ  x1, x1, 8
        instructions_list[25] = 32'h06300b93; // ADDI x23, x0, 99 (Skipped)
        instructions_list[26] = 32'h00100b93; // ADDI x23, x0, 1
        instructions_list[27] = 32'h00800c6f; // JAL  x24, 8
        instructions_list[28] = 32'h06300c93; // ADDI x25, x0, 99 (Skipped)
        instructions_list[29] = 32'h02a00c93; // ADDI x25, x0, 42
        instructions_list[30] = 32'h00000063; // BEQ  x0, x0, 0 (Halt)
        instructions_list[31] = 32'h00000013; // NOP

        end
        /*
        
        // === Words 0-3: Setup regs ===
        instructions_list[0]  = 32'h00A00093; // ADDI x1, x0, 10         x1=10
        instructions_list[1]  = 32'h01400113; // ADDI x2, x0, 20         x2=20
        instructions_list[2]  = 32'h00A00193; // ADDI x3, x0, 10         x3=10 (== x1)
        instructions_list[3]  = 32'h06300213; // ADDI x4, x0, 99         x4=99

        // === Word 4: BRANCH 1 - BEQ x1,x2,+24 NOT taken (10!=20) → MISPREDICTION ===
        instructions_list[4]  = 32'h00208C63; // BEQ x1, x2, +24  → pred TAKEN(w10), actual NOT taken
        // Correct path (after flush recovery):
        instructions_list[5]  = 32'h00B00293; // ADDI x5, x0, 11         x5=11
        instructions_list[6]  = 32'h01600313; // ADDI x6, x0, 22         x6=22

        // === Word 7: BRANCH 2 - BNE x1,x3,+20 NOT taken (10==10) → MISPREDICTION ===
        instructions_list[7]  = 32'h00309A63; // BNE x1, x3, +20  → pred TAKEN(w12), actual NOT taken
        // Correct path (after flush recovery, RAW on x5,x6):
        instructions_list[8]  = 32'h006283B3; // ADD x7, x5, x6          x7=11+22=33

        // === Word 9: BRANCH 3 - BEQ x1,x3,+8 TAKEN (10==10) → CORRECT PREDICTION ===
        instructions_list[9]  = 32'h00308463; // BEQ x1, x3, +8   → pred TAKEN(w11), actual TAKEN ✓
        instructions_list[10] = 32'hBAD00413; // ADDI x8, x0, -1107     SQUASHED (skipped)
        // Branch target:
        instructions_list[11] = 32'h02100493; // ADDI x9, x0, 33         x9=33

        // === Word 12: BRANCH 4 - BEQ x2,x4,+20 NOT taken (20!=99) → MISPREDICTION ===
        instructions_list[12] = 32'h00410A63; // BEQ x2, x4, +20  → pred TAKEN(w17), actual NOT taken
        // Correct path (after flush recovery, RAW on x7,x9):
        instructions_list[13] = 32'h00938533; // ADD x10, x7, x9         x10=33+33=66
        instructions_list[14] = 32'h02A00593; // ADDI x11, x0, 42        x11=42
        // Post-branch dependency chain:
        instructions_list[15] = 32'h00B50633; // ADD x12, x10, x11       x12=66+42=108

        // === Words 16-31: NOP ===
        instructions_list[16] = 32'h00000013;
        instructions_list[17] = 32'h00000013;
        instructions_list[18] = 32'h00000013;
        instructions_list[19] = 32'h00000013;
        instructions_list[20] = 32'h00000013;
        instructions_list[21] = 32'h00000013;
        instructions_list[22] = 32'h00000013;
        instructions_list[23] = 32'h00000013;
        instructions_list[24] = 32'h00000013;
        instructions_list[25] = 32'h00000013;
        instructions_list[26] = 32'h00000013;
        instructions_list[27] = 32'h00000013;
        instructions_list[28] = 32'h00000013;
        instructions_list[29] = 32'h00000013;
        instructions_list[30] = 32'h00000013;
        instructions_list[31] = 32'h00000013;
end*/
        /*initial begin : INIT_BLOCK
                // Zero-fill, then load from external hex file
                integer i;
                for (i = 0; i < 256; i = i + 1)
                    instructions_list[i] = 32'h00000013; // NOP
                $readmemh("program.hex", instructions_list);
            end*/
    
    always @(*)
    begin
    instruction_out1=instructions_list[(address[6:2])];
    instruction_out2=instructions_list[((address[6:2]) + 5'd1)&5'd31];
    instruction_out3=instructions_list[((address[6:2]) + 5'd2)&5'd31];
    instruction_out4=instructions_list[((address[6:2]) + 5'd3)&5'd31];
    address_out=address;
    end
    
endmodule
