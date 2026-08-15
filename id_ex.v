
module id_iq_buffer (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    input  wire        stall,          // ROB/IQ/LSQ/freelist full

    // ================================================================
    // FROM DECODE_TOP - per-instruction decoded fields
    // ================================================================
    input  wire [6:0]  ins0_opcode, ins1_opcode, ins2_opcode, ins3_opcode,
    input  wire [2:0]  ins0_funct3, ins1_funct3, ins2_funct3, ins3_funct3,
    input  wire [6:0]  ins0_funct7, ins1_funct7, ins2_funct7, ins3_funct7,
    input  wire [31:0] ins0_imm, ins1_imm, ins2_imm, ins3_imm,
    input  wire [4:0]  ins0_rd, ins1_rd, ins2_rd, ins3_rd,

    // Type flags (per-instruction, 1-bit each)
    input  wire ins0_is_alu, ins1_is_alu, ins2_is_alu, ins3_is_alu,
    input  wire ins0_is_mul, ins1_is_mul, ins2_is_mul, ins3_is_mul,
    input  wire ins0_is_load, ins1_is_load, ins2_is_load, ins3_is_load,
    input  wire ins0_is_store, ins1_is_store, ins2_is_store, ins3_is_store,
    input  wire ins0_is_branch, ins1_is_branch, ins2_is_branch, ins3_is_branch,
    input  wire ins0_is_jal, ins1_is_jal, ins2_is_jal, ins3_is_jal,
    input  wire ins0_is_jalr, ins1_is_jalr, ins2_is_jalr, ins3_is_jalr,
    input  wire ins0_is_lui, ins1_is_lui, ins2_is_lui, ins3_is_lui,
    input  wire ins0_is_auipc, ins1_is_auipc, ins2_is_auipc, ins3_is_auipc,

    // Packed rename outputs from Decode_Top
    input  wire [23:0] phys_rs1_in,
    input  wire [23:0] phys_rs2_in,
    input  wire [23:0] phys_rd_in,
    input  wire [23:0] old_phys_reg_in,
    input  wire [3:0]  rd_valid_in,
    input  wire [3:0]  rs1_valid_in,
    input  wire [3:0]  rs2_valid_in,
    input  wire [3:0]  rd_valid_at_rename_in,
    input  wire [3:0]  valid_in,

    // PC from Decode_Top
    input  wire [31:0] pc0_in, pc1_in, pc2_in, pc3_in,

    // ================================================================
    // TO ISSUE_TOP - packed dispatch format
    // ================================================================
    output reg  [3:0]   dispatch_valid,
    output reg  [3:0]   dispatch_is_alu,
    output reg  [3:0]   dispatch_is_mul,
    output reg  [3:0]   dispatch_is_load,
    output reg  [3:0]   dispatch_is_store,
    output reg  [3:0]   dispatch_is_branch,
    output reg  [3:0]   dispatch_is_jal,
    output reg  [3:0]   dispatch_is_jalr,
    output reg  [3:0]   dispatch_is_lui,
    output reg  [3:0]   dispatch_is_auipc,

    output reg  [23:0]  dispatch_phys_rs1,
    output reg  [23:0]  dispatch_phys_rs2,
    output reg  [23:0]  dispatch_phys_rd,
    output reg  [23:0]  dispatch_old_phys_rd,
    output reg  [19:0]  dispatch_arch_rd,
    output reg  [3:0]   dispatch_rd_valid,
    output reg  [3:0]   dispatch_rs1_valid,
    output reg  [3:0]   dispatch_rs2_valid,

    output reg  [27:0]  dispatch_opcode,      // packed 4×7
    output reg  [11:0]  dispatch_funct3,      // packed 4×3
    output reg  [27:0]  dispatch_funct7,      // packed 4×7
    output reg  [127:0] dispatch_imm,         // packed 4×32

    output reg  [31:0]  dispatch_pc0,
    output reg  [31:0]  dispatch_pc1,
    output reg  [31:0]  dispatch_pc2,
    output reg  [31:0]  dispatch_pc3,
    output reg  [3:0]   dispatch_rd_valid_at_rename
);

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            dispatch_valid      <= 4'b0;
            dispatch_is_alu     <= 4'b0;
            dispatch_is_mul     <= 4'b0;
            dispatch_is_load    <= 4'b0;
            dispatch_is_store   <= 4'b0;
            dispatch_is_branch  <= 4'b0;
            dispatch_is_jal     <= 4'b0;
            dispatch_is_jalr    <= 4'b0;
            dispatch_is_lui     <= 4'b0;
            dispatch_is_auipc   <= 4'b0;
            dispatch_phys_rs1   <= 24'b0;
            dispatch_phys_rs2   <= 24'b0;
            dispatch_phys_rd    <= 24'b0;
            dispatch_old_phys_rd<= 24'b0;
            dispatch_arch_rd    <= 20'b0;
            dispatch_rd_valid   <= 4'b0;
            dispatch_rs1_valid  <= 4'b0;
            dispatch_rs2_valid  <= 4'b0;
            dispatch_opcode     <= 28'b0;
            dispatch_funct3     <= 12'b0;
            dispatch_funct7     <= 28'b0;
            dispatch_imm        <= 128'b0;
            dispatch_pc0        <= 32'b0;
            dispatch_pc1        <= 32'b0;
            dispatch_pc2        <= 32'b0;
            dispatch_pc3        <= 32'b0;
            dispatch_rd_valid_at_rename <= 4'b0;  // FIX: was missing from reset/flush
        end
        else if (!stall) begin
            // ---- Validity ----
            dispatch_valid <= valid_in;

            // ---- Type flags: pack per-instruction bits into 4-bit buses ----
            dispatch_is_alu    <= {ins3_is_alu,    ins2_is_alu,    ins1_is_alu,    ins0_is_alu};
            dispatch_is_mul    <= {ins3_is_mul,    ins2_is_mul,    ins1_is_mul,    ins0_is_mul};
            dispatch_is_load   <= {ins3_is_load,   ins2_is_load,   ins1_is_load,   ins0_is_load};
            dispatch_is_store  <= {ins3_is_store,  ins2_is_store,  ins1_is_store,  ins0_is_store};
            dispatch_is_branch <= {ins3_is_branch, ins2_is_branch, ins1_is_branch, ins0_is_branch};
            dispatch_is_jal    <= {ins3_is_jal,    ins2_is_jal,    ins1_is_jal,    ins0_is_jal};
            dispatch_is_jalr   <= {ins3_is_jalr,   ins2_is_jalr,   ins1_is_jalr,   ins0_is_jalr};
            dispatch_is_lui    <= {ins3_is_lui,    ins2_is_lui,    ins1_is_lui,    ins0_is_lui};
            dispatch_is_auipc  <= {ins3_is_auipc,  ins2_is_auipc,  ins1_is_auipc,  ins0_is_auipc};

            // ---- Renamed registers: already packed, pass through ----
            dispatch_phys_rs1    <= phys_rs1_in;
            dispatch_phys_rs2    <= phys_rs2_in;
            dispatch_phys_rd     <= phys_rd_in;
            dispatch_old_phys_rd <= old_phys_reg_in;
            dispatch_rd_valid    <= rd_valid_in;
            dispatch_rs1_valid   <= rs1_valid_in;
            dispatch_rs2_valid   <= rs2_valid_in;

            // ---- Arch rd: pack 4×5-bit ----
            dispatch_arch_rd <= {ins3_rd, ins2_rd, ins1_rd, ins0_rd};

            // ---- Opcode: pack 4×7-bit ----
            dispatch_opcode <= {ins3_opcode, ins2_opcode, ins1_opcode, ins0_opcode};

            // ---- Funct3: pack 4×3-bit ----
            dispatch_funct3 <= {ins3_funct3, ins2_funct3, ins1_funct3, ins0_funct3};

            // ---- Funct7: pack 4×7-bit ----
            dispatch_funct7 <= {ins3_funct7, ins2_funct7, ins1_funct7, ins0_funct7};

            // ---- Imm: pack 4×32-bit ----
            dispatch_imm <= {ins3_imm, ins2_imm, ins1_imm, ins0_imm};

            // ---- PC ----
            dispatch_pc0 <= pc0_in;
            dispatch_pc1 <= pc1_in;
            dispatch_pc2 <= pc2_in;
            dispatch_pc3 <= pc3_in;
            dispatch_rd_valid_at_rename <= rd_valid_at_rename_in;
        end
        // else: stall - hold all values
    end

endmodule

