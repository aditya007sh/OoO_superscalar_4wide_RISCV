module fetch_stage_top(
    input clk,
    input rst,
    input enable_pc,
    input queue_pop,
    input stall_in,            // ← NEW: from if_id_buffer stall

    input flush,
    input redirect_valid,
    input [31:0] redirect_pc,

    output [31:0] pc_current,
    output [31:0] pc_iq_out,           // ← NEW: base PC from IQ (matches popped instructions)
    output [31:0] inst0, inst1, inst2, inst3,
    output [3:0]  valid_inst,
    output queue_full,
    output queue_empty
);

    wire [31:0] pc_next, pc_out;
    wire [31:0] imem_inst1, imem_inst2, imem_inst3, imem_inst4;
    wire [31:0] imem_addr_out;  // PC passed through IMEM
    wire [31:0] pd_inst1,   pd_inst2,   pd_inst3,   pd_inst4;
    wire [31:0] pd_pc_out;
    wire [3:0]  pd_valid;

    // Gate everything on stall
    wire fetch_enable = (enable_pc && !stall_in) || redirect_valid;
    wire pop_enable   = queue_pop && !stall_in;
    wire queue_push   = enable_pc && !queue_full && !flush && !stall_in;

    wire stall_fetch  = queue_full && !redirect_valid;

    assign pc_next = redirect_valid ? redirect_pc :
                     stall_fetch    ? pc_out       :
                                     pd_pc_out;

    wire [31:0] fetch_addr = redirect_valid ? redirect_pc : pc_out;

    PC pc_reg (
        .clk(clk),
        .rst(rst),
        .enable(fetch_enable),
        .pc_in(pc_next),
        .pc_out(pc_out)
    );

    assign pc_current = pc_out;

    INSTRUCTION_MEMORY imem (
        .address(pc_out),
        .instruction_out1(imem_inst1),
        .instruction_out2(imem_inst2),
        .instruction_out3(imem_inst3),
        .instruction_out4(imem_inst4),
        .address_out(imem_addr_out)
    );

    PD_and_BP pd_bp (
        .pc(imem_addr_out),
        .inst1(imem_inst1), .inst2(imem_inst2),
        .inst3(imem_inst3), .inst4(imem_inst4),
        .inst1_out(pd_inst1), .inst2_out(pd_inst2),
        .inst3_out(pd_inst3), .inst4_out(pd_inst4),
        .pc_out(pd_pc_out),
        .valid_inst(pd_valid)
    );

    instruction_queue iqueue (
        .clk(clk), .rst(rst),
        .flush(flush),
        .ins0(pd_inst1), .ins1(pd_inst2),
        .ins2(pd_inst3), .ins3(pd_inst4),
        .pc_in(pc_out),            // ← NEW: store fetch PC with bundle
        .valid(pd_valid),
        .push(queue_push),
        .pop(pop_enable),          // ← gated pop
        .ins0_out(inst0), .ins1_out(inst1),
        .ins2_out(inst2), .ins3_out(inst3),
        .pc_out(pc_iq_out),        // ← NEW: output PC with bundle
        .valid_out(valid_inst),
        .full(queue_full),
        .empty(queue_empty)
    );

endmodule
