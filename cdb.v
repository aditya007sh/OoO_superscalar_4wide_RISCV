
module CDB #( parameter ROB_PTR_W = 6 )(

    // ALU 0
    input wire alu0_valid,
    input wire [ROB_PTR_W-1:0] alu0_rob_idx,
    input wire [5:0] alu0_phys_reg,
    input wire [31:0] alu0_result,

    // ALU 1
    input wire alu1_valid,
    input wire [ROB_PTR_W-1:0] alu1_rob_idx,
    input wire [5:0] alu1_phys_reg,
    input wire [31:0] alu1_result,

    // ALU 2
    input wire alu2_valid,
    input wire [ROB_PTR_W-1:0] alu2_rob_idx,
    input wire [5:0] alu2_phys_reg,
    input wire [31:0] alu2_result,

    // ALU 3
    input wire alu3_valid,
    input wire [ROB_PTR_W-1:0] alu3_rob_idx,
    input wire [5:0] alu3_phys_reg,
    input wire [31:0] alu3_result,

    // BPU
    input wire bpu_valid,
    input wire [ROB_PTR_W-1:0] bpu_rob_idx,
    input wire [5:0] bpu_phys_reg,
    input wire [31:0] bpu_result,
    input wire bpu_mispredict,
    input wire [31:0] bpu_correct_pc,

    // LSQ
    input wire lsq_valid,
    input wire [7:0] lsq_tag,
    input wire [5:0] lsq_phys_reg,
    input wire [31:0] lsq_result,

    // MUL
    input wire mul_valid,
    input wire [ROB_PTR_W-1:0] mul_rob_idx,
    input wire [5:0] mul_phys_reg,
    input wire [31:0] mul_result,

    output wire cdb_fu0_valid,
    output wire [ROB_PTR_W-1:0] cdb_fu0_rob_idx,
    output wire [5:0] cdb_fu0_phys_reg,
    output wire [31:0] cdb_fu0_result,

    output wire cdb_fu1_valid,
    output wire [ROB_PTR_W-1:0] cdb_fu1_rob_idx,
    output wire [5:0] cdb_fu1_phys_reg,
    output wire [31:0] cdb_fu1_result,

    output wire cdb_fu2_valid,
    output wire [ROB_PTR_W-1:0] cdb_fu2_rob_idx,
    output wire [5:0] cdb_fu2_phys_reg,
    output wire [31:0] cdb_fu2_result,

    output wire cdb_fu3_valid,
    output wire [ROB_PTR_W-1:0] cdb_fu3_rob_idx,
    output wire [5:0] cdb_fu3_phys_reg,
    output wire [31:0] cdb_fu3_result,

    output wire cdb_bpu_valid,
    output wire [ROB_PTR_W-1:0] cdb_bpu_rob_idx,
    output wire [5:0] cdb_bpu_phys_reg,
    output wire [31:0] cdb_bpu_result,
    output wire cdb_bpu_mispredict,
    output wire [31:0] cdb_bpu_correct_pc,

    output wire cdb_lsq_valid,
    output wire [ROB_PTR_W-1:0] cdb_lsq_rob_idx,
    output wire [5:0] cdb_lsq_phys_reg,
    output wire [31:0] cdb_lsq_result,

    output wire cdb_mul_valid,
    output wire [ROB_PTR_W-1:0] cdb_mul_rob_idx,
    output wire [5:0] cdb_mul_phys_reg,
    output wire [31:0] cdb_mul_result
);

// ALU 0
assign cdb_fu0_valid = alu0_valid;
assign cdb_fu0_rob_idx = alu0_rob_idx;
assign cdb_fu0_phys_reg = alu0_phys_reg;
assign cdb_fu0_result = alu0_result;

// ALU 1
assign cdb_fu1_valid = alu1_valid;
assign cdb_fu1_rob_idx = alu1_rob_idx;
assign cdb_fu1_phys_reg = alu1_phys_reg;
assign cdb_fu1_result = alu1_result;

// ALU 2
assign cdb_fu2_valid = alu2_valid;
assign cdb_fu2_rob_idx = alu2_rob_idx;
assign cdb_fu2_phys_reg = alu2_phys_reg;
assign cdb_fu2_result = alu2_result;

// ALU 3
assign cdb_fu3_valid = alu3_valid;
assign cdb_fu3_rob_idx = alu3_rob_idx;
assign cdb_fu3_phys_reg = alu3_phys_reg;
assign cdb_fu3_result = alu3_result;

// BPU
assign cdb_bpu_valid = bpu_valid;
assign cdb_bpu_rob_idx = bpu_rob_idx;
assign cdb_bpu_phys_reg = bpu_phys_reg;
assign cdb_bpu_result = bpu_result;
assign cdb_bpu_mispredict = bpu_mispredict;
assign cdb_bpu_correct_pc = bpu_correct_pc;

// LSQ
assign cdb_lsq_valid = lsq_valid;
assign cdb_lsq_rob_idx = lsq_tag[ROB_PTR_W-1:0];
assign cdb_lsq_phys_reg = lsq_phys_reg;
assign cdb_lsq_result = lsq_result;

// MUL
assign cdb_mul_valid = mul_valid;
assign cdb_mul_rob_idx = mul_rob_idx;
assign cdb_mul_phys_reg = mul_phys_reg;
assign cdb_mul_result = mul_result;

endmodule
