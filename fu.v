module ALU #( parameter ROB_PTR_W = 6 )(
    // No clk/rst/flush - purely combinational now
    input wire valid_in,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [31:0] rs1_val,
    input wire [31:0] rs2_val,
    input wire [31:0] imm,
    input wire [7:0] seq_num,
    input wire [5:0] phys_rd,
    input wire [31:0] pc,

    output wire valid_out,
    output wire [ROB_PTR_W-1:0] rob_idx_out,
    output wire [5:0] phys_reg_out,
    output reg [31:0] result_out
);

localparam OP_R = 7'b0110011;
localparam OP_I = 7'b0010011;
localparam OP_LUI = 7'b0110111;
localparam OP_AUIPC = 7'b0010111;

wire is_r_type = (opcode == OP_R);
wire is_lui = (opcode == OP_LUI);
wire is_auipc = (opcode == OP_AUIPC);

wire [31:0] op_b = is_r_type ? rs2_val : imm;
wire sub_sra = is_r_type ? funct7[5] : imm[10];
wire [4:0] shamt = op_b[4:0];

// Passthrough - no register
assign valid_out = valid_in;
assign rob_idx_out = seq_num[ROB_PTR_W-1:0];
assign phys_reg_out = phys_rd;

always @(*) begin
    result_out = 32'd0;

    if (is_lui)
        result_out = imm;
    else if (is_auipc)
        result_out = pc + imm;
    else begin
        case (funct3)
            3'b000: result_out = (is_r_type && sub_sra) ? rs1_val - op_b : rs1_val + op_b;
            3'b001: result_out = rs1_val << shamt;
            3'b010: result_out = ($signed(rs1_val) < $signed(op_b)) ? 32'd1 : 32'd0;
            3'b011: result_out = (rs1_val < op_b) ? 32'd1 : 32'd0;
            3'b100: result_out = rs1_val ^ op_b;
            3'b101: begin
                if (sub_sra)
                    result_out = $signed(rs1_val) >>> shamt;
                else
                    result_out = rs1_val >> shamt;
            end
            3'b110: result_out = rs1_val | op_b;
            3'b111: result_out = rs1_val & op_b;
        endcase
    end
end

endmodule
