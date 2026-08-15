// ============================================================================
// 3-Stage Pipelined Multiplier (RV32M: MUL, MULH, MULHSU, MULHU)
// ============================================================================
// Latency  : 3 cycles
// Throughput: 1 instruction per cycle (fully pipelined)
//
// funct3 encoding:
//   3'b000 = MUL     → rd = (rs1 * rs2)[31:0]         (lower, sign irrelevant)
//   3'b001 = MULH    → rd = (signed(rs1) * signed(rs2))[63:32]
//   3'b010 = MULHSU  → rd = (signed(rs1) * unsigned(rs2))[63:32]
//   3'b011 = MULHU   → rd = (unsigned(rs1) * unsigned(rs2))[63:32]
// ============================================================================
module pipelined_multiplier #(
    parameter ROB_PTR_W = 6
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,

    // From IQ/EX buffer
    input  wire        valid_in,
    input  wire [7:0]  seq_num_in,     // ROB index
    input  wire [2:0]  funct3_in,
    input  wire [5:0]  phys_rd_in,
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,

    // To EX/WB buffer (after 3 cycles)
    output reg         valid_out,
    output reg  [ROB_PTR_W-1:0] rob_idx_out,
    output reg  [5:0]  phys_reg_out,
    output reg  [31:0] result_out,

    // Backpressure (always ready - fully pipelined)
    output wire        ready
);

    assign ready = 1'b1;  // Always accept new instructions

    // ================================================================
    // STAGE 1: Compute full 64-bit product
    // ================================================================
    reg        s1_valid;
    reg [7:0]  s1_seq_num;
    reg [2:0]  s1_funct3;
    reg [5:0]  s1_phys_rd;
    reg [63:0] s1_product;

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            s1_valid    <= 1'b0;
            s1_seq_num  <= 8'd0;
            s1_funct3   <= 3'd0;
            s1_phys_rd  <= 6'd0;
            s1_product  <= 64'd0;
        end else begin
            s1_valid   <= valid_in;
            s1_seq_num <= seq_num_in;
            s1_funct3  <= funct3_in;
            s1_phys_rd <= phys_rd_in;

            // Compute product based on signedness
            case (funct3_in)
                3'b000:  // MUL (lower 32-bit, sign doesn't matter for lower bits)
                    s1_product <= $signed(rs1_val) * $signed(rs2_val);
                3'b001:  // MULH (signed × signed)
                    s1_product <= $signed({{32{rs1_val[31]}}, rs1_val}) * $signed({{32{rs2_val[31]}}, rs2_val});
                3'b010:  // MULHSU (signed × unsigned)
                    s1_product <= $signed({{32{rs1_val[31]}}, rs1_val}) * $signed({32'b0, rs2_val});
                3'b011:  // MULHU (unsigned × unsigned)
                    s1_product <= {32'b0, rs1_val} * {32'b0, rs2_val};
                default:
                    s1_product <= 64'd0;
            endcase
        end
    end

    // ================================================================
    // STAGE 2: Pipeline register (lets Vivado split across DSP stages)
    // ================================================================
    reg        s2_valid;
    reg [7:0]  s2_seq_num;
    reg [2:0]  s2_funct3;
    reg [5:0]  s2_phys_rd;
    reg [63:0] s2_product;

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            s2_valid    <= 1'b0;
            s2_seq_num  <= 8'd0;
            s2_funct3   <= 3'd0;
            s2_phys_rd  <= 6'd0;
            s2_product  <= 64'd0;
        end else begin
            s2_valid   <= s1_valid;
            s2_seq_num <= s1_seq_num;
            s2_funct3  <= s1_funct3;
            s2_phys_rd <= s1_phys_rd;
            s2_product <= s1_product;
        end
    end

    // ================================================================
    // STAGE 3: Select result half and output
    // ================================================================
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            valid_out    <= 1'b0;
            rob_idx_out  <= {ROB_PTR_W{1'b0}};
            phys_reg_out <= 6'd0;
            result_out   <= 32'd0;
        end else begin
            valid_out    <= s2_valid;
            rob_idx_out  <= s2_seq_num[ROB_PTR_W-1:0];
            phys_reg_out <= s2_phys_rd;

            // Select lower or upper 32 bits based on funct3
            case (s2_funct3)
                3'b000:  result_out <= s2_product[31:0];   // MUL  → lower
                default: result_out <= s2_product[63:32];  // MULH/MULHSU/MULHU → upper
            endcase
        end
    end

endmodule
