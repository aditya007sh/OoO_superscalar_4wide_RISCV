/*module iq_ex_buffer #(
    parameter LSQ_PTR_W = 5
)(
    input  wire clk,
    input  wire rst,
    input  wire flush,

    // ================================================================
    // FU0 INPUT (from issue_top IQ + PRF)
    // ================================================================
    input  wire         fu0_valid_in,
    input  wire [7:0]   fu0_seq_num_in,
    input  wire [6:0]   fu0_opcode_in,
    input  wire [2:0]   fu0_funct3_in,
    input  wire [6:0]   fu0_funct7_in,
    input  wire [31:0]  fu0_imm_in,
    input  wire [5:0]   fu0_phys_rd_in,
    input  wire [31:0]  fu0_rs1_val_in,
    input  wire [31:0]  fu0_rs2_val_in,

    // FU1 INPUT
    input  wire         fu1_valid_in,
    input  wire [7:0]   fu1_seq_num_in,
    input  wire [6:0]   fu1_opcode_in,
    input  wire [2:0]   fu1_funct3_in,
    input  wire [6:0]   fu1_funct7_in,
    input  wire [31:0]  fu1_imm_in,
    input  wire [5:0]   fu1_phys_rd_in,
    input  wire [31:0]  fu1_rs1_val_in,
    input  wire [31:0]  fu1_rs2_val_in,

    // FU2 INPUT
    input  wire         fu2_valid_in,
    input  wire [7:0]   fu2_seq_num_in,
    input  wire [6:0]   fu2_opcode_in,
    input  wire [2:0]   fu2_funct3_in,
    input  wire [6:0]   fu2_funct7_in,
    input  wire [31:0]  fu2_imm_in,
    input  wire [5:0]   fu2_phys_rd_in,
    input  wire [31:0]  fu2_rs1_val_in,
    input  wire [31:0]  fu2_rs2_val_in,

    // FU3 INPUT
    input  wire         fu3_valid_in,
    input  wire [7:0]   fu3_seq_num_in,
    input  wire [6:0]   fu3_opcode_in,
    input  wire [2:0]   fu3_funct3_in,
    input  wire [6:0]   fu3_funct7_in,
    input  wire [31:0]  fu3_imm_in,
    input  wire [5:0]   fu3_phys_rd_in,
    input  wire [31:0]  fu3_rs1_val_in,
    input  wire [31:0]  fu3_rs2_val_in,

    // BPU INPUT
    input  wire         bpu_valid_in,
    input  wire [7:0]   bpu_seq_num_in,
    input  wire [6:0]   bpu_opcode_in,
    input  wire [2:0]   bpu_funct3_in,
    input  wire [31:0]  bpu_imm_in,
    input  wire [5:0]   bpu_phys_rd_in,
    input  wire [31:0]  bpu_rs1_val_in,
    input  wire [31:0]  bpu_rs2_val_in,

    // AGU INPUT (from AQ head + PRF values)
    input  wire                  agu_valid_in,
    input  wire [LSQ_PTR_W-1:0]  agu_lsq_idx_in,
    input  wire [31:0]           agu_rs1_val_in,
    input  wire [31:0]           agu_rs2_val_in,
    input  wire [31:0]           agu_imm_in,
    input  wire [2:0]            agu_funct3_in,
    input  wire                  agu_is_load_in,
    input  wire                  agu_is_store_in,

    // ================================================================
    // AQ POP - back to issue_top (stage 3)
    // ================================================================
    output wire                  aq_buf_accept,

    // ================================================================
    // FU0 OUTPUT (to combinational ALU0)
    // ================================================================
    output reg          fu0_valid_out,
    output reg  [7:0]   fu0_seq_num_out,
    output reg  [6:0]   fu0_opcode_out,
    output reg  [2:0]   fu0_funct3_out,
    output reg  [6:0]   fu0_funct7_out,
    output reg  [31:0]  fu0_imm_out,
    output reg  [5:0]   fu0_phys_rd_out,
    output reg  [31:0]  fu0_rs1_val_out,
    output reg  [31:0]  fu0_rs2_val_out,

    // FU1 OUTPUT
    output reg          fu1_valid_out,
    output reg  [7:0]   fu1_seq_num_out,
    output reg  [6:0]   fu1_opcode_out,
    output reg  [2:0]   fu1_funct3_out,
    output reg  [6:0]   fu1_funct7_out,
    output reg  [31:0]  fu1_imm_out,
    output reg  [5:0]   fu1_phys_rd_out,
    output reg  [31:0]  fu1_rs1_val_out,
    output reg  [31:0]  fu1_rs2_val_out,

    // FU2 OUTPUT
    output reg          fu2_valid_out,
    output reg  [7:0]   fu2_seq_num_out,
    output reg  [6:0]   fu2_opcode_out,
    output reg  [2:0]   fu2_funct3_out,
    output reg  [6:0]   fu2_funct7_out,
    output reg  [31:0]  fu2_imm_out,
    output reg  [5:0]   fu2_phys_rd_out,
    output reg  [31:0]  fu2_rs1_val_out,
    output reg  [31:0]  fu2_rs2_val_out,

    // FU3 OUTPUT
    output reg          fu3_valid_out,
    output reg  [7:0]   fu3_seq_num_out,
    output reg  [6:0]   fu3_opcode_out,
    output reg  [2:0]   fu3_funct3_out,
    output reg  [6:0]   fu3_funct7_out,
    output reg  [31:0]  fu3_imm_out,
    output reg  [5:0]   fu3_phys_rd_out,
    output reg  [31:0]  fu3_rs1_val_out,
    output reg  [31:0]  fu3_rs2_val_out,

    // BPU OUTPUT
    output reg          bpu_valid_out,
    output reg  [7:0]   bpu_seq_num_out,
    output reg  [6:0]   bpu_opcode_out,
    output reg  [2:0]   bpu_funct3_out,
    output reg  [31:0]  bpu_imm_out,
    output reg  [5:0]   bpu_phys_rd_out,
    output reg  [31:0]  bpu_rs1_val_out,
    output reg  [31:0]  bpu_rs2_val_out,

    // AGU OUTPUT (to combinational AGU)
    output reg                   agu_valid_out,
    output reg  [LSQ_PTR_W-1:0]  agu_lsq_idx_out,
    output reg  [31:0]           agu_rs1_val_out,
    output reg  [31:0]           agu_rs2_val_out,
    output reg  [31:0]           agu_imm_out,
    output reg  [2:0]            agu_funct3_out,
    output reg                   agu_is_load_out,
    output reg                   agu_is_store_out,

    // PC inputs
    input  wire [31:0]  fu0_pc_in,
    input  wire [31:0]  fu1_pc_in,
    input  wire [31:0]  fu2_pc_in,
    input  wire [31:0]  fu3_pc_in,
    input  wire [31:0]  bpu_pc_in,

    // PC outputs
    output reg  [31:0]  fu0_pc_out,
    output reg  [31:0]  fu1_pc_out,
    output reg  [31:0]  fu2_pc_out,
    output reg  [31:0]  fu3_pc_out,
    output reg  [31:0]  bpu_pc_out,

    // AGU store data readiness
    input  wire agu_rs2_ready_in,
    input  wire agu_ready_in,
    output reg  agu_rs2_ready_out
);

    // ================================================================
    // AQ POP - accept when AQ has data, not flushing
    // Buffer always has room (simple pipeline register, not FIFO)
    // ================================================================
    assign aq_buf_accept = agu_valid_in && agu_rs2_ready_in && agu_ready_in && !flush && !rst;

    // ================================================================
    // PIPELINE REGISTER - captures ALL ports every cycle
    // No backpressure: ALU/BPU/AGU are combinational consumers
    // ================================================================
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            // ---- FU0 ----
            fu0_valid_out   <= 1'b0;
            fu0_seq_num_out <= 8'd0;
            fu0_opcode_out  <= 7'd0;
            fu0_funct3_out  <= 3'd0;
            fu0_funct7_out  <= 7'd0;
            fu0_imm_out     <= 32'd0;
            fu0_phys_rd_out <= 6'd0;
            fu0_rs1_val_out <= 32'd0;
            fu0_rs2_val_out <= 32'd0;

            // ---- FU1 ----
            fu1_valid_out   <= 1'b0;
            fu1_seq_num_out <= 8'd0;
            fu1_opcode_out  <= 7'd0;
            fu1_funct3_out  <= 3'd0;
            fu1_funct7_out  <= 7'd0;
            fu1_imm_out     <= 32'd0;
            fu1_phys_rd_out <= 6'd0;
            fu1_rs1_val_out <= 32'd0;
            fu1_rs2_val_out <= 32'd0;

            // ---- FU2 ----
            fu2_valid_out   <= 1'b0;
            fu2_seq_num_out <= 8'd0;
            fu2_opcode_out  <= 7'd0;
            fu2_funct3_out  <= 3'd0;
            fu2_funct7_out  <= 7'd0;
            fu2_imm_out     <= 32'd0;
            fu2_phys_rd_out <= 6'd0;
            fu2_rs1_val_out <= 32'd0;
            fu2_rs2_val_out <= 32'd0;

            // ---- FU3 ----
            fu3_valid_out   <= 1'b0;
            fu3_seq_num_out <= 8'd0;
            fu3_opcode_out  <= 7'd0;
            fu3_funct3_out  <= 3'd0;
            fu3_funct7_out  <= 7'd0;
            fu3_imm_out     <= 32'd0;
            fu3_phys_rd_out <= 6'd0;
            fu3_rs1_val_out <= 32'd0;
            fu3_rs2_val_out <= 32'd0;

            // ---- BPU ----
            bpu_valid_out   <= 1'b0;
            bpu_seq_num_out <= 8'd0;
            bpu_opcode_out  <= 7'd0;
            bpu_funct3_out  <= 3'd0;
            bpu_imm_out     <= 32'd0;
            bpu_phys_rd_out <= 6'd0;
            bpu_rs1_val_out <= 32'd0;
            bpu_rs2_val_out <= 32'd0;

            // ---- AGU ----
            agu_valid_out     <= 1'b0;
            agu_lsq_idx_out   <= {LSQ_PTR_W{1'b0}};
            agu_rs1_val_out   <= 32'd0;
            agu_rs2_val_out   <= 32'd0;
            agu_imm_out       <= 32'd0;
            agu_funct3_out    <= 3'd0;
            agu_is_load_out   <= 1'b0;
            agu_is_store_out  <= 1'b0;
            agu_rs2_ready_out <= 1'b0;

            // ---- PCs ----
            fu0_pc_out <= 32'd0;
            fu1_pc_out <= 32'd0;
            fu2_pc_out <= 32'd0;
            fu3_pc_out <= 32'd0;
            bpu_pc_out <= 32'd0;

        end else begin
            // ---- FU0 ----
            fu0_valid_out   <= fu0_valid_in;
            fu0_seq_num_out <= fu0_seq_num_in;
            fu0_opcode_out  <= fu0_opcode_in;
            fu0_funct3_out  <= fu0_funct3_in;
            fu0_funct7_out  <= fu0_funct7_in;
            fu0_imm_out     <= fu0_imm_in;
            fu0_phys_rd_out <= fu0_phys_rd_in;
            fu0_rs1_val_out <= fu0_rs1_val_in;
            fu0_rs2_val_out <= fu0_rs2_val_in;

            // ---- FU1 ----
            fu1_valid_out   <= fu1_valid_in;
            fu1_seq_num_out <= fu1_seq_num_in;
            fu1_opcode_out  <= fu1_opcode_in;
            fu1_funct3_out  <= fu1_funct3_in;
            fu1_funct7_out  <= fu1_funct7_in;
            fu1_imm_out     <= fu1_imm_in;
            fu1_phys_rd_out <= fu1_phys_rd_in;
            fu1_rs1_val_out <= fu1_rs1_val_in;
            fu1_rs2_val_out <= fu1_rs2_val_in;

            // ---- FU2 ----
            fu2_valid_out   <= fu2_valid_in;
            fu2_seq_num_out <= fu2_seq_num_in;
            fu2_opcode_out  <= fu2_opcode_in;
            fu2_funct3_out  <= fu2_funct3_in;
            fu2_funct7_out  <= fu2_funct7_in;
            fu2_imm_out     <= fu2_imm_in;
            fu2_phys_rd_out <= fu2_phys_rd_in;
            fu2_rs1_val_out <= fu2_rs1_val_in;
            fu2_rs2_val_out <= fu2_rs2_val_in;

            // ---- FU3 ----
            fu3_valid_out   <= fu3_valid_in;
            fu3_seq_num_out <= fu3_seq_num_in;
            fu3_opcode_out  <= fu3_opcode_in;
            fu3_funct3_out  <= fu3_funct3_in;
            fu3_funct7_out  <= fu3_funct7_in;
            fu3_imm_out     <= fu3_imm_in;
            fu3_phys_rd_out <= fu3_phys_rd_in;
            fu3_rs1_val_out <= fu3_rs1_val_in;
            fu3_rs2_val_out <= fu3_rs2_val_in;

            // ---- BPU ----
            bpu_valid_out   <= bpu_valid_in;
            bpu_seq_num_out <= bpu_seq_num_in;
            bpu_opcode_out  <= bpu_opcode_in;
            bpu_funct3_out  <= bpu_funct3_in;
            bpu_imm_out     <= bpu_imm_in;
            bpu_phys_rd_out <= bpu_phys_rd_in;
            bpu_rs1_val_out <= bpu_rs1_val_in;
            bpu_rs2_val_out <= bpu_rs2_val_in;

            // ---- AGU ----
            agu_valid_out     <= agu_valid_in;
            agu_lsq_idx_out   <= agu_lsq_idx_in;
            agu_rs1_val_out   <= agu_rs1_val_in;
            agu_rs2_val_out   <= agu_rs2_val_in;
            agu_imm_out       <= agu_imm_in;
            agu_funct3_out    <= agu_funct3_in;
            agu_is_load_out   <= agu_is_load_in;
            agu_is_store_out  <= agu_is_store_in;
            agu_rs2_ready_out <= agu_rs2_ready_in;

            // ---- PCs ----
            fu0_pc_out <= fu0_pc_in;
            fu1_pc_out <= fu1_pc_in;
            fu2_pc_out <= fu2_pc_in;
            fu3_pc_out <= fu3_pc_in;
            bpu_pc_out <= bpu_pc_in;
        end
    end

endmodule*/
module iq_ex_buffer #(
    parameter LSQ_PTR_W = 5
)(
    input  wire clk,
    input  wire rst,
    input  wire flush,

    // ================================================================
    // FU0 INPUT (from issue_top IQ + PRF)
    // ================================================================
    input  wire         fu0_valid_in,
    input  wire [7:0]   fu0_seq_num_in,
    input  wire [6:0]   fu0_opcode_in,
    input  wire [2:0]   fu0_funct3_in,
    input  wire [6:0]   fu0_funct7_in,
    input  wire [31:0]  fu0_imm_in,
    input  wire [5:0]   fu0_phys_rd_in,
    input  wire [31:0]  fu0_rs1_val_in,
    input  wire [31:0]  fu0_rs2_val_in,

    // FU1 INPUT
    input  wire         fu1_valid_in,
    input  wire [7:0]   fu1_seq_num_in,
    input  wire [6:0]   fu1_opcode_in,
    input  wire [2:0]   fu1_funct3_in,
    input  wire [6:0]   fu1_funct7_in,
    input  wire [31:0]  fu1_imm_in,
    input  wire [5:0]   fu1_phys_rd_in,
    input  wire [31:0]  fu1_rs1_val_in,
    input  wire [31:0]  fu1_rs2_val_in,

    // FU2 INPUT
    input  wire         fu2_valid_in,
    input  wire [7:0]   fu2_seq_num_in,
    input  wire [6:0]   fu2_opcode_in,
    input  wire [2:0]   fu2_funct3_in,
    input  wire [6:0]   fu2_funct7_in,
    input  wire [31:0]  fu2_imm_in,
    input  wire [5:0]   fu2_phys_rd_in,
    input  wire [31:0]  fu2_rs1_val_in,
    input  wire [31:0]  fu2_rs2_val_in,

    // FU3 INPUT
    input  wire         fu3_valid_in,
    input  wire [7:0]   fu3_seq_num_in,
    input  wire [6:0]   fu3_opcode_in,
    input  wire [2:0]   fu3_funct3_in,
    input  wire [6:0]   fu3_funct7_in,
    input  wire [31:0]  fu3_imm_in,
    input  wire [5:0]   fu3_phys_rd_in,
    input  wire [31:0]  fu3_rs1_val_in,
    input  wire [31:0]  fu3_rs2_val_in,

    // BPU INPUT
    input  wire         bpu_valid_in,
    input  wire [7:0]   bpu_seq_num_in,
    input  wire [6:0]   bpu_opcode_in,
    input  wire [2:0]   bpu_funct3_in,
    input  wire [31:0]  bpu_imm_in,
    input  wire [5:0]   bpu_phys_rd_in,
    input  wire [31:0]  bpu_rs1_val_in,
    input  wire [31:0]  bpu_rs2_val_in,

    // MUL INPUT
    input  wire         mul_valid_in,
    input  wire [7:0]   mul_seq_num_in,
    input  wire [2:0]   mul_funct3_in,
    input  wire [5:0]   mul_phys_rd_in,
    input  wire [31:0]  mul_rs1_val_in,
    input  wire [31:0]  mul_rs2_val_in,

    // AGU INPUT (from AQ head + PRF values)
    input  wire                  agu_valid_in,
    input  wire [LSQ_PTR_W-1:0]  agu_lsq_idx_in,
    input  wire [31:0]           agu_rs1_val_in,
    input  wire [31:0]           agu_rs2_val_in,
    input  wire [31:0]           agu_imm_in,
    input  wire [2:0]            agu_funct3_in,
    input  wire                  agu_is_load_in,
    input  wire                  agu_is_store_in,

    // ================================================================
    // AQ POP - back to issue_top (stage 3)
    // ================================================================
    output wire                  aq_buf_accept,

    // ================================================================
    // FU0 OUTPUT (to combinational ALU0)
    // ================================================================
    output reg          fu0_valid_out,
    output reg  [7:0]   fu0_seq_num_out,
    output reg  [6:0]   fu0_opcode_out,
    output reg  [2:0]   fu0_funct3_out,
    output reg  [6:0]   fu0_funct7_out,
    output reg  [31:0]  fu0_imm_out,
    output reg  [5:0]   fu0_phys_rd_out,
    output reg  [31:0]  fu0_rs1_val_out,
    output reg  [31:0]  fu0_rs2_val_out,

    // FU1 OUTPUT
    output reg          fu1_valid_out,
    output reg  [7:0]   fu1_seq_num_out,
    output reg  [6:0]   fu1_opcode_out,
    output reg  [2:0]   fu1_funct3_out,
    output reg  [6:0]   fu1_funct7_out,
    output reg  [31:0]  fu1_imm_out,
    output reg  [5:0]   fu1_phys_rd_out,
    output reg  [31:0]  fu1_rs1_val_out,
    output reg  [31:0]  fu1_rs2_val_out,

    // FU2 OUTPUT
    output reg          fu2_valid_out,
    output reg  [7:0]   fu2_seq_num_out,
    output reg  [6:0]   fu2_opcode_out,
    output reg  [2:0]   fu2_funct3_out,
    output reg  [6:0]   fu2_funct7_out,
    output reg  [31:0]  fu2_imm_out,
    output reg  [5:0]   fu2_phys_rd_out,
    output reg  [31:0]  fu2_rs1_val_out,
    output reg  [31:0]  fu2_rs2_val_out,

    // FU3 OUTPUT
    output reg          fu3_valid_out,
    output reg  [7:0]   fu3_seq_num_out,
    output reg  [6:0]   fu3_opcode_out,
    output reg  [2:0]   fu3_funct3_out,
    output reg  [6:0]   fu3_funct7_out,
    output reg  [31:0]  fu3_imm_out,
    output reg  [5:0]   fu3_phys_rd_out,
    output reg  [31:0]  fu3_rs1_val_out,
    output reg  [31:0]  fu3_rs2_val_out,

    // BPU OUTPUT
    output reg          bpu_valid_out,
    output reg  [7:0]   bpu_seq_num_out,
    output reg  [6:0]   bpu_opcode_out,
    output reg  [2:0]   bpu_funct3_out,
    output reg  [31:0]  bpu_imm_out,
    output reg  [5:0]   bpu_phys_rd_out,
    output reg  [31:0]  bpu_rs1_val_out,
    output reg  [31:0]  bpu_rs2_val_out,

    // MUL OUTPUT
    output reg          mul_valid_out,
    output reg  [7:0]   mul_seq_num_out,
    output reg  [2:0]   mul_funct3_out,
    output reg  [5:0]   mul_phys_rd_out,
    output reg  [31:0]  mul_rs1_val_out,
    output reg  [31:0]  mul_rs2_val_out,

    // AGU OUTPUT (to combinational AGU)
    output reg                   agu_valid_out,
    output reg  [LSQ_PTR_W-1:0]  agu_lsq_idx_out,
    output reg  [31:0]           agu_rs1_val_out,
    output reg  [31:0]           agu_rs2_val_out,
    output reg  [31:0]           agu_imm_out,
    output reg  [2:0]            agu_funct3_out,
    output reg                   agu_is_load_out,
    output reg                   agu_is_store_out,

    // PC inputs
    input  wire [31:0]  fu0_pc_in,
    input  wire [31:0]  fu1_pc_in,
    input  wire [31:0]  fu2_pc_in,
    input  wire [31:0]  fu3_pc_in,
    input  wire [31:0]  bpu_pc_in,

    // PC outputs
    output reg  [31:0]  fu0_pc_out,
    output reg  [31:0]  fu1_pc_out,
    output reg  [31:0]  fu2_pc_out,
    output reg  [31:0]  fu3_pc_out,
    output reg  [31:0]  bpu_pc_out,

    // AGU store data readiness
    input  wire agu_rs2_ready_in,
    input  wire agu_ready_in,
    output reg  agu_rs2_ready_out
);

    // ================================================================
    // AQ POP - accept when AQ has data, not flushing
    // Buffer always has room (simple pipeline register, not FIFO)
    // ================================================================
    assign aq_buf_accept = agu_valid_in && agu_rs2_ready_in && agu_ready_in && !flush && !rst;

    // ================================================================
    // PIPELINE REGISTER - captures ALL ports every cycle
    // No backpressure: ALU/BPU/AGU are combinational consumers
    // ================================================================
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            // ---- FU0 ----
            fu0_valid_out   <= 1'b0;
            fu0_seq_num_out <= 8'd0;
            fu0_opcode_out  <= 7'd0;
            fu0_funct3_out  <= 3'd0;
            fu0_funct7_out  <= 7'd0;
            fu0_imm_out     <= 32'd0;
            fu0_phys_rd_out <= 6'd0;
            fu0_rs1_val_out <= 32'd0;
            fu0_rs2_val_out <= 32'd0;

            // ---- FU1 ----
            fu1_valid_out   <= 1'b0;
            fu1_seq_num_out <= 8'd0;
            fu1_opcode_out  <= 7'd0;
            fu1_funct3_out  <= 3'd0;
            fu1_funct7_out  <= 7'd0;
            fu1_imm_out     <= 32'd0;
            fu1_phys_rd_out <= 6'd0;
            fu1_rs1_val_out <= 32'd0;
            fu1_rs2_val_out <= 32'd0;

            // ---- FU2 ----
            fu2_valid_out   <= 1'b0;
            fu2_seq_num_out <= 8'd0;
            fu2_opcode_out  <= 7'd0;
            fu2_funct3_out  <= 3'd0;
            fu2_funct7_out  <= 7'd0;
            fu2_imm_out     <= 32'd0;
            fu2_phys_rd_out <= 6'd0;
            fu2_rs1_val_out <= 32'd0;
            fu2_rs2_val_out <= 32'd0;

            // ---- FU3 ----
            fu3_valid_out   <= 1'b0;
            fu3_seq_num_out <= 8'd0;
            fu3_opcode_out  <= 7'd0;
            fu3_funct3_out  <= 3'd0;
            fu3_funct7_out  <= 7'd0;
            fu3_imm_out     <= 32'd0;
            fu3_phys_rd_out <= 6'd0;
            fu3_rs1_val_out <= 32'd0;
            fu3_rs2_val_out <= 32'd0;

            // ---- BPU ----
            bpu_valid_out   <= 1'b0;
            bpu_seq_num_out <= 8'd0;
            bpu_opcode_out  <= 7'd0;
            bpu_funct3_out  <= 3'd0;
            bpu_imm_out     <= 32'd0;
            bpu_phys_rd_out <= 6'd0;
            bpu_rs1_val_out <= 32'd0;
            bpu_rs2_val_out <= 32'd0;

            // ---- MUL ----
            mul_valid_out   <= 1'b0;
            mul_seq_num_out <= 8'd0;
            mul_funct3_out  <= 3'd0;
            mul_phys_rd_out <= 6'd0;
            mul_rs1_val_out <= 32'd0;
            mul_rs2_val_out <= 32'd0;

            // ---- AGU ----
            agu_valid_out     <= 1'b0;
            agu_lsq_idx_out   <= {LSQ_PTR_W{1'b0}};
            agu_rs1_val_out   <= 32'd0;
            agu_rs2_val_out   <= 32'd0;
            agu_imm_out       <= 32'd0;
            agu_funct3_out    <= 3'd0;
            agu_is_load_out   <= 1'b0;
            agu_is_store_out  <= 1'b0;
            agu_rs2_ready_out <= 1'b0;

            // ---- PCs ----
            fu0_pc_out <= 32'd0;
            fu1_pc_out <= 32'd0;
            fu2_pc_out <= 32'd0;
            fu3_pc_out <= 32'd0;
            bpu_pc_out <= 32'd0;

        end else begin
            // ---- FU0 ----
            fu0_valid_out   <= fu0_valid_in;
            fu0_seq_num_out <= fu0_seq_num_in;
            fu0_opcode_out  <= fu0_opcode_in;
            fu0_funct3_out  <= fu0_funct3_in;
            fu0_funct7_out  <= fu0_funct7_in;
            fu0_imm_out     <= fu0_imm_in;
            fu0_phys_rd_out <= fu0_phys_rd_in;
            fu0_rs1_val_out <= fu0_rs1_val_in;
            fu0_rs2_val_out <= fu0_rs2_val_in;

            // ---- FU1 ----
            fu1_valid_out   <= fu1_valid_in;
            fu1_seq_num_out <= fu1_seq_num_in;
            fu1_opcode_out  <= fu1_opcode_in;
            fu1_funct3_out  <= fu1_funct3_in;
            fu1_funct7_out  <= fu1_funct7_in;
            fu1_imm_out     <= fu1_imm_in;
            fu1_phys_rd_out <= fu1_phys_rd_in;
            fu1_rs1_val_out <= fu1_rs1_val_in;
            fu1_rs2_val_out <= fu1_rs2_val_in;

            // ---- FU2 ----
            fu2_valid_out   <= fu2_valid_in;
            fu2_seq_num_out <= fu2_seq_num_in;
            fu2_opcode_out  <= fu2_opcode_in;
            fu2_funct3_out  <= fu2_funct3_in;
            fu2_funct7_out  <= fu2_funct7_in;
            fu2_imm_out     <= fu2_imm_in;
            fu2_phys_rd_out <= fu2_phys_rd_in;
            fu2_rs1_val_out <= fu2_rs1_val_in;
            fu2_rs2_val_out <= fu2_rs2_val_in;

            // ---- FU3 ----
            fu3_valid_out   <= fu3_valid_in;
            fu3_seq_num_out <= fu3_seq_num_in;
            fu3_opcode_out  <= fu3_opcode_in;
            fu3_funct3_out  <= fu3_funct3_in;
            fu3_funct7_out  <= fu3_funct7_in;
            fu3_imm_out     <= fu3_imm_in;
            fu3_phys_rd_out <= fu3_phys_rd_in;
            fu3_rs1_val_out <= fu3_rs1_val_in;
            fu3_rs2_val_out <= fu3_rs2_val_in;

            // ---- BPU ----
            bpu_valid_out   <= bpu_valid_in;
            bpu_seq_num_out <= bpu_seq_num_in;
            bpu_opcode_out  <= bpu_opcode_in;
            bpu_funct3_out  <= bpu_funct3_in;
            bpu_imm_out     <= bpu_imm_in;
            bpu_phys_rd_out <= bpu_phys_rd_in;
            bpu_rs1_val_out <= bpu_rs1_val_in;
            bpu_rs2_val_out <= bpu_rs2_val_in;

            // ---- MUL ----
            mul_valid_out   <= mul_valid_in;
            mul_seq_num_out <= mul_seq_num_in;
            mul_funct3_out  <= mul_funct3_in;
            mul_phys_rd_out <= mul_phys_rd_in;
            mul_rs1_val_out <= mul_rs1_val_in;
            mul_rs2_val_out <= mul_rs2_val_in;

            // ---- AGU ----
            agu_valid_out     <= agu_valid_in;
            agu_lsq_idx_out   <= agu_lsq_idx_in;
            agu_rs1_val_out   <= agu_rs1_val_in;
            agu_rs2_val_out   <= agu_rs2_val_in;
            agu_imm_out       <= agu_imm_in;
            agu_funct3_out    <= agu_funct3_in;
            agu_is_load_out   <= agu_is_load_in;
            agu_is_store_out  <= agu_is_store_in;
            agu_rs2_ready_out <= agu_rs2_ready_in;

            // ---- PCs ----
            fu0_pc_out <= fu0_pc_in;
            fu1_pc_out <= fu1_pc_in;
            fu2_pc_out <= fu2_pc_in;
            fu3_pc_out <= fu3_pc_in;
            bpu_pc_out <= bpu_pc_in;
        end
    end

endmodule

