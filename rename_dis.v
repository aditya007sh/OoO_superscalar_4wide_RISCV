module Rename_Dispatch(
    // ========== INPUTS FROM DECODE STAGE ==========
    // Logical register addresses (packed 4x5-bit)
    input [19:0] rd,           // Destination registers: rd[4:0]=inst0, rd[9:5]=inst1, ...
    input [19:0] rs1,          // Source1 registers: rs1[4:0]=inst0, rs1[9:5]=inst1, ...
    input [19:0] rs2,          // Source2 registers: rs2[4:0]=inst0, rs2[9:5]=inst1, ...
    
    // Validity signals (which registers are actually used)
    input [3:0] rs1_valid,     // inst0-3: which instructions have valid rs1
    input [3:0] rs2_valid,     // inst0-3: which instructions have valid rs2
    input [3:0] rd_valid,      // inst0-3: which instructions write destination
    
    // ========== INPUTS FROM RAT STAGE ==========
    // Physical register addresses from RAT (packed 4x6-bit)
    input [23:0] phys_rs1_rat,     // Physical source1 from RAT
    input [23:0] phys_rs2_rat,     // Physical source2 from RAT
    input [23:0] old_phys_reg_rat, // Old registers from RAT
    input [3:0] rd_valid_at_rename, // Write validity from RAT
    
    // ========== INPUTS FROM FREELIST STAGE ==========
    // Allocated physical registers (packed 4x6-bit)
    input [23:0] alloc_phys_rd,    // Allocated physical registers from Freelist
    input freelist_full,           // Stall signal from Freelist
    
    // ========== OUTPUTS TO DISPATCH/ISSUE QUEUE ==========
    // Physical register addresses (packed 4x6-bit)
    output wire [23:0] phys_rs1_final,     // Corrected physical source1 registers
    output wire [23:0] phys_rs2_final,     // Corrected physical source2 registers
    output wire [23:0] phys_rd_final,      // Physical destination registers
    
    // ========== OUTPUT TO ROB/COMMIT STAGE ==========
    // Old physical registers (for deallocation after instruction commits)
    output wire [23:0] old_phys_reg_final, // Corrected old registers to be freed
    
    // Validity signals (passed through for dispatch)
    output wire [3:0] rd_valid_final,      // Which instructions write destination
    output wire [3:0] rs1_valid_final,     // Which instructions have valid rs1
    output wire [3:0] rs2_valid_final,     // Which instructions have valid rs2
    output wire [3:0] rd_valid_at_rename_final // For safe deallocation
);
    // ========== UNPACK LOGICAL DESTINATION REGISTERS ==========
    wire [4:0] rd_0, rd_1, rd_2, rd_3;
    assign rd_0 = rd[4:0];
    assign rd_1 = rd[9:5];
    assign rd_2 = rd[14:10];
    assign rd_3 = rd[19:15];
    
    // ========== UNPACK LOGICAL SOURCE1 REGISTERS ==========
    wire [4:0] rs1_0, rs1_1, rs1_2, rs1_3;
    assign rs1_0 = rs1[4:0];
    assign rs1_1 = rs1[9:5];
    assign rs1_2 = rs1[14:10];
    assign rs1_3 = rs1[19:15];
    
    // ========== UNPACK LOGICAL SOURCE2 REGISTERS ==========
    wire [4:0] rs2_0, rs2_1, rs2_2, rs2_3;
    assign rs2_0 = rs2[4:0];
    assign rs2_1 = rs2[9:5];
    assign rs2_2 = rs2[14:10];
    assign rs2_3 = rs2[19:15];
    
    // ========== UNPACK PHYSICAL REGISTERS FROM RAT ==========
    wire [5:0] phys_rs1_rat_0, phys_rs1_rat_1, phys_rs1_rat_2, phys_rs1_rat_3;
    assign phys_rs1_rat_0 = phys_rs1_rat[5:0];
    assign phys_rs1_rat_1 = phys_rs1_rat[11:6];
    assign phys_rs1_rat_2 = phys_rs1_rat[17:12];
    assign phys_rs1_rat_3 = phys_rs1_rat[23:18];
    
    wire [5:0] phys_rs2_rat_0, phys_rs2_rat_1, phys_rs2_rat_2, phys_rs2_rat_3;
    assign phys_rs2_rat_0 = phys_rs2_rat[5:0];
    assign phys_rs2_rat_1 = phys_rs2_rat[11:6];
    assign phys_rs2_rat_2 = phys_rs2_rat[17:12];
    assign phys_rs2_rat_3 = phys_rs2_rat[23:18];
    
    wire [5:0] old_phys_rat_0, old_phys_rat_1, old_phys_rat_2, old_phys_rat_3;
    assign old_phys_rat_0 = old_phys_reg_rat[5:0];
    assign old_phys_rat_1 = old_phys_reg_rat[11:6];
    assign old_phys_rat_2 = old_phys_reg_rat[17:12];
    assign old_phys_rat_3 = old_phys_reg_rat[23:18];
    
    // ========== UNPACK ALLOCATED PHYSICAL REGISTERS FROM FREELIST ==========
    wire [5:0] alloc_0, alloc_1, alloc_2, alloc_3;
    assign alloc_0 = alloc_phys_rd[5:0];
    assign alloc_1 = alloc_phys_rd[11:6];
    assign alloc_2 = alloc_phys_rd[17:12];
    assign alloc_3 = alloc_phys_rd[23:18];
    
    // ========== FORWARDING LOGIC FOR SOURCE1 REGISTERS ==========
    // INSTRUCTION 0: No earlier instructions to check
    wire [5:0] phys_rs1_final_0;
    assign phys_rs1_final_0 = (rs1_valid[0]) ? phys_rs1_rat_0 : 6'b0;
    
    // INSTRUCTION 1: Check inst0 for RAW dependency
    // If inst0 writes to the register that inst1 reads, forward inst0's allocation
    wire [5:0] phys_rs1_final_1;
    assign phys_rs1_final_1 = 
        ((rs1_valid[1] == 1'b1) && (rd_valid[0] == 1'b1) && (rs1_1 == rd_0)) ? alloc_0 :
        (rs1_valid[1]) ? phys_rs1_rat_1 : 6'b0;
    
    // INSTRUCTION 2: Check inst0 and inst1 for RAW dependency
    // Priority: latest writer wins (inst1 > inst0)
    wire [5:0] phys_rs1_final_2;
    assign phys_rs1_final_2 = 
        ((rs1_valid[2]) && (rd_valid[1]) && (rs1_2 == rd_1)) ? alloc_1 :
        ((rs1_valid[2]) && (rd_valid[0]) && (rs1_2 == rd_0)) ? alloc_0 :
        (rs1_valid[2]) ? phys_rs1_rat_2 : 6'b0;
    
    // INSTRUCTION 3: Check inst0, inst1, and inst2 for RAW dependency
    // Priority: latest writer wins (inst2 > inst1 > inst0)
    wire [5:0] phys_rs1_final_3;
     assign phys_rs1_final_3 = 
         ((rs1_valid[3]) && (rd_valid[2]) && (rs1_3 == rd_2)) ? alloc_2 :
         ((rs1_valid[3]) && (rd_valid[1]) && (rs1_3 == rd_1)) ? alloc_1 :
         ((rs1_valid[3]) && (rd_valid[0]) && (rs1_3 == rd_0)) ? alloc_0 :
         (rs1_valid[3]) ? phys_rs1_rat_3 : 6'b0;
    
    // ========== FORWARDING LOGIC FOR SOURCE2 REGISTERS ==========
    // Same pattern as rs1
    
    // INSTRUCTION 0: No earlier instructions to check
    wire [5:0] phys_rs2_final_0;
    assign phys_rs2_final_0 = (rs2_valid[0]) ? phys_rs2_rat_0 : 6'b0;
    
    // INSTRUCTION 1: Check inst0 for RAW dependency
    wire [5:0] phys_rs2_final_1;
    assign phys_rs2_final_1 = 
        ((rs2_valid[1] == 1'b1) && (rd_valid[0] == 1'b1) && (rs2_1 == rd_0)) ? alloc_0 :
        (rs2_valid[1]) ? phys_rs2_rat_1 : 6'b0;
    
    // INSTRUCTION 2: Check inst0 and inst1 for RAW dependency
    wire [5:0] phys_rs2_final_2;
    assign phys_rs2_final_2 = 
        ((rs2_valid[2] == 1'b1) && (rd_valid[1] == 1'b1) && (rs2_2 == rd_1)) ? alloc_1 :
        ((rs2_valid[2] == 1'b1) && (rd_valid[0] == 1'b1) && (rs2_2 == rd_0)) ? alloc_0 :
        (rs2_valid[2]) ? phys_rs2_rat_2 : 6'b0;
    
    // INSTRUCTION 3: Check inst0, inst1, and inst2 for RAW dependency
    wire [5:0] phys_rs2_final_3;
    assign phys_rs2_final_3 = 
        ((rs2_valid[3] == 1'b1) && (rd_valid[2] == 1'b1) && (rs2_3 == rd_2)) ? alloc_2 :
        ((rs2_valid[3] == 1'b1) && (rd_valid[1] == 1'b1) && (rs2_3 == rd_1)) ? alloc_1 :
        ((rs2_valid[3] == 1'b1) && (rd_valid[0] == 1'b1) && (rs2_3 == rd_0)) ? alloc_0 :
        (rs2_valid[3]) ? phys_rs2_rat_3 : 6'b0;
    
    // ========== DESTINATION REGISTERS (NO FORWARDING NEEDED) ==========
    // Destination comes directly from freelist
    wire [5:0] phys_rd_final_0, phys_rd_final_1, phys_rd_final_2, phys_rd_final_3;
    assign phys_rd_final_0 = (rd_valid[0]) ? alloc_0 : 6'b0;
    assign phys_rd_final_1 = (rd_valid[1]) ? alloc_1 : 6'b0;
    assign phys_rd_final_2 = (rd_valid[2]) ? alloc_2 : 6'b0;
    assign phys_rd_final_3 = (rd_valid[3]) ? alloc_3 : 6'b0;
    
    // ========== WAW CASCADING FOR OLD_PHYS_REG ==========
    // If inst_j writes to same register as inst_i (where j < i),
    // then inst_i's old_phys should be inst_j's allocation, not the original RAT value
    
    // INSTRUCTION 0: No earlier instructions to check
    wire [5:0] old_phys_final_0;
    assign old_phys_final_0 = (rd_valid[0]) ? old_phys_rat_0 : 6'b0;
    
    // INSTRUCTION 1: Check inst0 for WAW conflict
    wire [5:0] old_phys_final_1;
    assign old_phys_final_1 = 
        ((rd_valid[1] == 1'b1) && (rd_valid[0] == 1'b1) && (rd_1 == rd_0)) ? alloc_0 :
        (rd_valid[1]) ? old_phys_rat_1 : 6'b0;
    
    // INSTRUCTION 2: Check inst0 and inst1 for WAW conflict
    // Priority: latest writer wins (inst1 > inst0)
    wire [5:0] old_phys_final_2;
    assign old_phys_final_2 = 
        ((rd_valid[2] == 1'b1) && (rd_valid[1] == 1'b1) && (rd_2 == rd_1)) ? alloc_1 :
        ((rd_valid[2] == 1'b1) && (rd_valid[0] == 1'b1) && (rd_2 == rd_0)) ? alloc_0 :
        (rd_valid[2]) ? old_phys_rat_2 : 6'b0;
    
    // INSTRUCTION 3: Check inst0, inst1, and inst2 for WAW conflict
    // Priority: latest writer wins (inst2 > inst1 > inst0)
    wire [5:0] old_phys_final_3;
    assign old_phys_final_3 = 
        ((rd_valid[3] == 1'b1) && (rd_valid[2] == 1'b1) && (rd_3 == rd_2)) ? alloc_2 :
        ((rd_valid[3] == 1'b1) && (rd_valid[1] == 1'b1) && (rd_3 == rd_1)) ? alloc_1 :
        ((rd_valid[3] == 1'b1) && (rd_valid[0] == 1'b1) && (rd_3 == rd_0)) ? alloc_0 :
        (rd_valid[3]) ? old_phys_rat_3 : 6'b0;
    
    // ========== PACK OUTPUTS ==========
    assign phys_rs1_final = {phys_rs1_final_3, phys_rs1_final_2, phys_rs1_final_1, phys_rs1_final_0};
    assign phys_rs2_final = {phys_rs2_final_3, phys_rs2_final_2, phys_rs2_final_1, phys_rs2_final_0};
    assign phys_rd_final = {phys_rd_final_3, phys_rd_final_2, phys_rd_final_1, phys_rd_final_0};
    assign old_phys_reg_final = {old_phys_final_3, old_phys_final_2, old_phys_final_1, old_phys_final_0};
    
    // ========== PASS THROUGH VALIDITY SIGNALS ==========
    assign rd_valid_final = rd_valid;
    assign rs1_valid_final = rs1_valid;
    assign rs2_valid_final = rs2_valid;
    assign rd_valid_at_rename_final = rd_valid_at_rename;

endmodule
