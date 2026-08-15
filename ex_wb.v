/*module ex_wb_buffer #(
    parameter ROB_PTR_W = 6,
    parameter LSQ_PTR_W = 5
)(
    input  wire clk,
    input  wire rst,
    input  wire flush,

    // ================================================================
    // FROM ALU0-3 (combinational)
    // ================================================================
    input  wire        alu0_valid_in,
    input  wire [ROB_PTR_W-1:0] alu0_rob_idx_in,
    input  wire [5:0]  alu0_phys_reg_in,
    input  wire [31:0] alu0_result_in,

    input  wire        alu1_valid_in,
    input  wire [ROB_PTR_W-1:0] alu1_rob_idx_in,
    input  wire [5:0]  alu1_phys_reg_in,
    input  wire [31:0] alu1_result_in,

    input  wire        alu2_valid_in,
    input  wire [ROB_PTR_W-1:0] alu2_rob_idx_in,
    input  wire [5:0]  alu2_phys_reg_in,
    input  wire [31:0] alu2_result_in,

    input  wire        alu3_valid_in,
    input  wire [ROB_PTR_W-1:0] alu3_rob_idx_in,
    input  wire [5:0]  alu3_phys_reg_in,
    input  wire [31:0] alu3_result_in,

    // FROM BPU (combinational)
    input  wire        bpu_valid_in,
    input  wire [ROB_PTR_W-1:0] bpu_rob_idx_in,
    input  wire [5:0]  bpu_phys_reg_in,
    input  wire [31:0] bpu_result_in,
    input  wire        bpu_mispredict_in,
    input  wire [31:0] bpu_correct_pc_in,

    // FROM AGU (combinational)
    input  wire        agu_valid_in,
    input  wire [LSQ_PTR_W-1:0] agu_lsq_idx_in,
    input  wire [31:0] agu_addr_in,
    input  wire [31:0] agu_store_data_in,
    input  wire        agu_data_valid_in,

    // ================================================================
    // TO CDB / ROB / LSQ (registered)
    // ================================================================
    output reg         alu0_valid_out,
    output reg  [ROB_PTR_W-1:0] alu0_rob_idx_out,
    output reg  [5:0]  alu0_phys_reg_out,
    output reg  [31:0] alu0_result_out,

    output reg         alu1_valid_out,
    output reg  [ROB_PTR_W-1:0] alu1_rob_idx_out,
    output reg  [5:0]  alu1_phys_reg_out,
    output reg  [31:0] alu1_result_out,

    output reg         alu2_valid_out,
    output reg  [ROB_PTR_W-1:0] alu2_rob_idx_out,
    output reg  [5:0]  alu2_phys_reg_out,
    output reg  [31:0] alu2_result_out,

    output reg         alu3_valid_out,
    output reg  [ROB_PTR_W-1:0] alu3_rob_idx_out,
    output reg  [5:0]  alu3_phys_reg_out,
    output reg  [31:0] alu3_result_out,

    output reg         bpu_valid_out,
    output reg  [ROB_PTR_W-1:0] bpu_rob_idx_out,
    output reg  [5:0]  bpu_phys_reg_out,
    output reg  [31:0] bpu_result_out,
    output reg         bpu_mispredict_out,
    output reg  [31:0] bpu_correct_pc_out,

    output reg         agu_valid_out,
    output reg  [LSQ_PTR_W-1:0] agu_lsq_idx_out,
    output reg  [31:0] agu_addr_out,
    output reg  [31:0] agu_store_data_out,
    output reg         agu_data_valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            alu0_valid_out     <= 1'b0;
            alu0_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu0_phys_reg_out  <= 6'd0;
            alu0_result_out    <= 32'd0;

            alu1_valid_out     <= 1'b0;
            alu1_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu1_phys_reg_out  <= 6'd0;
            alu1_result_out    <= 32'd0;

            alu2_valid_out     <= 1'b0;
            alu2_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu2_phys_reg_out  <= 6'd0;
            alu2_result_out    <= 32'd0;

            alu3_valid_out     <= 1'b0;
            alu3_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu3_phys_reg_out  <= 6'd0;
            alu3_result_out    <= 32'd0;

            bpu_valid_out      <= 1'b0;
            bpu_rob_idx_out    <= {ROB_PTR_W{1'b0}};
            bpu_phys_reg_out   <= 6'd0;
            bpu_result_out     <= 32'd0;
            bpu_mispredict_out <= 1'b0;
            bpu_correct_pc_out <= 32'd0;

            agu_valid_out      <= 1'b0;
            agu_lsq_idx_out    <= {LSQ_PTR_W{1'b0}};
            agu_addr_out       <= 32'd0;
            agu_store_data_out <= 32'd0;
            agu_data_valid_out <= 1'b0;
        end
        else begin
            // ALU0
            alu0_valid_out     <= alu0_valid_in;
            alu0_rob_idx_out   <= alu0_rob_idx_in;
            alu0_phys_reg_out  <= alu0_phys_reg_in;
            alu0_result_out    <= alu0_result_in;
            // ALU1
            alu1_valid_out     <= alu1_valid_in;
            alu1_rob_idx_out   <= alu1_rob_idx_in;
            alu1_phys_reg_out  <= alu1_phys_reg_in;
            alu1_result_out    <= alu1_result_in;
            // ALU2
            alu2_valid_out     <= alu2_valid_in;
            alu2_rob_idx_out   <= alu2_rob_idx_in;
            alu2_phys_reg_out  <= alu2_phys_reg_in;
            alu2_result_out    <= alu2_result_in;
            // ALU3
            alu3_valid_out     <= alu3_valid_in;
            alu3_rob_idx_out   <= alu3_rob_idx_in;
            alu3_phys_reg_out  <= alu3_phys_reg_in;
            alu3_result_out    <= alu3_result_in;
            // BPU
            bpu_valid_out      <= bpu_valid_in;
            bpu_rob_idx_out    <= bpu_rob_idx_in;
            bpu_phys_reg_out   <= bpu_phys_reg_in;
            bpu_result_out     <= bpu_result_in;
            bpu_mispredict_out <= bpu_mispredict_in;
            bpu_correct_pc_out <= bpu_correct_pc_in;
            // AGU
            agu_valid_out      <= agu_valid_in;
            agu_lsq_idx_out    <= agu_lsq_idx_in;
            agu_addr_out       <= agu_addr_in;
            agu_store_data_out <= agu_store_data_in;
            agu_data_valid_out <= agu_data_valid_in;
        end
    end

endmodule
*/
module ex_wb_buffer #(
    parameter ROB_PTR_W = 6,
    parameter LSQ_PTR_W = 5
)(
    input  wire clk,
    input  wire rst,
    input  wire flush,

    // ================================================================
    // FROM ALU0-3 (combinational)
    // ================================================================
    input  wire        alu0_valid_in,
    input  wire [ROB_PTR_W-1:0] alu0_rob_idx_in,
    input  wire [5:0]  alu0_phys_reg_in,
    input  wire [31:0] alu0_result_in,

    input  wire        alu1_valid_in,
    input  wire [ROB_PTR_W-1:0] alu1_rob_idx_in,
    input  wire [5:0]  alu1_phys_reg_in,
    input  wire [31:0] alu1_result_in,

    input  wire        alu2_valid_in,
    input  wire [ROB_PTR_W-1:0] alu2_rob_idx_in,
    input  wire [5:0]  alu2_phys_reg_in,
    input  wire [31:0] alu2_result_in,

    input  wire        alu3_valid_in,
    input  wire [ROB_PTR_W-1:0] alu3_rob_idx_in,
    input  wire [5:0]  alu3_phys_reg_in,
    input  wire [31:0] alu3_result_in,

    // FROM BPU (combinational)
    input  wire        bpu_valid_in,
    input  wire [ROB_PTR_W-1:0] bpu_rob_idx_in,
    input  wire [5:0]  bpu_phys_reg_in,
    input  wire [31:0] bpu_result_in,
    input  wire        bpu_mispredict_in,
    input  wire [31:0] bpu_correct_pc_in,

    // FROM MUL (pipelined multiplier output)
    input  wire        mul_valid_in,
    input  wire [ROB_PTR_W-1:0] mul_rob_idx_in,
    input  wire [5:0]  mul_phys_reg_in,
    input  wire [31:0] mul_result_in,

    // FROM AGU (combinational)
    input  wire        agu_valid_in,
    input  wire [LSQ_PTR_W-1:0] agu_lsq_idx_in,
    input  wire [31:0] agu_addr_in,
    input  wire [31:0] agu_store_data_in,
    input  wire        agu_data_valid_in,

    // ================================================================
    // TO CDB / ROB / LSQ (registered)
    // ================================================================
    output reg         alu0_valid_out,
    output reg  [ROB_PTR_W-1:0] alu0_rob_idx_out,
    output reg  [5:0]  alu0_phys_reg_out,
    output reg  [31:0] alu0_result_out,

    output reg         alu1_valid_out,
    output reg  [ROB_PTR_W-1:0] alu1_rob_idx_out,
    output reg  [5:0]  alu1_phys_reg_out,
    output reg  [31:0] alu1_result_out,

    output reg         alu2_valid_out,
    output reg  [ROB_PTR_W-1:0] alu2_rob_idx_out,
    output reg  [5:0]  alu2_phys_reg_out,
    output reg  [31:0] alu2_result_out,

    output reg         alu3_valid_out,
    output reg  [ROB_PTR_W-1:0] alu3_rob_idx_out,
    output reg  [5:0]  alu3_phys_reg_out,
    output reg  [31:0] alu3_result_out,

    output reg         bpu_valid_out,
    output reg  [ROB_PTR_W-1:0] bpu_rob_idx_out,
    output reg  [5:0]  bpu_phys_reg_out,
    output reg  [31:0] bpu_result_out,
    output reg         bpu_mispredict_out,
    output reg  [31:0] bpu_correct_pc_out,

    output reg         mul_valid_out,
    output reg  [ROB_PTR_W-1:0] mul_rob_idx_out,
    output reg  [5:0]  mul_phys_reg_out,
    output reg  [31:0] mul_result_out,

    output reg         agu_valid_out,
    output reg  [LSQ_PTR_W-1:0] agu_lsq_idx_out,
    output reg  [31:0] agu_addr_out,
    output reg  [31:0] agu_store_data_out,
    output reg         agu_data_valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            alu0_valid_out     <= 1'b0;
            alu0_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu0_phys_reg_out  <= 6'd0;
            alu0_result_out    <= 32'd0;

            alu1_valid_out     <= 1'b0;
            alu1_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu1_phys_reg_out  <= 6'd0;
            alu1_result_out    <= 32'd0;

            alu2_valid_out     <= 1'b0;
            alu2_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu2_phys_reg_out  <= 6'd0;
            alu2_result_out    <= 32'd0;

            alu3_valid_out     <= 1'b0;
            alu3_rob_idx_out   <= {ROB_PTR_W{1'b0}};
            alu3_phys_reg_out  <= 6'd0;
            alu3_result_out    <= 32'd0;

            bpu_valid_out      <= 1'b0;
            bpu_rob_idx_out    <= {ROB_PTR_W{1'b0}};
            bpu_phys_reg_out   <= 6'd0;
            bpu_result_out     <= 32'd0;
            bpu_mispredict_out <= 1'b0;
            bpu_correct_pc_out <= 32'd0;

            mul_valid_out      <= 1'b0;
            mul_rob_idx_out    <= {ROB_PTR_W{1'b0}};
            mul_phys_reg_out   <= 6'd0;
            mul_result_out     <= 32'd0;

            agu_valid_out      <= 1'b0;
            agu_lsq_idx_out    <= {LSQ_PTR_W{1'b0}};
            agu_addr_out       <= 32'd0;
            agu_store_data_out <= 32'd0;
            agu_data_valid_out <= 1'b0;
        end
        else begin
            // ALU0
            alu0_valid_out     <= alu0_valid_in;
            alu0_rob_idx_out   <= alu0_rob_idx_in;
            alu0_phys_reg_out  <= alu0_phys_reg_in;
            alu0_result_out    <= alu0_result_in;
            // ALU1
            alu1_valid_out     <= alu1_valid_in;
            alu1_rob_idx_out   <= alu1_rob_idx_in;
            alu1_phys_reg_out  <= alu1_phys_reg_in;
            alu1_result_out    <= alu1_result_in;
            // ALU2
            alu2_valid_out     <= alu2_valid_in;
            alu2_rob_idx_out   <= alu2_rob_idx_in;
            alu2_phys_reg_out  <= alu2_phys_reg_in;
            alu2_result_out    <= alu2_result_in;
            // ALU3
            alu3_valid_out     <= alu3_valid_in;
            alu3_rob_idx_out   <= alu3_rob_idx_in;
            alu3_phys_reg_out  <= alu3_phys_reg_in;
            alu3_result_out    <= alu3_result_in;
            // BPU
            bpu_valid_out      <= bpu_valid_in;
            bpu_rob_idx_out    <= bpu_rob_idx_in;
            bpu_phys_reg_out   <= bpu_phys_reg_in;
            bpu_result_out     <= bpu_result_in;
            bpu_mispredict_out <= bpu_mispredict_in;
            bpu_correct_pc_out <= bpu_correct_pc_in;
            // MUL
            mul_valid_out      <= mul_valid_in;
            mul_rob_idx_out    <= mul_rob_idx_in;
            mul_phys_reg_out   <= mul_phys_reg_in;
            mul_result_out     <= mul_result_in;
            // AGU
            agu_valid_out      <= agu_valid_in;
            agu_lsq_idx_out    <= agu_lsq_idx_in;
            agu_addr_out       <= agu_addr_in;
            agu_store_data_out <= agu_store_data_in;
            agu_data_valid_out <= agu_data_valid_in;
        end
    end

endmodule
