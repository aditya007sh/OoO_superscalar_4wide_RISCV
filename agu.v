module AGU #( parameter LSQ_PTR_W = 5 )(
    input wire valid_in,
    input wire [LSQ_PTR_W-1:0] lsq_idx_in,
    input wire [31:0] rs1_val,
    input wire [31:0] rs2_val,
    input wire rs2_ready,
    input wire [31:0] imm,
    input wire [2:0] funct3,
    input wire is_load,
    input wire is_store,

    output wire agu_wb_valid,
    output wire [LSQ_PTR_W-1:0] agu_wb_lsq_idx,
    output wire [31:0] agu_wb_addr,
    output wire [31:0] agu_wb_store_data,
    output wire agu_wb_data_valid
);

assign agu_wb_valid = valid_in && (is_load || is_store);
assign agu_wb_lsq_idx = lsq_idx_in;
assign agu_wb_addr = rs1_val + imm;
assign agu_wb_store_data = rs2_val;
assign agu_wb_data_valid = valid_in && is_store && rs2_ready;

endmodule
