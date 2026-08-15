/*module issue_top #(
    parameter ROB_DEPTH  = 64,
    parameter ROB_PTR_W  = 6,
    parameter LSQ_DEPTH  = 32,
    parameter LSQ_PTR_W  = 5,
    parameter AQ_DEPTH   = 16,
    parameter AQ_PTR_W   = 4,
    parameter MEM_DEPTH  = 256,
    parameter INIT_FILE  = ""
)(
    input  wire clk,
    input  wire rst,

    // ================================================================
    // DISPATCH INPUT (from Stage 2 Decode/Rename)
    // ================================================================
    input  wire [3:0]   dispatch_valid,
    input  wire [3:0]   dispatch_is_alu,
    input  wire [3:0]   dispatch_is_load,
    input  wire [3:0]   dispatch_is_store,
    input  wire [3:0]   dispatch_is_branch,
    input  wire [3:0]   dispatch_is_jal,
    input  wire [3:0]   dispatch_is_jalr,
    input  wire [3:0]   dispatch_is_lui,
    input  wire [3:0]   dispatch_is_auipc,

    input  wire [23:0]  dispatch_phys_rs1,
    input  wire [23:0]  dispatch_phys_rs2,
    input  wire [23:0]  dispatch_phys_rd,
    input  wire [23:0]  dispatch_old_phys_rd,
    input  wire [19:0]  dispatch_arch_rd,
    input  wire [3:0]   dispatch_rd_valid,
    input  wire [3:0]   dispatch_rs1_valid,
    input  wire [3:0]   dispatch_rs2_valid,

    input  wire [27:0]  dispatch_opcode,
    input  wire [11:0]  dispatch_funct3,
    input  wire [27:0]  dispatch_funct7,
    input  wire [127:0] dispatch_imm,

    input  wire [31:0]  dispatch_pc0,
    input  wire [31:0]  dispatch_pc1,
    input  wire [31:0]  dispatch_pc2,
    input  wire [31:0]  dispatch_pc3,

    // ================================================================
    // CDB INPUTS (from Stage 4 Execute)
    // ================================================================
    input  wire         cdb_fu0_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu0_rob_idx,
    input  wire [5:0]   cdb_fu0_phys_reg,
    input  wire [31:0]  cdb_fu0_result,

    input  wire         cdb_fu1_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu1_rob_idx,
    input  wire [5:0]   cdb_fu1_phys_reg,
    input  wire [31:0]  cdb_fu1_result,

    input  wire         cdb_fu2_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu2_rob_idx,
    input  wire [5:0]   cdb_fu2_phys_reg,
    input  wire [31:0]  cdb_fu2_result,

    input  wire         cdb_fu3_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu3_rob_idx,
    input  wire [5:0]   cdb_fu3_phys_reg,
    input  wire [31:0]  cdb_fu3_result,

    input  wire         cdb_bpu_valid,
    input  wire [ROB_PTR_W-1:0] cdb_bpu_rob_idx,
    input  wire [5:0]   cdb_bpu_phys_reg,
    input  wire [31:0]  cdb_bpu_result,
    input  wire         cdb_bpu_mispredict,
    input  wire [31:0]  cdb_bpu_correct_pc,

    // ================================================================
    // AGU WRITEBACK (from Stage 4 AGU -> back to LSQ)
    // ================================================================
    input  wire         agu_wb_valid,
    input  wire [LSQ_PTR_W-1:0] agu_wb_lsq_idx,
    input  wire [31:0]  agu_wb_addr,
    input  wire [31:0]  agu_wb_store_data,
    input  wire         agu_wb_data_valid,

    // ================================================================
    // BUFFER / PIPELINE CONTROLS
    // ================================================================
    input  wire         aq_buf_accept,
    input  wire         agu_ready,

    input  wire         fu0_ready,
    input  wire         fu1_ready,
    input  wire         fu2_ready,
    input  wire         fu3_ready,
    input  wire         bpu_ready,

    // ================================================================
    // BACK-PRESSURE OUTPUTS (to Stage 2)
    // ================================================================
    output wire         rob_full,
    output wire         iq_full,
    output wire         lsq_full,

    // ================================================================
    // ISSUE OUTPUTS (to Stage 3/4 Buffer)
    // ================================================================
    // BPU
    output wire         bpu_valid,
    output wire [7:0]   bpu_seq_num,
    output wire [6:0]   bpu_opcode,
    output wire [2:0]   bpu_funct3,
    output wire [31:0]  bpu_imm,
    output wire [5:0]   bpu_phys_rs1,
    output wire [5:0]   bpu_phys_rs2,
    output wire [5:0]   bpu_phys_rd,
    output wire [31:0]  bpu_rs1_val,
    output wire [31:0]  bpu_rs2_val,

    // FU0
    output wire         fu0_valid,
    output wire [7:0]   fu0_seq_num,
    output wire [6:0]   fu0_opcode,
    output wire [2:0]   fu0_funct3,
    output wire [6:0]   fu0_funct7,
    output wire [31:0]  fu0_imm,
    output wire [5:0]   fu0_phys_rs1,
    output wire [5:0]   fu0_phys_rs2,
    output wire [5:0]   fu0_phys_rd,
    output wire [31:0]  fu0_rs1_val,
    output wire [31:0]  fu0_rs2_val,

    // FU1
    output wire         fu1_valid,
    output wire [7:0]   fu1_seq_num,
    output wire [6:0]   fu1_opcode,
    output wire [2:0]   fu1_funct3,
    output wire [6:0]   fu1_funct7,
    output wire [31:0]  fu1_imm,
    output wire [5:0]   fu1_phys_rs1,
    output wire [5:0]   fu1_phys_rs2,
    output wire [5:0]   fu1_phys_rd,
    output wire [31:0]  fu1_rs1_val,
    output wire [31:0]  fu1_rs2_val,

    // FU2
    output wire         fu2_valid,
    output wire [7:0]   fu2_seq_num,
    output wire [6:0]   fu2_opcode,
    output wire [2:0]   fu2_funct3,
    output wire [6:0]   fu2_funct7,
    output wire [31:0]  fu2_imm,
    output wire [5:0]   fu2_phys_rs1,
    output wire [5:0]   fu2_phys_rs2,
    output wire [5:0]   fu2_phys_rd,
    output wire [31:0]  fu2_rs1_val,
    output wire [31:0]  fu2_rs2_val,

    // FU3
    output wire         fu3_valid,
    output wire [7:0]   fu3_seq_num,
    output wire [6:0]   fu3_opcode,
    output wire [2:0]   fu3_funct3,
    output wire [6:0]   fu3_funct7,
    output wire [31:0]  fu3_imm,
    output wire [5:0]   fu3_phys_rs1,
    output wire [5:0]   fu3_phys_rs2,
    output wire [5:0]   fu3_phys_rd,
    output wire [31:0]  fu3_rs1_val,
    output wire [31:0]  fu3_rs2_val,

    // AGU IQ Tracking
    output wire         agu_valid,
    output wire [7:0]   agu_seq_num,
    output wire [6:0]   agu_opcode,
    output wire [2:0]   agu_funct3,
    output wire [31:0]  agu_imm,
    output wire [5:0]   agu_phys_rs1,
    output wire [5:0]   agu_phys_rs2,
    output wire [5:0]   agu_phys_rd,
    output wire         agu_is_load,
    output wire         agu_is_store,

    // AGU Actual Execution Data (from LSQ's Address Queue)
    output wire                 aq_valid,
    output wire [4:0]           aq_lsq_idx,
    output wire [31:0]          aq_rs1_val,
    output wire [31:0]          aq_rs2_val,
    output wire [31:0]          aq_imm_out,
    output wire [2:0]           aq_funct3_out,
    output wire                 aq_is_load_out,
    output wire                 aq_is_store_out,

    // ================================================================
    // FLUSH OUTPUTS (to Stage 1 & 2)
    // ================================================================
    output wire         flush,
    output wire [7:0]   flush_seq_num,
    output wire [31:0]  flush_correct_pc,

    // ================================================================
    // FREELIST OUTPUTS (to Stage 2 Freelist, 4-wide)
    // ================================================================
    output wire [3:0]   commit_free_valid,
    output wire [23:0]  commit_old_phys_rd,
    output wire [3:0]   flush_free_valid,
    output wire [23:0]  flush_free_phys_rd,

    // ================================================================
    // RAT / RRAT OUTPUTS (to Stage 2 RAT, 4-wide)
    // ================================================================
    output wire [3:0]   commit_valid,
    output wire [19:0]  commit_arch_rd,
    output wire [23:0]  commit_phys_rd,
    output wire [127:0] commit_result,
    output wire [3:0]   commit_rd_valid,

    // ================================================================
    // PC PASSTHROUGHS
    // ================================================================
    output wire [31:0]  fu0_pc,
    output wire [31:0]  fu1_pc,
    output wire [31:0]  fu2_pc,
    output wire [31:0]  fu3_pc,
    output wire [31:0]  bpu_pc,

    // Store data readiness indicator
    output wire         aq_rs2_ready,

    // ================================================================
    // DEBUG OUTPUTS
    // ================================================================
    output wire [ROB_PTR_W-1:0] dbg_rob_head,
    output wire [ROB_PTR_W-1:0] dbg_rob_tail,
    output wire [ROB_PTR_W:0]   dbg_rob_count,
    output wire [LSQ_PTR_W-1:0] dbg_lsq_head,
    output wire [LSQ_PTR_W-1:0] dbg_lsq_tail,
    output wire [LSQ_PTR_W:0]   dbg_lsq_count,
    output wire [1023:0]        dbg_arf_regfile,
    output wire [191:0]         dbg_arf_rat,
    output wire [4:0]           dbg_rd_addr0,
    output wire [31:0]          dbg_rd_data0,
    output wire [4:0]           dbg_rd_addr1,
    output wire [31:0]          dbg_rd_data1,

    // Shadow RAT for flush recovery
    output wire [191:0]         arch_to_phys_flush
);

    // ================================================================
    // INTERNAL WIRES
    // ================================================================
    wire [ROB_PTR_W-1:0] w_rob_idx0, w_rob_idx1, w_rob_idx2, w_rob_idx3;

    wire [3:0]   w_commit_valid;
    wire [19:0]  w_commit_arch_rd;
    wire [23:0]  w_commit_phys_rd;
    wire [127:0] w_commit_result;
    wire [3:0]   w_commit_rd_valid;

    wire [3:0]   w_commit_free_valid;
    wire [23:0]  w_commit_old_phys_rd;
    wire [3:0]  w_flush_free_valid;
    wire [23:0] w_flush_free_phys_rd;

    wire [3:0]   w_commit_store_valid;
    wire [4*ROB_PTR_W-1:0] w_commit_store_rob_idx;
    wire        w_store_done_valid;
    wire [ROB_PTR_W-1:0] w_store_done_rob_idx;

    wire [5:0] w_bpu_phys_rs1, w_bpu_phys_rs2;
    wire [5:0] w_aq_phys_rs1, w_aq_phys_rs2;

    wire        w_mem_req_valid;
    wire        w_mem_req_we;
    wire [31:0] w_mem_req_addr;
    wire [31:0] w_mem_req_wdata;
    wire [1:0]  w_mem_req_size;
    wire [LSQ_PTR_W-1:0] w_mem_req_lsq_idx;
    wire        w_mem_req_ready;

    wire        w_mem_resp_valid;
    wire [31:0] w_mem_resp_data;
    wire [LSQ_PTR_W-1:0] w_mem_resp_lsq_idx;

    wire        w_lsq_cdb_valid;
    wire [7:0]  w_lsq_cdb_tag;
    wire [5:0]  w_lsq_cdb_phys_reg;
    wire [31:0] w_lsq_cdb_result;

    wire [191:0] w_arch_to_phys;

    // ================================================================
    // EXPORT OUTPUTS
    // ================================================================
    assign commit_free_valid  = w_commit_free_valid;
    assign commit_old_phys_rd = w_commit_old_phys_rd;
    assign flush_free_valid   = w_flush_free_valid;
    assign flush_free_phys_rd = w_flush_free_phys_rd;

    assign commit_valid    = w_commit_valid;
    assign commit_arch_rd  = w_commit_arch_rd;
    assign commit_phys_rd  = w_commit_phys_rd;
    assign commit_result   = w_commit_result;
    assign commit_rd_valid = w_commit_rd_valid;

    assign bpu_phys_rs1 = w_bpu_phys_rs1;
    assign bpu_phys_rs2 = w_bpu_phys_rs2;

    // ================================================================
    // ROB
    // ================================================================
    ROB #(
        .ROB_DEPTH (ROB_DEPTH),
        .ROB_PTR_W (ROB_PTR_W),
        .LSQ_PTR_W (LSQ_PTR_W)
    ) u_rob (
        .clk                  (clk),
        .rst                  (rst),
        .dispatch_valid       (dispatch_valid),
        .dispatch_is_alu      (dispatch_is_alu),
        .dispatch_is_load     (dispatch_is_load),
        .dispatch_is_store    (dispatch_is_store),
        .dispatch_is_branch   (dispatch_is_branch),
        .dispatch_is_jal      (dispatch_is_jal),
        .dispatch_is_jalr     (dispatch_is_jalr),
        .dispatch_phys_rd     (dispatch_phys_rd),
        .dispatch_old_phys_rd (dispatch_old_phys_rd),
        .dispatch_rd_valid    (dispatch_rd_valid),
        .dispatch_pc0         (dispatch_pc0),
        .dispatch_pc1         (dispatch_pc1),
        .dispatch_pc2         (dispatch_pc2),
        .dispatch_pc3         (dispatch_pc3),
        .dispatch_arch_rd     (dispatch_arch_rd),

        .rob_idx_out0         (w_rob_idx0),
        .rob_idx_out1         (w_rob_idx1),
        .rob_idx_out2         (w_rob_idx2),
        .rob_idx_out3         (w_rob_idx3),
        .rob_full             (rob_full),

        .cdb_fu0_valid        (cdb_fu0_valid),
        .cdb_fu0_rob_idx      (cdb_fu0_rob_idx),
        .cdb_fu0_result       (cdb_fu0_result),
        .cdb_fu1_valid        (cdb_fu1_valid),
        .cdb_fu1_rob_idx      (cdb_fu1_rob_idx),
        .cdb_fu1_result       (cdb_fu1_result),
        .cdb_fu2_valid        (cdb_fu2_valid),
        .cdb_fu2_rob_idx      (cdb_fu2_rob_idx),
        .cdb_fu2_result       (cdb_fu2_result),
        .cdb_fu3_valid        (cdb_fu3_valid),
        .cdb_fu3_rob_idx      (cdb_fu3_rob_idx),
        .cdb_fu3_result       (cdb_fu3_result),
        .cdb_bpu_valid        (cdb_bpu_valid),
        .cdb_bpu_rob_idx      (cdb_bpu_rob_idx),
        .cdb_bpu_result       (cdb_bpu_result),
        .cdb_bpu_mispredict   (cdb_bpu_mispredict),
        .cdb_bpu_correct_pc   (cdb_bpu_correct_pc),
        .cdb_lsq_valid        (w_lsq_cdb_valid),
        .cdb_lsq_rob_idx      (w_lsq_cdb_tag[ROB_PTR_W-1:0]),
        .cdb_lsq_result       (w_lsq_cdb_result),

        .store_done_valid     (w_store_done_valid),
        .store_done_rob_idx   (w_store_done_rob_idx),
        .commit_store_valid   (w_commit_store_valid),
        .commit_store_rob_idx (w_commit_store_rob_idx),

        .commit_valid         (w_commit_valid),
        .commit_arch_rd       (w_commit_arch_rd),
        .commit_phys_rd       (w_commit_phys_rd),
        .commit_result        (w_commit_result),
        .commit_rd_valid      (w_commit_rd_valid),
        .commit_free_valid    (w_commit_free_valid),
        .commit_old_phys_rd   (w_commit_old_phys_rd),

        .flush                (flush),
        .flush_seq_num        (flush_seq_num),
        .flush_correct_pc     (flush_correct_pc),
        .flush_free_valid     (w_flush_free_valid),
        .flush_free_phys_rd   (w_flush_free_phys_rd),

        .dbg_head             (dbg_rob_head),
        .dbg_tail             (dbg_rob_tail),
        .dbg_count            (dbg_rob_count)
    );

    // ================================================================
    // ISSUE QUEUE
    // ================================================================
    Issue_Queue u_iq (
        .clk            (clk),
        .rst            (rst),
        .flush          (flush),
        .valid_in       (dispatch_valid),
        .phys_rs1_in    (dispatch_phys_rs1),
        .phys_rs2_in    (dispatch_phys_rs2),
        .phys_rd_in     (dispatch_phys_rd),
        .opcode_in      (dispatch_opcode),
        .funct3_in      (dispatch_funct3),
        .funct7_in      (dispatch_funct7),
        .imm_in         (dispatch_imm),
        .rs1_valid_in   (dispatch_rs1_valid),
        .rs2_valid_in   (dispatch_rs2_valid),
        .rd_valid_in    (dispatch_rd_valid),
        .is_alu_in      (dispatch_is_alu),
        .is_load_in     (dispatch_is_load),
        .is_store_in    (dispatch_is_store),
        .is_branch_in   (dispatch_is_branch),
        .is_jal_in      (dispatch_is_jal),
        .is_jalr_in     (dispatch_is_jalr),
        .is_lui_in      (dispatch_is_lui),
        .is_auipc_in    (dispatch_is_auipc),
        .rob_idx_in0    ({2'b0, w_rob_idx0}),
        .rob_idx_in1    ({2'b0, w_rob_idx1}),
        .rob_idx_in2    ({2'b0, w_rob_idx2}),
        .rob_idx_in3    ({2'b0, w_rob_idx3}),
        .pc_in0         (dispatch_pc0),
        .pc_in1         (dispatch_pc1),
        .pc_in2         (dispatch_pc2),
        .pc_in3         (dispatch_pc3),
        .iq_full        (iq_full),

        .bpu_valid      (bpu_valid),
        .bpu_seq_num    (bpu_seq_num),
        .bpu_opcode     (bpu_opcode),
        .bpu_funct3     (bpu_funct3),
        .bpu_imm        (bpu_imm),
        .bpu_phys_rs1   (w_bpu_phys_rs1),
        .bpu_phys_rs2   (w_bpu_phys_rs2),
        .bpu_phys_rd    (bpu_phys_rd),
        .bpu_ready      (bpu_ready),
        .fu0_valid      (fu0_valid),
        .fu0_seq_num    (fu0_seq_num),
        .fu0_opcode     (fu0_opcode),
        .fu0_funct3     (fu0_funct3),
        .fu0_funct7     (fu0_funct7),
        .fu0_imm        (fu0_imm),
        .fu0_phys_rs1   (fu0_phys_rs1),
        .fu0_phys_rs2   (fu0_phys_rs2),
        .fu0_phys_rd    (fu0_phys_rd),
        .fu0_ready      (fu0_ready),
        .fu1_valid      (fu1_valid),
        .fu1_seq_num    (fu1_seq_num),
        .fu1_opcode     (fu1_opcode),
        .fu1_funct3     (fu1_funct3),
        .fu1_funct7     (fu1_funct7),
        .fu1_imm        (fu1_imm),
        .fu1_phys_rs1   (fu1_phys_rs1),
        .fu1_phys_rs2   (fu1_phys_rs2),
        .fu1_phys_rd    (fu1_phys_rd),
        .fu1_ready      (fu1_ready),
        .fu2_valid      (fu2_valid),
        .fu2_seq_num    (fu2_seq_num),
        .fu2_opcode     (fu2_opcode),
        .fu2_funct3     (fu2_funct3),
        .fu2_funct7     (fu2_funct7),
        .fu2_imm        (fu2_imm),
        .fu2_phys_rs1   (fu2_phys_rs1),
        .fu2_phys_rs2   (fu2_phys_rs2),
        .fu2_phys_rd    (fu2_phys_rd),
        .fu2_ready      (fu2_ready),
        .fu3_valid      (fu3_valid),
        .fu3_seq_num    (fu3_seq_num),
        .fu3_opcode     (fu3_opcode),
        .fu3_funct3     (fu3_funct3),
        .fu3_funct7     (fu3_funct7),
        .fu3_imm        (fu3_imm),
        .fu3_phys_rs1   (fu3_phys_rs1),
        .fu3_phys_rs2   (fu3_phys_rs2),
        .fu3_phys_rd    (fu3_phys_rd),
        .fu3_ready      (fu3_ready),

        .agu_valid      (agu_valid),
        .agu_seq_num    (agu_seq_num),
        .agu_opcode     (agu_opcode),
        .agu_funct3     (agu_funct3),
        .agu_imm        (agu_imm),
        .agu_phys_rs1   (agu_phys_rs1),
        .agu_phys_rs2   (agu_phys_rs2),
        .agu_phys_rd    (agu_phys_rd),
        .agu_is_load    (agu_is_load),
        .agu_is_store   (agu_is_store),

        .fu0_pc         (fu0_pc),
        .fu1_pc         (fu1_pc),
        .fu2_pc         (fu2_pc),
        .fu3_pc         (fu3_pc),
        .bpu_pc         (bpu_pc),
        .agu_ready      (agu_ready),

        .cdb_fu0_valid    (cdb_fu0_valid),
        .cdb_fu0_tag      ({2'b0, cdb_fu0_rob_idx}),
        .cdb_fu0_phys_reg (cdb_fu0_phys_reg),
        .cdb_fu1_valid    (cdb_fu1_valid),
        .cdb_fu1_tag      ({2'b0, cdb_fu1_rob_idx}),
        .cdb_fu1_phys_reg (cdb_fu1_phys_reg),
        .cdb_fu2_valid    (cdb_fu2_valid),
        .cdb_fu2_tag      ({2'b0, cdb_fu2_rob_idx}),
        .cdb_fu2_phys_reg (cdb_fu2_phys_reg),
        .cdb_fu3_valid    (cdb_fu3_valid),
        .cdb_fu3_tag      ({2'b0, cdb_fu3_rob_idx}),
        .cdb_fu3_phys_reg (cdb_fu3_phys_reg),
        .cdb_bpu_valid    (cdb_bpu_valid),
        .cdb_bpu_tag      ({2'b0, cdb_bpu_rob_idx}),
        .cdb_bpu_phys_reg (cdb_bpu_phys_reg),
        .cdb_lsq_valid    (w_lsq_cdb_valid),
        .cdb_lsq_tag      (w_lsq_cdb_tag),
        .cdb_lsq_phys_reg (w_lsq_cdb_phys_reg)
    );

    // ================================================================
    // PRF
    // ================================================================
    PRF u_prf (
        .clk               (clk),
        .rst               (rst),
        .cdb_fu0_valid     (cdb_fu0_valid),
        .cdb_fu0_phys_reg  (cdb_fu0_phys_reg),
        .cdb_fu0_value     (cdb_fu0_result),
        .cdb_fu1_valid     (cdb_fu1_valid),
        .cdb_fu1_phys_reg  (cdb_fu1_phys_reg),
        .cdb_fu1_value     (cdb_fu1_result),
        .cdb_fu2_valid     (cdb_fu2_valid),
        .cdb_fu2_phys_reg  (cdb_fu2_phys_reg),
        .cdb_fu2_value     (cdb_fu2_result),
        .cdb_fu3_valid     (cdb_fu3_valid),
        .cdb_fu3_phys_reg  (cdb_fu3_phys_reg),
        .cdb_fu3_value     (cdb_fu3_result),
        .cdb_bpu_valid     (cdb_bpu_valid),
        .cdb_bpu_phys_reg  (cdb_bpu_phys_reg),
        .cdb_bpu_value     (cdb_bpu_result),
        .cdb_lsq_valid     (w_lsq_cdb_valid),
        .cdb_lsq_phys_reg  (w_lsq_cdb_phys_reg),
        .cdb_lsq_value     (w_lsq_cdb_result),

        .bpu_phys_rs1      (w_bpu_phys_rs1),
        .bpu_phys_rs2      (w_bpu_phys_rs2),
        .bpu_rs1_val       (bpu_rs1_val),
        .bpu_rs2_val       (bpu_rs2_val),
        .fu0_phys_rs1      (fu0_phys_rs1),
        .fu0_phys_rs2      (fu0_phys_rs2),
        .fu0_rs1_val       (fu0_rs1_val),
        .fu0_rs2_val       (fu0_rs2_val),
        .fu1_phys_rs1      (fu1_phys_rs1),
        .fu1_phys_rs2      (fu1_phys_rs2),
        .fu1_rs1_val       (fu1_rs1_val),
        .fu1_rs2_val       (fu1_rs2_val),
        .fu2_phys_rs1      (fu2_phys_rs1),
        .fu2_phys_rs2      (fu2_phys_rs2),
        .fu2_rs1_val       (fu2_rs1_val),
        .fu2_rs2_val       (fu2_rs2_val),
        .fu3_phys_rs1      (fu3_phys_rs1),
        .fu3_phys_rs2      (fu3_phys_rs2),
        .fu3_rs1_val       (fu3_rs1_val),
        .fu3_rs2_val       (fu3_rs2_val),

        .agu_phys_rs1      (w_aq_phys_rs1),
        .agu_phys_rs2      (w_aq_phys_rs2),
        .agu_rs1_val       (aq_rs1_val),
        .agu_rs2_val       (aq_rs2_val),
        .agu_rs2_ready     (aq_rs2_ready)
    );

    // ================================================================
    // LSQ
    // ================================================================
    LSQ #(
        .LSQ_DEPTH (LSQ_DEPTH),
        .AQ_DEPTH  (AQ_DEPTH),
        .LSQ_PTR_W (LSQ_PTR_W),
        .AQ_PTR_W  (AQ_PTR_W),
        .ROB_PTR_W (ROB_PTR_W)
    ) u_lsq (
        .clk                  (clk),
        .rst                  (rst),
        .flush                (flush),
        .flush_seq_num        (flush_seq_num),

        .dispatch_valid       (dispatch_valid),
        .dispatch_is_load     (dispatch_is_load),
        .dispatch_is_store    (dispatch_is_store),
        .dispatch_phys_rd     (dispatch_phys_rd),
        .dispatch_phys_rs1    (dispatch_phys_rs1),
        .dispatch_phys_rs2    (dispatch_phys_rs2),
        .dispatch_imm         (dispatch_imm),
        .dispatch_funct3      (dispatch_funct3),
        .rob_idx_in0          (w_rob_idx0),
        .rob_idx_in1          (w_rob_idx1),
        .rob_idx_in2          (w_rob_idx2),
        .rob_idx_in3          (w_rob_idx3),

        .lsq_full             (lsq_full),
        .aq_valid             (aq_valid),
        .aq_lsq_idx           (aq_lsq_idx),
        .aq_phys_rs1          (w_aq_phys_rs1),
        .aq_phys_rs2          (w_aq_phys_rs2),
        .aq_imm               (aq_imm_out),
        .aq_funct3            (aq_funct3_out),
        .aq_is_load           (aq_is_load_out),
        .aq_is_store          (aq_is_store_out),
        .agu_pop              (aq_buf_accept),

        .agu_wb_valid         (agu_wb_valid),
        .agu_wb_lsq_idx      (agu_wb_lsq_idx),
        .agu_wb_addr          (agu_wb_addr),
        .agu_wb_store_data    (agu_wb_store_data),
        .agu_wb_data_valid    (agu_wb_data_valid),

        // LSQ only retires 1 store/cycle. ROB guarantees at most 1 store in commit window.
        .store_commit_valid   (|w_commit_store_valid),
        .store_commit_rob_idx (w_commit_store_valid[0] ? w_commit_store_rob_idx[ROB_PTR_W-1:0] :
                               w_commit_store_valid[1] ? w_commit_store_rob_idx[2*ROB_PTR_W-1:ROB_PTR_W] :
                               w_commit_store_valid[2] ? w_commit_store_rob_idx[3*ROB_PTR_W-1:2*ROB_PTR_W] :
                                                         w_commit_store_rob_idx[4*ROB_PTR_W-1:3*ROB_PTR_W]),
        .store_done_valid     (w_store_done_valid),
        .store_done_rob_idx   (w_store_done_rob_idx),

        .mem_req_valid        (w_mem_req_valid),
        .mem_req_we           (w_mem_req_we),
        .mem_req_addr         (w_mem_req_addr),
        .mem_req_wdata        (w_mem_req_wdata),
        .mem_req_size         (w_mem_req_size),
        .mem_req_lsq_idx      (w_mem_req_lsq_idx),
        .mem_req_ready        (w_mem_req_ready),
        .mem_resp_valid       (w_mem_resp_valid),
        .mem_resp_data        (w_mem_resp_data),
        .mem_resp_lsq_idx     (w_mem_resp_lsq_idx),

        .cdb_valid            (w_lsq_cdb_valid),
        .cdb_tag              (w_lsq_cdb_tag),
        .cdb_phys_reg         (w_lsq_cdb_phys_reg),
        .cdb_result           (w_lsq_cdb_result),

        .cdb_fu0_valid        (cdb_fu0_valid),
        .cdb_fu0_phys_reg     (cdb_fu0_phys_reg),
        .cdb_fu0_result       (cdb_fu0_result),
        .cdb_fu1_valid        (cdb_fu1_valid),
        .cdb_fu1_phys_reg     (cdb_fu1_phys_reg),
        .cdb_fu1_result       (cdb_fu1_result),
        .cdb_fu2_valid        (cdb_fu2_valid),
        .cdb_fu2_phys_reg     (cdb_fu2_phys_reg),
        .cdb_fu2_result       (cdb_fu2_result),
        .cdb_fu3_valid        (cdb_fu3_valid),
        .cdb_fu3_phys_reg     (cdb_fu3_phys_reg),
        .cdb_fu3_result       (cdb_fu3_result),
        .cdb_bpu_valid        (cdb_bpu_valid),
        .cdb_bpu_phys_reg     (cdb_bpu_phys_reg),
        .cdb_bpu_result       (cdb_bpu_result),
        .cdb_lsq_snoop_valid  (w_lsq_cdb_valid),
        .cdb_lsq_snoop_phys_reg(w_lsq_cdb_phys_reg),
        .cdb_lsq_snoop_result (w_lsq_cdb_result),

        .dbg_head             (dbg_lsq_head),
        .dbg_tail             (dbg_lsq_tail),
        .dbg_count            (dbg_lsq_count)
    );

    // ================================================================
    // MAIN MEMORY
    // ================================================================
    Main_Memory #(
        .DEPTH     (MEM_DEPTH),
        .LSQ_PTR_W (LSQ_PTR_W),
        .INIT_FILE (INIT_FILE)
    ) u_mem (
        .clk              (clk),
        .rst              (rst),
        .mem_req_valid    (w_mem_req_valid),
        .mem_req_we       (w_mem_req_we),
        .mem_req_addr     (w_mem_req_addr),
        .mem_req_wdata    (w_mem_req_wdata),
        .mem_req_size     (w_mem_req_size),
        .mem_req_lsq_idx  (w_mem_req_lsq_idx),
        .mem_req_ready    (w_mem_req_ready),
        .mem_resp_valid   (w_mem_resp_valid),
        .mem_resp_data    (w_mem_resp_data),
        .mem_resp_lsq_idx (w_mem_resp_lsq_idx)
    );

    // ================================================================
    // ARF
    // ================================================================
    ARF u_arf (
        .clk              (clk),
        .rst              (rst),
        .commit_valid     (w_commit_valid),
        .commit_rd_valid  (w_commit_rd_valid),
        .commit_arch_rd   (w_commit_arch_rd),
        .commit_phys_rd   (w_commit_phys_rd),
        .commit_result    (w_commit_result),
        .arch_to_phys_out (w_arch_to_phys),
        .dbg_rd_addr0     (dbg_rd_addr0),
        .dbg_rd_data0     (dbg_rd_data0),
        .dbg_rd_addr1     (dbg_rd_addr1),
        .dbg_rd_data1     (dbg_rd_data1),
        .dbg_regfile_dump (dbg_arf_regfile),
        .dbg_rat_dump     (dbg_arf_rat)
    );
    assign arch_to_phys_flush = w_arch_to_phys;

endmodule*/
module issue_top #(
    parameter ROB_DEPTH  = 64,
    parameter ROB_PTR_W  = 6,
    parameter LSQ_DEPTH  = 32,
    parameter LSQ_PTR_W  = 5,
    parameter AQ_DEPTH   = 16,
    parameter AQ_PTR_W   = 4,
    parameter MEM_DEPTH  = 256,
    parameter INIT_FILE  = ""
)(
    input  wire clk,
    input  wire rst,

    // ================================================================
    // DISPATCH INPUT (from Stage 2 Decode/Rename)
    // ================================================================
    input  wire [3:0]   dispatch_valid,
    input  wire [3:0]   dispatch_is_alu,
    input  wire [3:0]   dispatch_is_mul,
    input  wire [3:0]   dispatch_is_load,
    input  wire [3:0]   dispatch_is_store,
    input  wire [3:0]   dispatch_is_branch,
    input  wire [3:0]   dispatch_is_jal,
    input  wire [3:0]   dispatch_is_jalr,
    input  wire [3:0]   dispatch_is_lui,
    input  wire [3:0]   dispatch_is_auipc,

    input  wire [23:0]  dispatch_phys_rs1,
    input  wire [23:0]  dispatch_phys_rs2,
    input  wire [23:0]  dispatch_phys_rd,
    input  wire [23:0]  dispatch_old_phys_rd,
    input  wire [19:0]  dispatch_arch_rd,
    input  wire [3:0]   dispatch_rd_valid,
    input  wire [3:0]   dispatch_rs1_valid,
    input  wire [3:0]   dispatch_rs2_valid,

    input  wire [27:0]  dispatch_opcode,
    input  wire [11:0]  dispatch_funct3,
    input  wire [27:0]  dispatch_funct7,
    input  wire [127:0] dispatch_imm,

    input  wire [31:0]  dispatch_pc0,
    input  wire [31:0]  dispatch_pc1,
    input  wire [31:0]  dispatch_pc2,
    input  wire [31:0]  dispatch_pc3,

    // ================================================================
    // CDB INPUTS (from Stage 4 Execute)
    // ================================================================
    input  wire         cdb_fu0_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu0_rob_idx,
    input  wire [5:0]   cdb_fu0_phys_reg,
    input  wire [31:0]  cdb_fu0_result,

    input  wire         cdb_fu1_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu1_rob_idx,
    input  wire [5:0]   cdb_fu1_phys_reg,
    input  wire [31:0]  cdb_fu1_result,

    input  wire         cdb_fu2_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu2_rob_idx,
    input  wire [5:0]   cdb_fu2_phys_reg,
    input  wire [31:0]  cdb_fu2_result,

    input  wire         cdb_fu3_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu3_rob_idx,
    input  wire [5:0]   cdb_fu3_phys_reg,
    input  wire [31:0]  cdb_fu3_result,

    input  wire         cdb_bpu_valid,
    input  wire [ROB_PTR_W-1:0] cdb_bpu_rob_idx,
    input  wire [5:0]   cdb_bpu_phys_reg,
    input  wire [31:0]  cdb_bpu_result,
    input  wire         cdb_bpu_mispredict,
    input  wire [31:0]  cdb_bpu_correct_pc,

    input  wire         cdb_mul_valid,
    input  wire [ROB_PTR_W-1:0] cdb_mul_rob_idx,
    input  wire [5:0]   cdb_mul_phys_reg,
    input  wire [31:0]  cdb_mul_result,

    // ================================================================
    // AGU WRITEBACK (from Stage 4 AGU -> back to LSQ)
    // ================================================================
    input  wire         agu_wb_valid,
    input  wire [LSQ_PTR_W-1:0] agu_wb_lsq_idx,
    input  wire [31:0]  agu_wb_addr,
    input  wire [31:0]  agu_wb_store_data,
    input  wire         agu_wb_data_valid,

    // ================================================================
    // BUFFER / PIPELINE CONTROLS
    // ================================================================
    input  wire         aq_buf_accept,
    input  wire         agu_ready,

    input  wire         fu0_ready,
    input  wire         fu1_ready,
    input  wire         fu2_ready,
    input  wire         fu3_ready,
    input  wire         bpu_ready,
    input  wire         mul_ready,

    // ================================================================
    // BACK-PRESSURE OUTPUTS (to Stage 2)
    // ================================================================
    output wire         rob_full,
    output wire         iq_full,
    output wire         lsq_full,

    // ================================================================
    // ISSUE OUTPUTS (to Stage 3/4 Buffer)
    // ================================================================
    // BPU
    output wire         bpu_valid,
    output wire [7:0]   bpu_seq_num,
    output wire [6:0]   bpu_opcode,
    output wire [2:0]   bpu_funct3,
    output wire [31:0]  bpu_imm,
    output wire [5:0]   bpu_phys_rs1,
    output wire [5:0]   bpu_phys_rs2,
    output wire [5:0]   bpu_phys_rd,
    output wire [31:0]  bpu_rs1_val,
    output wire [31:0]  bpu_rs2_val,

    // FU0
    output wire         fu0_valid,
    output wire [7:0]   fu0_seq_num,
    output wire [6:0]   fu0_opcode,
    output wire [2:0]   fu0_funct3,
    output wire [6:0]   fu0_funct7,
    output wire [31:0]  fu0_imm,
    output wire [5:0]   fu0_phys_rs1,
    output wire [5:0]   fu0_phys_rs2,
    output wire [5:0]   fu0_phys_rd,
    output wire [31:0]  fu0_rs1_val,
    output wire [31:0]  fu0_rs2_val,

    // FU1
    output wire         fu1_valid,
    output wire [7:0]   fu1_seq_num,
    output wire [6:0]   fu1_opcode,
    output wire [2:0]   fu1_funct3,
    output wire [6:0]   fu1_funct7,
    output wire [31:0]  fu1_imm,
    output wire [5:0]   fu1_phys_rs1,
    output wire [5:0]   fu1_phys_rs2,
    output wire [5:0]   fu1_phys_rd,
    output wire [31:0]  fu1_rs1_val,
    output wire [31:0]  fu1_rs2_val,

    // FU2
    output wire         fu2_valid,
    output wire [7:0]   fu2_seq_num,
    output wire [6:0]   fu2_opcode,
    output wire [2:0]   fu2_funct3,
    output wire [6:0]   fu2_funct7,
    output wire [31:0]  fu2_imm,
    output wire [5:0]   fu2_phys_rs1,
    output wire [5:0]   fu2_phys_rs2,
    output wire [5:0]   fu2_phys_rd,
    output wire [31:0]  fu2_rs1_val,
    output wire [31:0]  fu2_rs2_val,

    // FU3
    output wire         fu3_valid,
    output wire [7:0]   fu3_seq_num,
    output wire [6:0]   fu3_opcode,
    output wire [2:0]   fu3_funct3,
    output wire [6:0]   fu3_funct7,
    output wire [31:0]  fu3_imm,
    output wire [5:0]   fu3_phys_rs1,
    output wire [5:0]   fu3_phys_rs2,
    output wire [5:0]   fu3_phys_rd,
    output wire [31:0]  fu3_rs1_val,
    output wire [31:0]  fu3_rs2_val,

    // MUL
    output wire         mul_valid,
    output wire [7:0]   mul_seq_num,
    output wire [2:0]   mul_funct3,
    output wire [5:0]   mul_phys_rs1,
    output wire [5:0]   mul_phys_rs2,
    output wire [5:0]   mul_phys_rd,
    output wire [31:0]  mul_rs1_val,
    output wire [31:0]  mul_rs2_val,

    // AGU IQ Tracking
    output wire         agu_valid,
    output wire [7:0]   agu_seq_num,
    output wire [6:0]   agu_opcode,
    output wire [2:0]   agu_funct3,
    output wire [31:0]  agu_imm,
    output wire [5:0]   agu_phys_rs1,
    output wire [5:0]   agu_phys_rs2,
    output wire [5:0]   agu_phys_rd,
    output wire         agu_is_load,
    output wire         agu_is_store,

    // AGU Actual Execution Data (from LSQ's Address Queue)
    output wire                 aq_valid,
    output wire [4:0]           aq_lsq_idx,
    output wire [31:0]          aq_rs1_val,
    output wire [31:0]          aq_rs2_val,
    output wire [31:0]          aq_imm_out,
    output wire [2:0]           aq_funct3_out,
    output wire                 aq_is_load_out,
    output wire                 aq_is_store_out,

    // ================================================================
    // FLUSH OUTPUTS (to Stage 1 & 2)
    // ================================================================
    output wire         flush,
    output wire [7:0]   flush_seq_num,
    output wire [31:0]  flush_correct_pc,

    // ================================================================
    // FREELIST OUTPUTS (to Stage 2 Freelist, 4-wide)
    // ================================================================
    output wire [3:0]   commit_free_valid,
    output wire [23:0]  commit_old_phys_rd,
    output wire [3:0]   flush_free_valid,
    output wire [23:0]  flush_free_phys_rd,

    // ================================================================
    // RAT / RRAT OUTPUTS (to Stage 2 RAT, 4-wide)
    // ================================================================
    output wire [3:0]   commit_valid,
    output wire [19:0]  commit_arch_rd,
    output wire [23:0]  commit_phys_rd,
    output wire [127:0] commit_result,
    output wire [3:0]   commit_rd_valid,

    // ================================================================
    // PC PASSTHROUGHS
    // ================================================================
    output wire [31:0]  fu0_pc,
    output wire [31:0]  fu1_pc,
    output wire [31:0]  fu2_pc,
    output wire [31:0]  fu3_pc,
    output wire [31:0]  bpu_pc,

    // Store data readiness indicator
    output wire         aq_rs2_ready,

    // ================================================================
    // DEBUG OUTPUTS
    // ================================================================
    output wire [ROB_PTR_W-1:0] dbg_rob_head,
    output wire [ROB_PTR_W-1:0] dbg_rob_tail,
    output wire [ROB_PTR_W:0]   dbg_rob_count,
    output wire [LSQ_PTR_W-1:0] dbg_lsq_head,
    output wire [LSQ_PTR_W-1:0] dbg_lsq_tail,
    output wire [LSQ_PTR_W:0]   dbg_lsq_count,
    output wire [1023:0]        dbg_arf_regfile,
    output wire [191:0]         dbg_arf_rat,
    output wire [4:0]           dbg_rd_addr0,
    output wire [31:0]          dbg_rd_data0,
    output wire [4:0]           dbg_rd_addr1,
    output wire [31:0]          dbg_rd_data1,

    // Shadow RAT for flush recovery
    output wire [191:0]         arch_to_phys_flush
);

    // ================================================================
    // INTERNAL WIRES
    // ================================================================
    wire [ROB_PTR_W-1:0] w_rob_idx0, w_rob_idx1, w_rob_idx2, w_rob_idx3;

    wire [3:0]   w_commit_valid;
    wire [19:0]  w_commit_arch_rd;
    wire [23:0]  w_commit_phys_rd;
    wire [127:0] w_commit_result;
    wire [3:0]   w_commit_rd_valid;

    wire [3:0]   w_commit_free_valid;
    wire [23:0]  w_commit_old_phys_rd;
    wire [3:0]  w_flush_free_valid;
    wire [23:0] w_flush_free_phys_rd;

    wire [3:0]   w_commit_store_valid;
    wire [4*ROB_PTR_W-1:0] w_commit_store_rob_idx;
    wire        w_store_done_valid;
    wire [ROB_PTR_W-1:0] w_store_done_rob_idx;

    wire [5:0] w_bpu_phys_rs1, w_bpu_phys_rs2;
    wire [5:0] w_aq_phys_rs1, w_aq_phys_rs2;
    wire [5:0] w_mul_phys_rs1, w_mul_phys_rs2;

    wire        w_mem_req_valid;
    wire        w_mem_req_we;
    wire [31:0] w_mem_req_addr;
    wire [31:0] w_mem_req_wdata;
    wire [1:0]  w_mem_req_size;
    wire [LSQ_PTR_W-1:0] w_mem_req_lsq_idx;
    wire        w_mem_req_ready;

    wire        w_mem_resp_valid;
    wire [31:0] w_mem_resp_data;
    wire [LSQ_PTR_W-1:0] w_mem_resp_lsq_idx;

    wire        w_lsq_cdb_valid;
    wire [7:0]  w_lsq_cdb_tag;
    wire [5:0]  w_lsq_cdb_phys_reg;
    wire [31:0] w_lsq_cdb_result;

    wire [191:0] w_arch_to_phys;

    // ================================================================
    // EXPORT OUTPUTS
    // ================================================================
    assign commit_free_valid  = w_commit_free_valid;
    assign commit_old_phys_rd = w_commit_old_phys_rd;
    assign flush_free_valid   = w_flush_free_valid;
    assign flush_free_phys_rd = w_flush_free_phys_rd;

    assign commit_valid    = w_commit_valid;
    assign commit_arch_rd  = w_commit_arch_rd;
    assign commit_phys_rd  = w_commit_phys_rd;
    assign commit_result   = w_commit_result;
    assign commit_rd_valid = w_commit_rd_valid;

    assign bpu_phys_rs1 = w_bpu_phys_rs1;
    assign bpu_phys_rs2 = w_bpu_phys_rs2;

    // ================================================================
    // ROB
    // ================================================================
    ROB #(
        .ROB_DEPTH (ROB_DEPTH),
        .ROB_PTR_W (ROB_PTR_W),
        .LSQ_PTR_W (LSQ_PTR_W)
    ) u_rob (
        .clk                  (clk),
        .rst                  (rst),
        .dispatch_valid       (dispatch_valid),
        .dispatch_is_alu      (dispatch_is_alu),
        .dispatch_is_mul      (dispatch_is_mul),
        .dispatch_is_load     (dispatch_is_load),
        .dispatch_is_store    (dispatch_is_store),
        .dispatch_is_branch   (dispatch_is_branch),
        .dispatch_is_jal      (dispatch_is_jal),
        .dispatch_is_jalr     (dispatch_is_jalr),
        .dispatch_phys_rd     (dispatch_phys_rd),
        .dispatch_old_phys_rd (dispatch_old_phys_rd),
        .dispatch_rd_valid    (dispatch_rd_valid),
        .dispatch_pc0         (dispatch_pc0),
        .dispatch_pc1         (dispatch_pc1),
        .dispatch_pc2         (dispatch_pc2),
        .dispatch_pc3         (dispatch_pc3),
        .dispatch_arch_rd     (dispatch_arch_rd),

        .rob_idx_out0         (w_rob_idx0),
        .rob_idx_out1         (w_rob_idx1),
        .rob_idx_out2         (w_rob_idx2),
        .rob_idx_out3         (w_rob_idx3),
        .rob_full             (rob_full),

        .cdb_fu0_valid        (cdb_fu0_valid),
        .cdb_fu0_rob_idx      (cdb_fu0_rob_idx),
        .cdb_fu0_result       (cdb_fu0_result),
        .cdb_fu1_valid        (cdb_fu1_valid),
        .cdb_fu1_rob_idx      (cdb_fu1_rob_idx),
        .cdb_fu1_result       (cdb_fu1_result),
        .cdb_fu2_valid        (cdb_fu2_valid),
        .cdb_fu2_rob_idx      (cdb_fu2_rob_idx),
        .cdb_fu2_result       (cdb_fu2_result),
        .cdb_fu3_valid        (cdb_fu3_valid),
        .cdb_fu3_rob_idx      (cdb_fu3_rob_idx),
        .cdb_fu3_result       (cdb_fu3_result),
        .cdb_bpu_valid        (cdb_bpu_valid),
        .cdb_bpu_rob_idx      (cdb_bpu_rob_idx),
        .cdb_bpu_result       (cdb_bpu_result),
        .cdb_bpu_mispredict   (cdb_bpu_mispredict),
        .cdb_bpu_correct_pc   (cdb_bpu_correct_pc),
        .cdb_lsq_valid        (w_lsq_cdb_valid),
        .cdb_lsq_rob_idx      (w_lsq_cdb_tag[ROB_PTR_W-1:0]),
        .cdb_lsq_result       (w_lsq_cdb_result),

        .cdb_mul_valid        (cdb_mul_valid),
        .cdb_mul_rob_idx      (cdb_mul_rob_idx),
        .cdb_mul_result       (cdb_mul_result),

        .store_done_valid     (w_store_done_valid),
        .store_done_rob_idx   (w_store_done_rob_idx),
        .commit_store_valid   (w_commit_store_valid),
        .commit_store_rob_idx (w_commit_store_rob_idx),

        .commit_valid         (w_commit_valid),
        .commit_arch_rd       (w_commit_arch_rd),
        .commit_phys_rd       (w_commit_phys_rd),
        .commit_result        (w_commit_result),
        .commit_rd_valid      (w_commit_rd_valid),
        .commit_free_valid    (w_commit_free_valid),
        .commit_old_phys_rd   (w_commit_old_phys_rd),

        .flush                (flush),
        .flush_seq_num        (flush_seq_num),
        .flush_correct_pc     (flush_correct_pc),
        .flush_free_valid     (w_flush_free_valid),
        .flush_free_phys_rd   (w_flush_free_phys_rd),

        .dbg_head             (dbg_rob_head),
        .dbg_tail             (dbg_rob_tail),
        .dbg_count            (dbg_rob_count)
    );

    // ================================================================
    // ISSUE QUEUE
    // ================================================================
    Issue_Queue u_iq (
        .clk            (clk),
        .rst            (rst),
        .flush          (flush),
        .valid_in       (dispatch_valid),
        .phys_rs1_in    (dispatch_phys_rs1),
        .phys_rs2_in    (dispatch_phys_rs2),
        .phys_rd_in     (dispatch_phys_rd),
        .opcode_in      (dispatch_opcode),
        .funct3_in      (dispatch_funct3),
        .funct7_in      (dispatch_funct7),
        .imm_in         (dispatch_imm),
        .rs1_valid_in   (dispatch_rs1_valid),
        .rs2_valid_in   (dispatch_rs2_valid),
        .rd_valid_in    (dispatch_rd_valid),
        .is_alu_in      (dispatch_is_alu),
        .is_mul_in      (dispatch_is_mul),
        .is_load_in     (dispatch_is_load),
        .is_store_in    (dispatch_is_store),
        .is_branch_in   (dispatch_is_branch),
        .is_jal_in      (dispatch_is_jal),
        .is_jalr_in     (dispatch_is_jalr),
        .is_lui_in      (dispatch_is_lui),
        .is_auipc_in    (dispatch_is_auipc),
        .rob_idx_in0    ({2'b0, w_rob_idx0}),
        .rob_idx_in1    ({2'b0, w_rob_idx1}),
        .rob_idx_in2    ({2'b0, w_rob_idx2}),
        .rob_idx_in3    ({2'b0, w_rob_idx3}),
        .pc_in0         (dispatch_pc0),
        .pc_in1         (dispatch_pc1),
        .pc_in2         (dispatch_pc2),
        .pc_in3         (dispatch_pc3),
        .iq_full        (iq_full),

        .bpu_valid      (bpu_valid),
        .bpu_seq_num    (bpu_seq_num),
        .bpu_opcode     (bpu_opcode),
        .bpu_funct3     (bpu_funct3),
        .bpu_imm        (bpu_imm),
        .bpu_phys_rs1   (w_bpu_phys_rs1),
        .bpu_phys_rs2   (w_bpu_phys_rs2),
        .bpu_phys_rd    (bpu_phys_rd),
        .bpu_ready      (bpu_ready),
        .fu0_valid      (fu0_valid),
        .fu0_seq_num    (fu0_seq_num),
        .fu0_opcode     (fu0_opcode),
        .fu0_funct3     (fu0_funct3),
        .fu0_funct7     (fu0_funct7),
        .fu0_imm        (fu0_imm),
        .fu0_phys_rs1   (fu0_phys_rs1),
        .fu0_phys_rs2   (fu0_phys_rs2),
        .fu0_phys_rd    (fu0_phys_rd),
        .fu0_ready      (fu0_ready),
        .fu1_valid      (fu1_valid),
        .fu1_seq_num    (fu1_seq_num),
        .fu1_opcode     (fu1_opcode),
        .fu1_funct3     (fu1_funct3),
        .fu1_funct7     (fu1_funct7),
        .fu1_imm        (fu1_imm),
        .fu1_phys_rs1   (fu1_phys_rs1),
        .fu1_phys_rs2   (fu1_phys_rs2),
        .fu1_phys_rd    (fu1_phys_rd),
        .fu1_ready      (fu1_ready),
        .fu2_valid      (fu2_valid),
        .fu2_seq_num    (fu2_seq_num),
        .fu2_opcode     (fu2_opcode),
        .fu2_funct3     (fu2_funct3),
        .fu2_funct7     (fu2_funct7),
        .fu2_imm        (fu2_imm),
        .fu2_phys_rs1   (fu2_phys_rs1),
        .fu2_phys_rs2   (fu2_phys_rs2),
        .fu2_phys_rd    (fu2_phys_rd),
        .fu2_ready      (fu2_ready),
        .fu3_valid      (fu3_valid),
        .fu3_seq_num    (fu3_seq_num),
        .fu3_opcode     (fu3_opcode),
        .fu3_funct3     (fu3_funct3),
        .fu3_funct7     (fu3_funct7),
        .fu3_imm        (fu3_imm),
        .fu3_phys_rs1   (fu3_phys_rs1),
        .fu3_phys_rs2   (fu3_phys_rs2),
        .fu3_phys_rd    (fu3_phys_rd),
        .fu3_ready      (fu3_ready),

        .agu_valid      (agu_valid),
        .agu_seq_num    (agu_seq_num),
        .agu_opcode     (agu_opcode),
        .agu_funct3     (agu_funct3),
        .agu_imm        (agu_imm),
        .agu_phys_rs1   (agu_phys_rs1),
        .agu_phys_rs2   (agu_phys_rs2),
        .agu_phys_rd    (agu_phys_rd),
        .agu_is_load    (agu_is_load),
        .agu_is_store   (agu_is_store),

        .fu0_pc         (fu0_pc),
        .fu1_pc         (fu1_pc),
        .fu2_pc         (fu2_pc),
        .fu3_pc         (fu3_pc),
        .bpu_pc         (bpu_pc),
        .agu_ready      (agu_ready),

        .mul_valid      (mul_valid),
        .mul_seq_num    (mul_seq_num),
        .mul_funct3     (mul_funct3),
        .mul_phys_rs1   (w_mul_phys_rs1),
        .mul_phys_rs2   (w_mul_phys_rs2),
        .mul_phys_rd    (mul_phys_rd),
        .mul_ready      (mul_ready),

        .cdb_fu0_valid    (cdb_fu0_valid),
        .cdb_fu0_tag      ({2'b0, cdb_fu0_rob_idx}),
        .cdb_fu0_phys_reg (cdb_fu0_phys_reg),
        .cdb_fu1_valid    (cdb_fu1_valid),
        .cdb_fu1_tag      ({2'b0, cdb_fu1_rob_idx}),
        .cdb_fu1_phys_reg (cdb_fu1_phys_reg),
        .cdb_fu2_valid    (cdb_fu2_valid),
        .cdb_fu2_tag      ({2'b0, cdb_fu2_rob_idx}),
        .cdb_fu2_phys_reg (cdb_fu2_phys_reg),
        .cdb_fu3_valid    (cdb_fu3_valid),
        .cdb_fu3_tag      ({2'b0, cdb_fu3_rob_idx}),
        .cdb_fu3_phys_reg (cdb_fu3_phys_reg),
        .cdb_bpu_valid    (cdb_bpu_valid),
        .cdb_bpu_tag      ({2'b0, cdb_bpu_rob_idx}),
        .cdb_bpu_phys_reg (cdb_bpu_phys_reg),
        .cdb_lsq_valid    (w_lsq_cdb_valid),
        .cdb_lsq_tag      (w_lsq_cdb_tag),
        .cdb_lsq_phys_reg (w_lsq_cdb_phys_reg),
        .cdb_mul_valid    (cdb_mul_valid),
        .cdb_mul_tag      ({2'b0, cdb_mul_rob_idx}),
        .cdb_mul_phys_reg (cdb_mul_phys_reg)
    );

    // ================================================================
    // PRF
    // ================================================================
    PRF u_prf (
        .clk               (clk),
        .rst               (rst),
        .cdb_fu0_valid     (cdb_fu0_valid),
        .cdb_fu0_phys_reg  (cdb_fu0_phys_reg),
        .cdb_fu0_value     (cdb_fu0_result),
        .cdb_fu1_valid     (cdb_fu1_valid),
        .cdb_fu1_phys_reg  (cdb_fu1_phys_reg),
        .cdb_fu1_value     (cdb_fu1_result),
        .cdb_fu2_valid     (cdb_fu2_valid),
        .cdb_fu2_phys_reg  (cdb_fu2_phys_reg),
        .cdb_fu2_value     (cdb_fu2_result),
        .cdb_fu3_valid     (cdb_fu3_valid),
        .cdb_fu3_phys_reg  (cdb_fu3_phys_reg),
        .cdb_fu3_value     (cdb_fu3_result),
        .cdb_bpu_valid     (cdb_bpu_valid),
        .cdb_bpu_phys_reg  (cdb_bpu_phys_reg),
        .cdb_bpu_value     (cdb_bpu_result),
        .cdb_lsq_valid     (w_lsq_cdb_valid),
        .cdb_lsq_phys_reg  (w_lsq_cdb_phys_reg),
        .cdb_lsq_value     (w_lsq_cdb_result),

        .bpu_phys_rs1      (w_bpu_phys_rs1),
        .bpu_phys_rs2      (w_bpu_phys_rs2),
        .bpu_rs1_val       (bpu_rs1_val),
        .bpu_rs2_val       (bpu_rs2_val),
        .fu0_phys_rs1      (fu0_phys_rs1),
        .fu0_phys_rs2      (fu0_phys_rs2),
        .fu0_rs1_val       (fu0_rs1_val),
        .fu0_rs2_val       (fu0_rs2_val),
        .fu1_phys_rs1      (fu1_phys_rs1),
        .fu1_phys_rs2      (fu1_phys_rs2),
        .fu1_rs1_val       (fu1_rs1_val),
        .fu1_rs2_val       (fu1_rs2_val),
        .fu2_phys_rs1      (fu2_phys_rs1),
        .fu2_phys_rs2      (fu2_phys_rs2),
        .fu2_rs1_val       (fu2_rs1_val),
        .fu2_rs2_val       (fu2_rs2_val),
        .fu3_phys_rs1      (fu3_phys_rs1),
        .fu3_phys_rs2      (fu3_phys_rs2),
        .fu3_rs1_val       (fu3_rs1_val),
        .fu3_rs2_val       (fu3_rs2_val),

        .agu_phys_rs1      (w_aq_phys_rs1),
        .agu_phys_rs2      (w_aq_phys_rs2),
        .agu_rs1_val       (aq_rs1_val),
        .agu_rs2_val       (aq_rs2_val),
        .agu_rs2_ready     (aq_rs2_ready),

        .cdb_mul_valid     (cdb_mul_valid),
        .cdb_mul_phys_reg  (cdb_mul_phys_reg),
        .cdb_mul_value     (cdb_mul_result),
        .mul_phys_rs1      (w_mul_phys_rs1),
        .mul_phys_rs2      (w_mul_phys_rs2),
        .mul_rs1_val       (mul_rs1_val),
        .mul_rs2_val       (mul_rs2_val)
    );

    // ================================================================
    // LSQ
    // ================================================================
    LSQ #(
        .LSQ_DEPTH (LSQ_DEPTH),
        .AQ_DEPTH  (AQ_DEPTH),
        .LSQ_PTR_W (LSQ_PTR_W),
        .AQ_PTR_W  (AQ_PTR_W),
        .ROB_PTR_W (ROB_PTR_W)
    ) u_lsq (
        .clk                  (clk),
        .rst                  (rst),
        .flush                (flush),
        .flush_seq_num        (flush_seq_num),

        .dispatch_valid       (dispatch_valid),
        .dispatch_is_load     (dispatch_is_load),
        .dispatch_is_store    (dispatch_is_store),
        .dispatch_phys_rd     (dispatch_phys_rd),
        .dispatch_phys_rs1    (dispatch_phys_rs1),
        .dispatch_phys_rs2    (dispatch_phys_rs2),
        .dispatch_imm         (dispatch_imm),
        .dispatch_funct3      (dispatch_funct3),
        .rob_idx_in0          (w_rob_idx0),
        .rob_idx_in1          (w_rob_idx1),
        .rob_idx_in2          (w_rob_idx2),
        .rob_idx_in3          (w_rob_idx3),

        .lsq_full             (lsq_full),
        .aq_valid             (aq_valid),
        .aq_lsq_idx           (aq_lsq_idx),
        .aq_phys_rs1          (w_aq_phys_rs1),
        .aq_phys_rs2          (w_aq_phys_rs2),
        .aq_imm               (aq_imm_out),
        .aq_funct3            (aq_funct3_out),
        .aq_is_load           (aq_is_load_out),
        .aq_is_store          (aq_is_store_out),
        .agu_pop              (aq_buf_accept),

        .agu_wb_valid         (agu_wb_valid),
        .agu_wb_lsq_idx      (agu_wb_lsq_idx),
        .agu_wb_addr          (agu_wb_addr),
        .agu_wb_store_data    (agu_wb_store_data),
        .agu_wb_data_valid    (agu_wb_data_valid),

        // LSQ only retires 1 store/cycle. ROB guarantees at most 1 store in commit window.
        .store_commit_valid   (|w_commit_store_valid),
        .store_commit_rob_idx (w_commit_store_valid[0] ? w_commit_store_rob_idx[ROB_PTR_W-1:0] :
                               w_commit_store_valid[1] ? w_commit_store_rob_idx[2*ROB_PTR_W-1:ROB_PTR_W] :
                               w_commit_store_valid[2] ? w_commit_store_rob_idx[3*ROB_PTR_W-1:2*ROB_PTR_W] :
                                                         w_commit_store_rob_idx[4*ROB_PTR_W-1:3*ROB_PTR_W]),
        .store_done_valid     (w_store_done_valid),
        .store_done_rob_idx   (w_store_done_rob_idx),

        .mem_req_valid        (w_mem_req_valid),
        .mem_req_we           (w_mem_req_we),
        .mem_req_addr         (w_mem_req_addr),
        .mem_req_wdata        (w_mem_req_wdata),
        .mem_req_size         (w_mem_req_size),
        .mem_req_lsq_idx      (w_mem_req_lsq_idx),
        .mem_req_ready        (w_mem_req_ready),
        .mem_resp_valid       (w_mem_resp_valid),
        .mem_resp_data        (w_mem_resp_data),
        .mem_resp_lsq_idx     (w_mem_resp_lsq_idx),

        .cdb_valid            (w_lsq_cdb_valid),
        .cdb_tag              (w_lsq_cdb_tag),
        .cdb_phys_reg         (w_lsq_cdb_phys_reg),
        .cdb_result           (w_lsq_cdb_result),

        .cdb_fu0_valid        (cdb_fu0_valid),
        .cdb_fu0_phys_reg     (cdb_fu0_phys_reg),
        .cdb_fu0_result       (cdb_fu0_result),
        .cdb_fu1_valid        (cdb_fu1_valid),
        .cdb_fu1_phys_reg     (cdb_fu1_phys_reg),
        .cdb_fu1_result       (cdb_fu1_result),
        .cdb_fu2_valid        (cdb_fu2_valid),
        .cdb_fu2_phys_reg     (cdb_fu2_phys_reg),
        .cdb_fu2_result       (cdb_fu2_result),
        .cdb_fu3_valid        (cdb_fu3_valid),
        .cdb_fu3_phys_reg     (cdb_fu3_phys_reg),
        .cdb_fu3_result       (cdb_fu3_result),
        .cdb_bpu_valid        (cdb_bpu_valid),
        .cdb_bpu_phys_reg     (cdb_bpu_phys_reg),
        .cdb_bpu_result       (cdb_bpu_result),
        .cdb_lsq_snoop_valid  (w_lsq_cdb_valid),
        .cdb_lsq_snoop_phys_reg(w_lsq_cdb_phys_reg),
        .cdb_lsq_snoop_result (w_lsq_cdb_result),

        .dbg_head             (dbg_lsq_head),
        .dbg_tail             (dbg_lsq_tail),
        .dbg_count            (dbg_lsq_count)
    );

    // ================================================================
    // MAIN MEMORY
    // ================================================================
    Main_Memory #(
        .DEPTH     (MEM_DEPTH),
        .LSQ_PTR_W (LSQ_PTR_W),
        .INIT_FILE (INIT_FILE)
    ) u_mem (
        .clk              (clk),
        .rst              (rst),
        .mem_req_valid    (w_mem_req_valid),
        .mem_req_we       (w_mem_req_we),
        .mem_req_addr     (w_mem_req_addr),
        .mem_req_wdata    (w_mem_req_wdata),
        .mem_req_size     (w_mem_req_size),
        .mem_req_lsq_idx  (w_mem_req_lsq_idx),
        .mem_req_ready    (w_mem_req_ready),
        .mem_resp_valid   (w_mem_resp_valid),
        .mem_resp_data    (w_mem_resp_data),
        .mem_resp_lsq_idx (w_mem_resp_lsq_idx)
    );

    // ================================================================
    // ARF
    // ================================================================
    ARF u_arf (
        .clk              (clk),
        .rst              (rst),
        .commit_valid     (w_commit_valid),
        .commit_rd_valid  (w_commit_rd_valid),
        .commit_arch_rd   (w_commit_arch_rd),
        .commit_phys_rd   (w_commit_phys_rd),
        .commit_result    (w_commit_result),
        .arch_to_phys_out (w_arch_to_phys),
        .dbg_rd_addr0     (dbg_rd_addr0),
        .dbg_rd_data0     (dbg_rd_data0),
        .dbg_rd_addr1     (dbg_rd_addr1),
        .dbg_rd_data1     (dbg_rd_data1),
        .dbg_regfile_dump (dbg_arf_regfile),
        .dbg_rat_dump     (dbg_arf_rat)
    );
    assign arch_to_phys_flush = w_arch_to_phys;

endmodule

