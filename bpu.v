module BPU #( parameter ROB_PTR_W = 6 )(
    input wire valid_in,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [31:0] rs1_val,
    input wire [31:0] rs2_val,
    input wire [31:0] imm,
    input wire [7:0] seq_num,
    input wire [5:0] phys_rd,
    input wire [31:0] pc,

    output wire valid_out,
    output wire [ROB_PTR_W-1:0] rob_idx_out,
    output wire [5:0] phys_reg_out,
    output reg [31:0] result_out,
    output reg mispredict_out,
    output reg [31:0] correct_pc_out
);

localparam OP_BRANCH = 7'b1100011;
localparam OP_JAL = 7'b1101111;
localparam OP_JALR = 7'b1100111;

wire is_branch = (opcode == OP_BRANCH);
wire is_jal = (opcode == OP_JAL);
wire is_jalr = (opcode == OP_JALR);

// Passthrough
assign valid_out = valid_in;
assign rob_idx_out = seq_num[ROB_PTR_W-1:0];
assign phys_reg_out = phys_rd;

reg branch_taken;

always @(*) begin
    branch_taken = 1'b0;

    if (valid_in && is_branch) begin
        case (funct3)
            3'b000: branch_taken = (rs1_val == rs2_val);
            3'b001: branch_taken = (rs1_val != rs2_val);
            3'b100: branch_taken = ($signed(rs1_val) < $signed(rs2_val));
            3'b101: branch_taken = ($signed(rs1_val) >= $signed(rs2_val));
            3'b110: branch_taken = (rs1_val < rs2_val);
            3'b111: branch_taken = (rs1_val >= rs2_val);
            default: branch_taken = 1'b0;
        endcase
    end
end

wire [31:0] branch_target = pc + imm;
wire [31:0] jalr_target = (rs1_val + imm) & 32'hFFFFFFFE;
wire [31:0] link_addr = pc + 32'd4;

always @(*) begin
    result_out = 32'd0;
    mispredict_out = 1'b0;
    correct_pc_out = 32'd0;

    if (valid_in) begin
        if (is_branch) begin
            // PD_and_BP predicts ALL branches as TAKEN
            if (branch_taken) begin
                mispredict_out = 1'b0;       // predicted taken, actually taken
                correct_pc_out = branch_target;
            end else begin
                mispredict_out = 1'b1;       // predicted taken, actually NOT taken
                correct_pc_out = link_addr;  // should go to pc+4
            end
        end else if (is_jal) begin
            result_out = link_addr;
            correct_pc_out = branch_target;  // PD_and_BP already redirected
        end else if (is_jalr) begin
            result_out = link_addr;
            mispredict_out = 1'b1;           // PD_and_BP can't predict JALR target
            correct_pc_out = jalr_target;
        end
    end
end

endmodule
