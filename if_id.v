module if_id_buffer (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,          // from backend misprediction
    input  wire        stall,          // from decode (freelist full, ROB full, etc.)

    // ================================================================
    // FROM FETCH STAGE
    // ================================================================
    input  wire [31:0] pc_in,          // PC of first instruction in bundle
    input  wire [31:0] inst0_in,
    input  wire [31:0] inst1_in,
    input  wire [31:0] inst2_in,
    input  wire [31:0] inst3_in,
    input  wire [3:0]  valid_in,

    // ================================================================
    // TO DECODE STAGE
    // ================================================================
    output reg  [31:0] pc0_out,        // PC for each instruction
    output reg  [31:0] pc1_out,
    output reg  [31:0] pc2_out,
    output reg  [31:0] pc3_out,
    output reg  [31:0] inst0_out,
    output reg  [31:0] inst1_out,
    output reg  [31:0] inst2_out,
    output reg  [31:0] inst3_out,
    output reg  [3:0]  valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            pc0_out   <= 32'd0;
            pc1_out   <= 32'd0;
            pc2_out   <= 32'd0;
            pc3_out   <= 32'd0;
            inst0_out <= 32'h00000013;  // NOP on flush/reset
            inst1_out <= 32'h00000013;
            inst2_out <= 32'h00000013;
            inst3_out <= 32'h00000013;
            valid_out <= 4'b0000;
        end
        else if (!stall) begin
            // Per-instruction PCs: base + 0, +4, +8, +12
            pc0_out   <= pc_in;
            pc1_out   <= pc_in + 32'd4;
            pc2_out   <= pc_in + 32'd8;
            pc3_out   <= pc_in + 32'd12;
            inst0_out <= inst0_in;
            inst1_out <= inst1_in;
            inst2_out <= inst2_in;
            inst3_out <= inst3_in;
            valid_out <= valid_in;
        end
        // else: stall - hold current values
    end

endmodule
