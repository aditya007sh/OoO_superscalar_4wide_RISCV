/*module Execute_Top #(
    parameter ROB_PTR_W = 6,
    parameter LSQ_PTR_W = 5
)(
    // ================================================================
    // FROM IQ/EX BUFFER - FU0
    // ================================================================
    input  wire        fu0_valid_in,
    input  wire [7:0]  fu0_seq_num,
    input  wire [6:0]  fu0_opcode,
    input  wire [2:0]  fu0_funct3,
    input  wire [6:0]  fu0_funct7,
    input  wire [31:0] fu0_imm,
    input  wire [5:0]  fu0_phys_rd,
    input  wire [31:0] fu0_rs1_val,
    input  wire [31:0] fu0_rs2_val,
    input  wire [31:0] fu0_pc,

    // FU1
    input  wire        fu1_valid_in,
    input  wire [7:0]  fu1_seq_num,
    input  wire [6:0]  fu1_opcode,
    input  wire [2:0]  fu1_funct3,
    input  wire [6:0]  fu1_funct7,
    input  wire [31:0] fu1_imm,
    input  wire [5:0]  fu1_phys_rd,
    input  wire [31:0] fu1_rs1_val,
    input  wire [31:0] fu1_rs2_val,
    input  wire [31:0] fu1_pc,

    // FU2
    input  wire        fu2_valid_in,
    input  wire [7:0]  fu2_seq_num,
    input  wire [6:0]  fu2_opcode,
    input  wire [2:0]  fu2_funct3,
    input  wire [6:0]  fu2_funct7,
    input  wire [31:0] fu2_imm,
    input  wire [5:0]  fu2_phys_rd,
    input  wire [31:0] fu2_rs1_val,
    input  wire [31:0] fu2_rs2_val,
    input  wire [31:0] fu2_pc,

    // FU3
    input  wire        fu3_valid_in,
    input  wire [7:0]  fu3_seq_num,
    input  wire [6:0]  fu3_opcode,
    input  wire [2:0]  fu3_funct3,
    input  wire [6:0]  fu3_funct7,
    input  wire [31:0] fu3_imm,
    input  wire [5:0]  fu3_phys_rd,
    input  wire [31:0] fu3_rs1_val,
    input  wire [31:0] fu3_rs2_val,
    input  wire [31:0] fu3_pc,

    // BPU
    input  wire        bpu_valid_in,
    input  wire [7:0]  bpu_seq_num,
    input  wire [6:0]  bpu_opcode,
    input  wire [2:0]  bpu_funct3,
    input  wire [31:0] bpu_imm,
    input  wire [5:0]  bpu_phys_rd,
    input  wire [31:0] bpu_rs1_val,
    input  wire [31:0] bpu_rs2_val,
    input  wire [31:0] bpu_pc,

    // AGU
    input  wire                  agu_valid_in,
    input  wire [LSQ_PTR_W-1:0]  agu_lsq_idx,
    input  wire [31:0]           agu_rs1_val,
    input  wire [31:0]           agu_rs2_val,
    input  wire [31:0]           agu_imm,
    input  wire [2:0]            agu_funct3,
    input  wire                  agu_is_load,
    input  wire                  agu_is_store,
    input  wire                  agu_rs2_ready,

    // ================================================================
    // CDB OUTPUTS -> EX/WB -> ROB + PRF + IQ wakeup
    // ================================================================
    // ALU0
    output wire        alu0_valid_out,
    output wire [ROB_PTR_W-1:0] alu0_rob_idx,
    output wire [5:0]  alu0_phys_reg,
    output wire [31:0] alu0_result,

    // ALU1
    output wire        alu1_valid_out,
    output wire [ROB_PTR_W-1:0] alu1_rob_idx,
    output wire [5:0]  alu1_phys_reg,
    output wire [31:0] alu1_result,

    // ALU2
    output wire        alu2_valid_out,
    output wire [ROB_PTR_W-1:0] alu2_rob_idx,
    output wire [5:0]  alu2_phys_reg,
    output wire [31:0] alu2_result,

    // ALU3
    output wire        alu3_valid_out,
    output wire [ROB_PTR_W-1:0] alu3_rob_idx,
    output wire [5:0]  alu3_phys_reg,
    output wire [31:0] alu3_result,

    // BPU
    output wire        bpu_valid_out,
    output wire [ROB_PTR_W-1:0] bpu_rob_idx,
    output wire [5:0]  bpu_phys_reg,
    output wire [31:0] bpu_result,
    output wire        bpu_mispredict,
    output wire [31:0] bpu_correct_pc,

    // AGU -> LSQ writeback
    output wire        agu_wb_valid,
    output wire [LSQ_PTR_W-1:0] agu_wb_lsq_idx,
    output wire [31:0] agu_wb_addr,
    output wire [31:0] agu_wb_store_data,
    output wire        agu_wb_data_valid,

    // ================================================================
    // READY SIGNALS -> IQ/EX buffer & issue_top
    // All combinational units are always ready
    // ================================================================
    output wire        fu0_ready,
    output wire        fu1_ready,
    output wire        fu2_ready,
    output wire        fu3_ready,
    output wire        bpu_ready,
    output wire        agu_ready
);

    // ================================================================
    // READY - combinational units are always ready
    // ================================================================
    assign fu0_ready = 1'b1;
    assign fu1_ready = 1'b1;
    assign fu2_ready = 1'b1;
    assign fu3_ready = 1'b1;
    assign bpu_ready = 1'b1;
    assign agu_ready = 1'b1;

    // ================================================================
    // ALU0
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu0 (
        .valid_in    (fu0_valid_in),
        .opcode      (fu0_opcode),
        .funct3      (fu0_funct3),
        .funct7      (fu0_funct7),
        .rs1_val     (fu0_rs1_val),
        .rs2_val     (fu0_rs2_val),
        .imm         (fu0_imm),
        .seq_num     (fu0_seq_num),
        .phys_rd     (fu0_phys_rd),
        .pc          (fu0_pc),
        .valid_out   (alu0_valid_out),
        .rob_idx_out (alu0_rob_idx),
        .phys_reg_out(alu0_phys_reg),
        .result_out  (alu0_result)
    );

    // ================================================================
    // ALU1
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu1 (
        .valid_in    (fu1_valid_in),
        .opcode      (fu1_opcode),
        .funct3      (fu1_funct3),
        .funct7      (fu1_funct7),
        .rs1_val     (fu1_rs1_val),
        .rs2_val     (fu1_rs2_val),
        .imm         (fu1_imm),
        .seq_num     (fu1_seq_num),
        .phys_rd     (fu1_phys_rd),
        .pc          (fu1_pc),
        .valid_out   (alu1_valid_out),
        .rob_idx_out (alu1_rob_idx),
        .phys_reg_out(alu1_phys_reg),
        .result_out  (alu1_result)
    );

    // ================================================================
    // ALU2
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu2 (
        .valid_in    (fu2_valid_in),
        .opcode      (fu2_opcode),
        .funct3      (fu2_funct3),
        .funct7      (fu2_funct7),
        .rs1_val     (fu2_rs1_val),
        .rs2_val     (fu2_rs2_val),
        .imm         (fu2_imm),
        .seq_num     (fu2_seq_num),
        .phys_rd     (fu2_phys_rd),
        .pc          (fu2_pc),
        .valid_out   (alu2_valid_out),
        .rob_idx_out (alu2_rob_idx),
        .phys_reg_out(alu2_phys_reg),
        .result_out  (alu2_result)
    );

    // ================================================================
    // ALU3
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu3 (
        .valid_in    (fu3_valid_in),
        .opcode      (fu3_opcode),
        .funct3      (fu3_funct3),
        .funct7      (fu3_funct7),
        .rs1_val     (fu3_rs1_val),
        .rs2_val     (fu3_rs2_val),
        .imm         (fu3_imm),
        .seq_num     (fu3_seq_num),
        .phys_rd     (fu3_phys_rd),
        .pc          (fu3_pc),
        .valid_out   (alu3_valid_out),
        .rob_idx_out (alu3_rob_idx),
        .phys_reg_out(alu3_phys_reg),
        .result_out  (alu3_result)
    );

    // ================================================================
    // BPU
    // ================================================================
    BPU #(.ROB_PTR_W(ROB_PTR_W)) u_bpu (
        .valid_in      (bpu_valid_in),
        .opcode        (bpu_opcode),
        .funct3        (bpu_funct3),
        .rs1_val       (bpu_rs1_val),
        .rs2_val       (bpu_rs2_val),
        .imm           (bpu_imm),
        .seq_num       (bpu_seq_num),
        .phys_rd       (bpu_phys_rd),
        .pc            (bpu_pc),
        .valid_out     (bpu_valid_out),
        .rob_idx_out   (bpu_rob_idx),
        .phys_reg_out  (bpu_phys_reg),
        .result_out    (bpu_result),
        .mispredict_out(bpu_mispredict),
        .correct_pc_out(bpu_correct_pc)
    );

    // ================================================================
    // AGU
    // ================================================================
    AGU #(.LSQ_PTR_W(LSQ_PTR_W)) u_agu (
        .valid_in        (agu_valid_in),
        .lsq_idx_in      (agu_lsq_idx),
        .rs1_val         (agu_rs1_val),
        .rs2_val         (agu_rs2_val),
        .rs2_ready       (agu_rs2_ready),
        .imm             (agu_imm),
        .funct3          (agu_funct3),
        .is_load         (agu_is_load),
        .is_store        (agu_is_store),
        .agu_wb_valid    (agu_wb_valid),
        .agu_wb_lsq_idx  (agu_wb_lsq_idx),
        .agu_wb_addr     (agu_wb_addr),
        .agu_wb_store_data(agu_wb_store_data),
        .agu_wb_data_valid(agu_wb_data_valid)
    );

endmodule*/
module Execute_Top #(
    parameter ROB_PTR_W = 6,
    parameter LSQ_PTR_W = 5
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    // ================================================================
    // FROM IQ/EX BUFFER - FU0
    // ================================================================
    input  wire        fu0_valid_in,
    input  wire [7:0]  fu0_seq_num,
    input  wire [6:0]  fu0_opcode,
    input  wire [2:0]  fu0_funct3,
    input  wire [6:0]  fu0_funct7,
    input  wire [31:0] fu0_imm,
    input  wire [5:0]  fu0_phys_rd,
    input  wire [31:0] fu0_rs1_val,
    input  wire [31:0] fu0_rs2_val,
    input  wire [31:0] fu0_pc,

    // FU1
    input  wire        fu1_valid_in,
    input  wire [7:0]  fu1_seq_num,
    input  wire [6:0]  fu1_opcode,
    input  wire [2:0]  fu1_funct3,
    input  wire [6:0]  fu1_funct7,
    input  wire [31:0] fu1_imm,
    input  wire [5:0]  fu1_phys_rd,
    input  wire [31:0] fu1_rs1_val,
    input  wire [31:0] fu1_rs2_val,
    input  wire [31:0] fu1_pc,

    // FU2
    input  wire        fu2_valid_in,
    input  wire [7:0]  fu2_seq_num,
    input  wire [6:0]  fu2_opcode,
    input  wire [2:0]  fu2_funct3,
    input  wire [6:0]  fu2_funct7,
    input  wire [31:0] fu2_imm,
    input  wire [5:0]  fu2_phys_rd,
    input  wire [31:0] fu2_rs1_val,
    input  wire [31:0] fu2_rs2_val,
    input  wire [31:0] fu2_pc,

    // FU3
    input  wire        fu3_valid_in,
    input  wire [7:0]  fu3_seq_num,
    input  wire [6:0]  fu3_opcode,
    input  wire [2:0]  fu3_funct3,
    input  wire [6:0]  fu3_funct7,
    input  wire [31:0] fu3_imm,
    input  wire [5:0]  fu3_phys_rd,
    input  wire [31:0] fu3_rs1_val,
    input  wire [31:0] fu3_rs2_val,
    input  wire [31:0] fu3_pc,

    // BPU
    input  wire        bpu_valid_in,
    input  wire [7:0]  bpu_seq_num,
    input  wire [6:0]  bpu_opcode,
    input  wire [2:0]  bpu_funct3,
    input  wire [31:0] bpu_imm,
    input  wire [5:0]  bpu_phys_rd,
    input  wire [31:0] bpu_rs1_val,
    input  wire [31:0] bpu_rs2_val,
    input  wire [31:0] bpu_pc,

    // AGU
    input  wire                  agu_valid_in,
    input  wire [LSQ_PTR_W-1:0]  agu_lsq_idx,
    input  wire [31:0]           agu_rs1_val,
    input  wire [31:0]           agu_rs2_val,
    input  wire [31:0]           agu_imm,
    input  wire [2:0]            agu_funct3,
    input  wire                  agu_is_load,
    input  wire                  agu_is_store,
    input  wire                  agu_rs2_ready,

    // ================================================================
    // CDB OUTPUTS -> EX/WB -> ROB + PRF + IQ wakeup
    // ================================================================
    // ALU0
    output wire        alu0_valid_out,
    output wire [ROB_PTR_W-1:0] alu0_rob_idx,
    output wire [5:0]  alu0_phys_reg,
    output wire [31:0] alu0_result,

    // ALU1
    output wire        alu1_valid_out,
    output wire [ROB_PTR_W-1:0] alu1_rob_idx,
    output wire [5:0]  alu1_phys_reg,
    output wire [31:0] alu1_result,

    // ALU2
    output wire        alu2_valid_out,
    output wire [ROB_PTR_W-1:0] alu2_rob_idx,
    output wire [5:0]  alu2_phys_reg,
    output wire [31:0] alu2_result,

    // ALU3
    output wire        alu3_valid_out,
    output wire [ROB_PTR_W-1:0] alu3_rob_idx,
    output wire [5:0]  alu3_phys_reg,
    output wire [31:0] alu3_result,

    // BPU
    output wire        bpu_valid_out,
    output wire [ROB_PTR_W-1:0] bpu_rob_idx,
    output wire [5:0]  bpu_phys_reg,
    output wire [31:0] bpu_result,
    output wire        bpu_mispredict,
    output wire [31:0] bpu_correct_pc,

    // AGU -> LSQ writeback
    output wire        agu_wb_valid,
    output wire [LSQ_PTR_W-1:0] agu_wb_lsq_idx,
    output wire [31:0] agu_wb_addr,
    output wire [31:0] agu_wb_store_data,
    output wire        agu_wb_data_valid,

    // ================================================================
    // READY SIGNALS -> IQ/EX buffer & issue_top
    // All combinational units are always ready
    // ================================================================
    output wire        fu0_ready,
    output wire        fu1_ready,
    output wire        fu2_ready,
    output wire        fu3_ready,
    output wire        bpu_ready,
    output wire        agu_ready,
    output wire        mul_ready,

    // ================================================================
    // FROM IQ/EX BUFFER - MUL
    // ================================================================
    input  wire        mul_valid_in,
    input  wire [7:0]  mul_seq_num,
    input  wire [2:0]  mul_funct3,
    input  wire [5:0]  mul_phys_rd,
    input  wire [31:0] mul_rs1_val,
    input  wire [31:0] mul_rs2_val,

    // MUL -> EX/WB buffer
    output wire        mul_valid_out,
    output wire [ROB_PTR_W-1:0] mul_rob_idx,
    output wire [5:0]  mul_phys_reg,
    output wire [31:0] mul_result
);

    // ================================================================
    // READY - combinational units are always ready
    // ================================================================
    assign fu0_ready = 1'b1;
    assign fu1_ready = 1'b1;
    assign fu2_ready = 1'b1;
    assign fu3_ready = 1'b1;
    assign bpu_ready = 1'b1;
    assign agu_ready = 1'b1;

    // ================================================================
    // ALU0
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu0 (
        .valid_in    (fu0_valid_in),
        .opcode      (fu0_opcode),
        .funct3      (fu0_funct3),
        .funct7      (fu0_funct7),
        .rs1_val     (fu0_rs1_val),
        .rs2_val     (fu0_rs2_val),
        .imm         (fu0_imm),
        .seq_num     (fu0_seq_num),
        .phys_rd     (fu0_phys_rd),
        .pc          (fu0_pc),
        .valid_out   (alu0_valid_out),
        .rob_idx_out (alu0_rob_idx),
        .phys_reg_out(alu0_phys_reg),
        .result_out  (alu0_result)
    );

    // ================================================================
    // ALU1
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu1 (
        .valid_in    (fu1_valid_in),
        .opcode      (fu1_opcode),
        .funct3      (fu1_funct3),
        .funct7      (fu1_funct7),
        .rs1_val     (fu1_rs1_val),
        .rs2_val     (fu1_rs2_val),
        .imm         (fu1_imm),
        .seq_num     (fu1_seq_num),
        .phys_rd     (fu1_phys_rd),
        .pc          (fu1_pc),
        .valid_out   (alu1_valid_out),
        .rob_idx_out (alu1_rob_idx),
        .phys_reg_out(alu1_phys_reg),
        .result_out  (alu1_result)
    );

    // ================================================================
    // ALU2
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu2 (
        .valid_in    (fu2_valid_in),
        .opcode      (fu2_opcode),
        .funct3      (fu2_funct3),
        .funct7      (fu2_funct7),
        .rs1_val     (fu2_rs1_val),
        .rs2_val     (fu2_rs2_val),
        .imm         (fu2_imm),
        .seq_num     (fu2_seq_num),
        .phys_rd     (fu2_phys_rd),
        .pc          (fu2_pc),
        .valid_out   (alu2_valid_out),
        .rob_idx_out (alu2_rob_idx),
        .phys_reg_out(alu2_phys_reg),
        .result_out  (alu2_result)
    );

    // ================================================================
    // ALU3
    // ================================================================
    ALU #(.ROB_PTR_W(ROB_PTR_W)) u_alu3 (
        .valid_in    (fu3_valid_in),
        .opcode      (fu3_opcode),
        .funct3      (fu3_funct3),
        .funct7      (fu3_funct7),
        .rs1_val     (fu3_rs1_val),
        .rs2_val     (fu3_rs2_val),
        .imm         (fu3_imm),
        .seq_num     (fu3_seq_num),
        .phys_rd     (fu3_phys_rd),
        .pc          (fu3_pc),
        .valid_out   (alu3_valid_out),
        .rob_idx_out (alu3_rob_idx),
        .phys_reg_out(alu3_phys_reg),
        .result_out  (alu3_result)
    );

    // ================================================================
    // BPU
    // ================================================================
    BPU #(.ROB_PTR_W(ROB_PTR_W)) u_bpu (
        .valid_in      (bpu_valid_in),
        .opcode        (bpu_opcode),
        .funct3        (bpu_funct3),
        .rs1_val       (bpu_rs1_val),
        .rs2_val       (bpu_rs2_val),
        .imm           (bpu_imm),
        .seq_num       (bpu_seq_num),
        .phys_rd       (bpu_phys_rd),
        .pc            (bpu_pc),
        .valid_out     (bpu_valid_out),
        .rob_idx_out   (bpu_rob_idx),
        .phys_reg_out  (bpu_phys_reg),
        .result_out    (bpu_result),
        .mispredict_out(bpu_mispredict),
        .correct_pc_out(bpu_correct_pc)
    );

    // ================================================================
    // AGU
    // ================================================================
    AGU #(.LSQ_PTR_W(LSQ_PTR_W)) u_agu (
        .valid_in        (agu_valid_in),
        .lsq_idx_in      (agu_lsq_idx),
        .rs1_val         (agu_rs1_val),
        .rs2_val         (agu_rs2_val),
        .rs2_ready       (agu_rs2_ready),
        .imm             (agu_imm),
        .funct3          (agu_funct3),
        .is_load         (agu_is_load),
        .is_store        (agu_is_store),
        .agu_wb_valid    (agu_wb_valid),
        .agu_wb_lsq_idx  (agu_wb_lsq_idx),
        .agu_wb_addr     (agu_wb_addr),
        .agu_wb_store_data(agu_wb_store_data),
        .agu_wb_data_valid(agu_wb_data_valid)
    );

    // ================================================================
    // PIPELINED MULTIPLIER (3-cycle latency)
    // ================================================================
    pipelined_multiplier #(.ROB_PTR_W(ROB_PTR_W)) u_mul (
        .clk         (clk),
        .rst         (rst),
        .flush       (flush),
        .valid_in    (mul_valid_in),
        .seq_num_in  (mul_seq_num),
        .funct3_in   (mul_funct3),
        .phys_rd_in  (mul_phys_rd),
        .rs1_val     (mul_rs1_val),
        .rs2_val     (mul_rs2_val),
        .valid_out   (mul_valid_out),
        .rob_idx_out (mul_rob_idx),
        .phys_reg_out(mul_phys_reg),
        .result_out  (mul_result),
        .ready       (mul_ready)
    );

endmodule

