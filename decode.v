
module Decode_Single(
    input [31:0] instr,
    
    // Operand information
    output [4:0] rs1,
    output [4:0] rs2,
    output [4:0] rd,
    output [31:0] imm,
    
    // Validity flags (from instruction format only)
    output rs1_valid,
    output rs2_valid,
    output rd_valid,
    
    // Instruction type
    output [6:0] opcode,
    output [2:0] funct3,
    output [6:0] funct7,
    
    // Decoded control signals
    output is_alu,
    output is_mul,
    output is_load,
    output is_store,
    output is_branch,
    output is_jal,
    output is_jalr,
    output is_lui,
    output is_auipc
);

    // ========== FIELD EXTRACTION ==========
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // ========== IMMEDIATE DECODING ==========
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;  
    
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // ========== CONTROL SIGNALS ==========
    reg rs1_valid_reg, rs2_valid_reg, rd_valid_reg;//for rat to know which prf to assign
    reg [31:0] imm_reg;//select right immed value of 5 
    reg is_alu_reg, is_mul_reg, is_load_reg, is_store_reg, is_branch_reg;
    reg is_jal_reg, is_jalr_reg, is_lui_reg, is_auipc_reg;

    always @(*) begin
        // Default values
        imm_reg        = 32'b0;
        rs1_valid_reg  = 1'b0;
        rs2_valid_reg  = 1'b0;
        rd_valid_reg   = 1'b0;
        
        is_alu_reg     = 1'b0;
        is_mul_reg     = 1'b0;
        is_load_reg    = 1'b0;
        is_store_reg   = 1'b0;
        is_branch_reg  = 1'b0;
        is_jal_reg     = 1'b0;
        is_jalr_reg    = 1'b0;
        is_lui_reg     = 1'b0;
        is_auipc_reg   = 1'b0;

        case(opcode)
            7'b0110011: begin  // R-type (ALU or MUL)
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b1;
                rd_valid_reg  = 1'b1;
                if (funct7 == 7'b0000001)  // M-extension: MUL/MULH/MULHSU/MULHU
                    is_mul_reg = 1'b1;
                else
                    is_alu_reg = 1'b1;
            end
            
            7'b0010011: begin  // I-type ALU
                is_alu_reg    = 1'b1;
                imm_reg       = imm_i;
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            7'b0000011: begin  // LOAD
                is_load_reg   = 1'b1;
                imm_reg       = imm_i;
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            7'b0100011: begin  // STORE
                is_store_reg  = 1'b1;
                imm_reg       = imm_s;
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b1;
                rd_valid_reg  = 1'b0;
            end
            
            7'b1100011: begin  // BRANCH
                is_branch_reg = 1'b1;
                imm_reg       = imm_b;
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b1;
                rd_valid_reg  = 1'b0;
            end
            
            7'b1101111: begin  // JAL
                is_jal_reg    = 1'b1;
                imm_reg       = imm_j;
                rs1_valid_reg = 1'b0;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            7'b1100111: begin  // JALR
                is_jalr_reg   = 1'b1;
                imm_reg       = imm_i;
                rs1_valid_reg = 1'b1;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            7'b0110111: begin  // LUI
                is_lui_reg    = 1'b1;
                imm_reg       = imm_u;
                rs1_valid_reg = 1'b0;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            7'b0010111: begin  // AUIPC
                is_auipc_reg  = 1'b1;
                imm_reg       = imm_u;
                rs1_valid_reg = 1'b0;
                rs2_valid_reg = 1'b0;
                rd_valid_reg  = 1'b1;
            end
            
            //default: begin  //i think its not required
               // rd_valid_reg  = 1'b0;
            //end
        endcase
    end

    // ========== ASSIGN OUTPUTS ==========
    assign rs1_valid  = rs1_valid_reg;
    assign rs2_valid  = rs2_valid_reg;
    assign rd_valid   = rd_valid_reg & (rd != 5'b0);
    assign imm        = imm_reg;
    assign is_alu     = is_alu_reg;
    assign is_mul     = is_mul_reg;
    assign is_load    = is_load_reg;
    assign is_store   = is_store_reg;
    assign is_branch  = is_branch_reg;
    assign is_jal     = is_jal_reg;
    assign is_jalr    = is_jalr_reg;
    assign is_lui     = is_lui_reg;
    assign is_auipc   = is_auipc_reg;

endmodule
// ========================================
// 4-WIDE DECODE
// ========================================
module Decode_4Wide(
    input [31:0] ins0_in,
    input [31:0] ins1_in,
    input [31:0] ins2_in,
    input [31:0] ins3_in,
    input [3:0] valid_in,  // From fetch (branch predictions)
    
    // ===== INSTRUCTION 0 DECODED OUTPUTS =====
    output [4:0] ins0_rs1,
    output [4:0] ins0_rs2,
    output [4:0] ins0_rd,
    output [31:0] ins0_imm,
    output ins0_rs1_valid,      // GATED with valid_in[0]
    output ins0_rs2_valid,      // GATED with valid_in[0]
    output ins0_rd_valid,       // GATED with valid_in[0]
    output [6:0] ins0_opcode,
    output [2:0] ins0_funct3,
    output [6:0] ins0_funct7,
    output ins0_is_alu,
    output ins0_is_mul,
    output ins0_is_load,
    output ins0_is_store,
    output ins0_is_branch,
    output ins0_is_jal,
    output ins0_is_jalr,
    output ins0_is_lui,
    output ins0_is_auipc,
    
    // ===== INSTRUCTION 1 DECODED OUTPUTS =====
    output [4:0] ins1_rs1,
    output [4:0] ins1_rs2,
    output [4:0] ins1_rd,
    output [31:0] ins1_imm,
    output ins1_rs1_valid,      // GATED with valid_in[1]
    output ins1_rs2_valid,      // GATED with valid_in[1]
    output ins1_rd_valid,       // GATED with valid_in[1]
    output [6:0] ins1_opcode,
    output [2:0] ins1_funct3,
    output [6:0] ins1_funct7,
    output ins1_is_alu,
    output ins1_is_mul,
    output ins1_is_load,
    output ins1_is_store,
    output ins1_is_branch,
    output ins1_is_jal,
    output ins1_is_jalr,
    output ins1_is_lui,
    output ins1_is_auipc,
    
    // ===== INSTRUCTION 2 DECODED OUTPUTS =====
    output [4:0] ins2_rs1,
    output [4:0] ins2_rs2,
    output [4:0] ins2_rd,
    output [31:0] ins2_imm,
    output ins2_rs1_valid,      // GATED with valid_in[2]
    output ins2_rs2_valid,      // GATED with valid_in[2]
    output ins2_rd_valid,       // GATED with valid_in[2]
    output [6:0] ins2_opcode,
    output [2:0] ins2_funct3,
    output [6:0] ins2_funct7,
    output ins2_is_alu,
    output ins2_is_mul,
    output ins2_is_load,
    output ins2_is_store,
    output ins2_is_branch,
    output ins2_is_jal,
    output ins2_is_jalr,
    output ins2_is_lui,
    output ins2_is_auipc,
    
    // ===== INSTRUCTION 3 DECODED OUTPUTS =====
    output [4:0] ins3_rs1,
    output [4:0] ins3_rs2,
    output [4:0] ins3_rd,
    output [31:0] ins3_imm,
    output ins3_rs1_valid,      // GATED with valid_in[3]
    output ins3_rs2_valid,      // GATED with valid_in[3]
    output ins3_rd_valid,       // GATED with valid_in[3]
    output [6:0] ins3_opcode,
    output [2:0] ins3_funct3,
    output [6:0] ins3_funct7,
    output ins3_is_alu,
    output ins3_is_mul,
    output ins3_is_load,
    output ins3_is_store,
    output ins3_is_branch,
    output ins3_is_jal,
    output ins3_is_jalr,
    output ins3_is_lui,
    output ins3_is_auipc,
    
    output [3:0] valid_out
);

    // ========== INTERNAL WIRES FROM RAW DECODERS ==========
    // Decoder 0 outputs
    wire decoder0_rs1_valid, decoder0_rs2_valid, decoder0_rd_valid;
    wire decoder0_is_alu, decoder0_is_mul, decoder0_is_load, decoder0_is_store, decoder0_is_branch;
    wire decoder0_is_jal, decoder0_is_jalr, decoder0_is_lui, decoder0_is_auipc;
    
    // Decoder 1 outputs
    wire decoder1_rs1_valid, decoder1_rs2_valid, decoder1_rd_valid;
    wire decoder1_is_alu, decoder1_is_mul, decoder1_is_load, decoder1_is_store, decoder1_is_branch;
    wire decoder1_is_jal, decoder1_is_jalr, decoder1_is_lui, decoder1_is_auipc;
    
    // Decoder 2 outputs
    wire decoder2_rs1_valid, decoder2_rs2_valid, decoder2_rd_valid;
    wire decoder2_is_alu, decoder2_is_mul, decoder2_is_load, decoder2_is_store, decoder2_is_branch;
    wire decoder2_is_jal, decoder2_is_jalr, decoder2_is_lui, decoder2_is_auipc;
    
    // Decoder 3 outputs
    wire decoder3_rs1_valid, decoder3_rs2_valid, decoder3_rd_valid;
    wire decoder3_is_alu, decoder3_is_mul, decoder3_is_load, decoder3_is_store, decoder3_is_branch;
    wire decoder3_is_jal, decoder3_is_jalr, decoder3_is_lui, decoder3_is_auipc;


    // ========== INSTANTIATE DECODER 0 ==========
    Decode_Single decoder0(
        .instr(ins0_in),
        .rs1(ins0_rs1),
        .rs2(ins0_rs2),
        .rd(ins0_rd),
        .imm(ins0_imm),
        .rs1_valid(decoder0_rs1_valid),
        .rs2_valid(decoder0_rs2_valid),
        .rd_valid(decoder0_rd_valid),
        .opcode(ins0_opcode),
        .funct3(ins0_funct3),
        .funct7(ins0_funct7),
        .is_alu(decoder0_is_alu),
        .is_mul(decoder0_is_mul),
        .is_load(decoder0_is_load),
        .is_store(decoder0_is_store),
        .is_branch(decoder0_is_branch),
        .is_jal(decoder0_is_jal),
        .is_jalr(decoder0_is_jalr),
        .is_lui(decoder0_is_lui),
        .is_auipc(decoder0_is_auipc)
    );

    // ========== INSTANTIATE DECODER 1 ==========
    Decode_Single decoder1(
        .instr(ins1_in),
        .rs1(ins1_rs1),
        .rs2(ins1_rs2),
        .rd(ins1_rd),
        .imm(ins1_imm),
        .rs1_valid(decoder1_rs1_valid),
        .rs2_valid(decoder1_rs2_valid),
        .rd_valid(decoder1_rd_valid),
        .opcode(ins1_opcode),
        .funct3(ins1_funct3),
        .funct7(ins1_funct7),
        .is_alu(decoder1_is_alu),
        .is_mul(decoder1_is_mul),
        .is_load(decoder1_is_load),
        .is_store(decoder1_is_store),
        .is_branch(decoder1_is_branch),
        .is_jal(decoder1_is_jal),
        .is_jalr(decoder1_is_jalr),
        .is_lui(decoder1_is_lui),
        .is_auipc(decoder1_is_auipc)
    );

    // ========== INSTANTIATE DECODER 2 ==========
    Decode_Single decoder2(
        .instr(ins2_in),
        .rs1(ins2_rs1),
        .rs2(ins2_rs2),
        .rd(ins2_rd),
        .imm(ins2_imm),
        .rs1_valid(decoder2_rs1_valid),
        .rs2_valid(decoder2_rs2_valid),
        .rd_valid(decoder2_rd_valid),
        .opcode(ins2_opcode),
        .funct3(ins2_funct3),
        .funct7(ins2_funct7),
        .is_alu(decoder2_is_alu),
        .is_mul(decoder2_is_mul),
        .is_load(decoder2_is_load),
        .is_store(decoder2_is_store),
        .is_branch(decoder2_is_branch),
        .is_jal(decoder2_is_jal),
        .is_jalr(decoder2_is_jalr),
        .is_lui(decoder2_is_lui),
        .is_auipc(decoder2_is_auipc)
    );

    // ========== INSTANTIATE DECODER 3 ==========
    Decode_Single decoder3(
        .instr(ins3_in),
        .rs1(ins3_rs1),
        .rs2(ins3_rs2),
        .rd(ins3_rd),
        .imm(ins3_imm),
        .rs1_valid(decoder3_rs1_valid),
        .rs2_valid(decoder3_rs2_valid),
        .rd_valid(decoder3_rd_valid),
        .opcode(ins3_opcode),
        .funct3(ins3_funct3),
        .funct7(ins3_funct7),
        .is_alu(decoder3_is_alu),
        .is_mul(decoder3_is_mul),
        .is_load(decoder3_is_load),
        .is_store(decoder3_is_store),
        .is_branch(decoder3_is_branch),
        .is_jal(decoder3_is_jal),
        .is_jalr(decoder3_is_jalr),
        .is_lui(decoder3_is_lui),
        .is_auipc(decoder3_is_auipc)
    );


// ========== VALIDITY GATING FOR INSTRUCTION 0 ==========
// Register validity - CRITICAL
assign ins0_rs1_valid = decoder0_rs1_valid & valid_in[0];
assign ins0_rs2_valid = decoder0_rs2_valid & valid_in[0];
assign ins0_rd_valid  = decoder0_rd_valid  & valid_in[0];

// Instruction type - SAFETY & CLARITY
assign ins0_is_alu    = decoder0_is_alu    & valid_in[0];
assign ins0_is_mul    = decoder0_is_mul    & valid_in[0];
assign ins0_is_load   = decoder0_is_load   & valid_in[0];
assign ins0_is_store  = decoder0_is_store  & valid_in[0];
assign ins0_is_branch = decoder0_is_branch & valid_in[0];
assign ins0_is_jal    = decoder0_is_jal    & valid_in[0];
assign ins0_is_jalr   = decoder0_is_jalr   & valid_in[0];
assign ins0_is_lui    = decoder0_is_lui    & valid_in[0];
assign ins0_is_auipc  = decoder0_is_auipc  & valid_in[0];

// ========== VALIDITY GATING FOR INSTRUCTION 1 ==========
assign ins1_rs1_valid = decoder1_rs1_valid & valid_in[1];
assign ins1_rs2_valid = decoder1_rs2_valid & valid_in[1];
assign ins1_rd_valid  = decoder1_rd_valid  & valid_in[1];

assign ins1_is_alu    = decoder1_is_alu    & valid_in[1];
assign ins1_is_mul    = decoder1_is_mul    & valid_in[1];
assign ins1_is_load   = decoder1_is_load   & valid_in[1];
assign ins1_is_store  = decoder1_is_store  & valid_in[1];
assign ins1_is_branch = decoder1_is_branch & valid_in[1];
assign ins1_is_jal    = decoder1_is_jal    & valid_in[1];
assign ins1_is_jalr   = decoder1_is_jalr   & valid_in[1];
assign ins1_is_lui    = decoder1_is_lui    & valid_in[1];
assign ins1_is_auipc  = decoder1_is_auipc  & valid_in[1];

// ========== VALIDITY GATING FOR INSTRUCTION 2 ==========
assign ins2_rs1_valid = decoder2_rs1_valid & valid_in[2];
assign ins2_rs2_valid = decoder2_rs2_valid & valid_in[2];
assign ins2_rd_valid  = decoder2_rd_valid  & valid_in[2];

assign ins2_is_alu    = decoder2_is_alu    & valid_in[2];
assign ins2_is_mul    = decoder2_is_mul    & valid_in[2];
assign ins2_is_load   = decoder2_is_load   & valid_in[2];
assign ins2_is_store  = decoder2_is_store  & valid_in[2];
assign ins2_is_branch = decoder2_is_branch & valid_in[2];
assign ins2_is_jal    = decoder2_is_jal    & valid_in[2];
assign ins2_is_jalr   = decoder2_is_jalr   & valid_in[2];
assign ins2_is_lui    = decoder2_is_lui    & valid_in[2];
assign ins2_is_auipc  = decoder2_is_auipc  & valid_in[2];

// ========== VALIDITY GATING FOR INSTRUCTION 3 ==========
assign ins3_rs1_valid = decoder3_rs1_valid & valid_in[3];
assign ins3_rs2_valid = decoder3_rs2_valid & valid_in[3];
assign ins3_rd_valid  = decoder3_rd_valid  & valid_in[3];

assign ins3_is_alu    = decoder3_is_alu    & valid_in[3];
assign ins3_is_mul    = decoder3_is_mul    & valid_in[3];
assign ins3_is_load   = decoder3_is_load   & valid_in[3];
assign ins3_is_store  = decoder3_is_store  & valid_in[3];
assign ins3_is_branch = decoder3_is_branch & valid_in[3];
assign ins3_is_jal    = decoder3_is_jal    & valid_in[3];
assign ins3_is_jalr   = decoder3_is_jalr   & valid_in[3];
assign ins3_is_lui    = decoder3_is_lui    & valid_in[3];
assign ins3_is_auipc  = decoder3_is_auipc  & valid_in[3];

    // ========== PROPAGATE VALIDITY ==========
    assign valid_out = valid_in;

endmodule

