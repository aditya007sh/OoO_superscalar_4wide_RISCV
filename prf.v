/*module PRF (
    input  wire        clk,
    input  wire        rst,

    // WRITE PORTS - 6 CDB sources
    input  wire        cdb_fu0_valid,
    input  wire [5:0]  cdb_fu0_phys_reg,
    input  wire [31:0] cdb_fu0_value,

    input  wire        cdb_fu1_valid,
    input  wire [5:0]  cdb_fu1_phys_reg,
    input  wire [31:0] cdb_fu1_value,

    input  wire        cdb_fu2_valid,
    input  wire [5:0]  cdb_fu2_phys_reg,
    input  wire [31:0] cdb_fu2_value,

    input  wire        cdb_fu3_valid,
    input  wire [5:0]  cdb_fu3_phys_reg,
    input  wire [31:0] cdb_fu3_value,

    input  wire        cdb_bpu_valid,
    input  wire [5:0]  cdb_bpu_phys_reg,
    input  wire [31:0] cdb_bpu_value,

    input  wire        cdb_lsq_valid,
    input  wire [5:0]  cdb_lsq_phys_reg,
    input  wire [31:0] cdb_lsq_value,

    // READ PORTS
    input  wire [5:0]  bpu_phys_rs1,
    input  wire [5:0]  bpu_phys_rs2,
    output wire [31:0] bpu_rs1_val,
    output wire [31:0] bpu_rs2_val,

    input  wire [5:0]  fu0_phys_rs1,
    input  wire [5:0]  fu0_phys_rs2,
    output wire [31:0] fu0_rs1_val,
    output wire [31:0] fu0_rs2_val,

    input  wire [5:0]  fu1_phys_rs1,
    input  wire [5:0]  fu1_phys_rs2,
    output wire [31:0] fu1_rs1_val,
    output wire [31:0] fu1_rs2_val,

    input  wire [5:0]  fu2_phys_rs1,
    input  wire [5:0]  fu2_phys_rs2,
    output wire [31:0] fu2_rs1_val,
    output wire [31:0] fu2_rs2_val,

    input  wire [5:0]  fu3_phys_rs1,
    input  wire [5:0]  fu3_phys_rs2,
    output wire [31:0] fu3_rs1_val,
    output wire [31:0] fu3_rs2_val,

    input  wire [5:0]  agu_phys_rs1,
    input  wire [5:0]  agu_phys_rs2,
    output wire [31:0] agu_rs1_val,
    output wire [31:0] agu_rs2_val,
    output wire        agu_rs2_ready
);

    reg [31:0] prf [0:63];
    reg [63:0] prf_valid;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1)
                prf[i] <= 32'b0;
            prf_valid <= 64'h00000000_FFFFFFFF;  // FIX: PR0-31 valid at reset
        end else begin
            if (cdb_fu0_valid && cdb_fu0_phys_reg != 6'd0) begin
                prf[cdb_fu0_phys_reg] <= cdb_fu0_value;
                prf_valid[cdb_fu0_phys_reg] <= 1'b1;
            end
            if (cdb_fu1_valid && cdb_fu1_phys_reg != 6'd0) begin
                prf[cdb_fu1_phys_reg] <= cdb_fu1_value;
                prf_valid[cdb_fu1_phys_reg] <= 1'b1;
            end
            if (cdb_fu2_valid && cdb_fu2_phys_reg != 6'd0) begin
                prf[cdb_fu2_phys_reg] <= cdb_fu2_value;
                prf_valid[cdb_fu2_phys_reg] <= 1'b1;
            end
            if (cdb_fu3_valid && cdb_fu3_phys_reg != 6'd0) begin
                prf[cdb_fu3_phys_reg] <= cdb_fu3_value;
                prf_valid[cdb_fu3_phys_reg] <= 1'b1;
            end
            if (cdb_bpu_valid && cdb_bpu_phys_reg != 6'd0) begin
                prf[cdb_bpu_phys_reg] <= cdb_bpu_value;
                prf_valid[cdb_bpu_phys_reg] <= 1'b1;
            end
            if (cdb_lsq_valid && cdb_lsq_phys_reg != 6'd0) begin
                prf[cdb_lsq_phys_reg] <= cdb_lsq_value;
                prf_valid[cdb_lsq_phys_reg] <= 1'b1;
            end
        end
    end

    function automatic [31:0] forward_val;
        input [5:0] addr;
        begin
            if (addr == 6'd0)
                forward_val = 32'b0;
            else if (cdb_fu0_valid && cdb_fu0_phys_reg == addr)
                forward_val = cdb_fu0_value;
            else if (cdb_fu1_valid && cdb_fu1_phys_reg == addr)
                forward_val = cdb_fu1_value;
            else if (cdb_fu2_valid && cdb_fu2_phys_reg == addr)
                forward_val = cdb_fu2_value;
            else if (cdb_fu3_valid && cdb_fu3_phys_reg == addr)
                forward_val = cdb_fu3_value;
            else if (cdb_bpu_valid && cdb_bpu_phys_reg == addr)
                forward_val = cdb_bpu_value;
            else if (cdb_lsq_valid && cdb_lsq_phys_reg == addr)
                forward_val = cdb_lsq_value;
            else
                forward_val = prf[addr];
        end
    endfunction

    assign bpu_rs1_val = forward_val(bpu_phys_rs1);
    assign bpu_rs2_val = forward_val(bpu_phys_rs2);
    assign fu0_rs1_val = forward_val(fu0_phys_rs1);
    assign fu0_rs2_val = forward_val(fu0_phys_rs2);
    assign fu1_rs1_val = forward_val(fu1_phys_rs1);
    assign fu1_rs2_val = forward_val(fu1_phys_rs2);
    assign fu2_rs1_val = forward_val(fu2_phys_rs1);
    assign fu2_rs2_val = forward_val(fu2_phys_rs2);
    assign fu3_rs1_val = forward_val(fu3_phys_rs1);
    assign fu3_rs2_val = forward_val(fu3_phys_rs2);
    assign agu_rs1_val = forward_val(agu_phys_rs1);
    assign agu_rs2_val = forward_val(agu_phys_rs2);

    assign agu_rs2_ready =
        (agu_phys_rs2 == 6'd0) ? 1'b1 : prf_valid[agu_phys_rs2];

endmodule
*/
module PRF (
    input  wire        clk,
    input  wire        rst,

    // WRITE PORTS - 6 CDB sources
    input  wire        cdb_fu0_valid,
    input  wire [5:0]  cdb_fu0_phys_reg,
    input  wire [31:0] cdb_fu0_value,

    input  wire        cdb_fu1_valid,
    input  wire [5:0]  cdb_fu1_phys_reg,
    input  wire [31:0] cdb_fu1_value,

    input  wire        cdb_fu2_valid,
    input  wire [5:0]  cdb_fu2_phys_reg,
    input  wire [31:0] cdb_fu2_value,

    input  wire        cdb_fu3_valid,
    input  wire [5:0]  cdb_fu3_phys_reg,
    input  wire [31:0] cdb_fu3_value,

    input  wire        cdb_bpu_valid,
    input  wire [5:0]  cdb_bpu_phys_reg,
    input  wire [31:0] cdb_bpu_value,

    input  wire        cdb_lsq_valid,
    input  wire [5:0]  cdb_lsq_phys_reg,
    input  wire [31:0] cdb_lsq_value,

    input  wire        cdb_mul_valid,
    input  wire [5:0]  cdb_mul_phys_reg,
    input  wire [31:0] cdb_mul_value,

    // READ PORTS
    input  wire [5:0]  bpu_phys_rs1,
    input  wire [5:0]  bpu_phys_rs2,
    output wire [31:0] bpu_rs1_val,
    output wire [31:0] bpu_rs2_val,

    input  wire [5:0]  fu0_phys_rs1,
    input  wire [5:0]  fu0_phys_rs2,
    output wire [31:0] fu0_rs1_val,
    output wire [31:0] fu0_rs2_val,

    input  wire [5:0]  fu1_phys_rs1,
    input  wire [5:0]  fu1_phys_rs2,
    output wire [31:0] fu1_rs1_val,
    output wire [31:0] fu1_rs2_val,

    input  wire [5:0]  fu2_phys_rs1,
    input  wire [5:0]  fu2_phys_rs2,
    output wire [31:0] fu2_rs1_val,
    output wire [31:0] fu2_rs2_val,

    input  wire [5:0]  fu3_phys_rs1,
    input  wire [5:0]  fu3_phys_rs2,
    output wire [31:0] fu3_rs1_val,
    output wire [31:0] fu3_rs2_val,

    input  wire [5:0]  agu_phys_rs1,
    input  wire [5:0]  agu_phys_rs2,
    output wire [31:0] agu_rs1_val,
    output wire [31:0] agu_rs2_val,
    output wire        agu_rs2_ready,

    input  wire [5:0]  mul_phys_rs1,
    input  wire [5:0]  mul_phys_rs2,
    output wire [31:0] mul_rs1_val,
    output wire [31:0] mul_rs2_val
);

    reg [31:0] prf [0:63];
    reg [63:0] prf_valid;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1)
                prf[i] <= 32'b0;
            prf_valid <= 64'h00000000_FFFFFFFF;  // FIX: PR0-31 valid at reset
        end else begin
            if (cdb_fu0_valid && cdb_fu0_phys_reg != 6'd0) begin
                prf[cdb_fu0_phys_reg] <= cdb_fu0_value;
                prf_valid[cdb_fu0_phys_reg] <= 1'b1;
            end
            if (cdb_fu1_valid && cdb_fu1_phys_reg != 6'd0) begin
                prf[cdb_fu1_phys_reg] <= cdb_fu1_value;
                prf_valid[cdb_fu1_phys_reg] <= 1'b1;
            end
            if (cdb_fu2_valid && cdb_fu2_phys_reg != 6'd0) begin
                prf[cdb_fu2_phys_reg] <= cdb_fu2_value;
                prf_valid[cdb_fu2_phys_reg] <= 1'b1;
            end
            if (cdb_fu3_valid && cdb_fu3_phys_reg != 6'd0) begin
                prf[cdb_fu3_phys_reg] <= cdb_fu3_value;
                prf_valid[cdb_fu3_phys_reg] <= 1'b1;
            end
            if (cdb_bpu_valid && cdb_bpu_phys_reg != 6'd0) begin
                prf[cdb_bpu_phys_reg] <= cdb_bpu_value;
                prf_valid[cdb_bpu_phys_reg] <= 1'b1;
            end
            if (cdb_lsq_valid && cdb_lsq_phys_reg != 6'd0) begin
                prf[cdb_lsq_phys_reg] <= cdb_lsq_value;
                prf_valid[cdb_lsq_phys_reg] <= 1'b1;
            end
            if (cdb_mul_valid && cdb_mul_phys_reg != 6'd0) begin
                prf[cdb_mul_phys_reg] <= cdb_mul_value;
                prf_valid[cdb_mul_phys_reg] <= 1'b1;
            end
        end
    end

    function automatic [31:0] forward_val;
        input [5:0] addr;
        begin
            if (addr == 6'd0)
                forward_val = 32'b0;
            else if (cdb_fu0_valid && cdb_fu0_phys_reg == addr)
                forward_val = cdb_fu0_value;
            else if (cdb_fu1_valid && cdb_fu1_phys_reg == addr)
                forward_val = cdb_fu1_value;
            else if (cdb_fu2_valid && cdb_fu2_phys_reg == addr)
                forward_val = cdb_fu2_value;
            else if (cdb_fu3_valid && cdb_fu3_phys_reg == addr)
                forward_val = cdb_fu3_value;
            else if (cdb_bpu_valid && cdb_bpu_phys_reg == addr)
                forward_val = cdb_bpu_value;
            else if (cdb_lsq_valid && cdb_lsq_phys_reg == addr)
                forward_val = cdb_lsq_value;
            else if (cdb_mul_valid && cdb_mul_phys_reg == addr)
                forward_val = cdb_mul_value;
            else
                forward_val = prf[addr];
        end
    endfunction

    assign bpu_rs1_val = forward_val(bpu_phys_rs1);
    assign bpu_rs2_val = forward_val(bpu_phys_rs2);
    assign fu0_rs1_val = forward_val(fu0_phys_rs1);
    assign fu0_rs2_val = forward_val(fu0_phys_rs2);
    assign fu1_rs1_val = forward_val(fu1_phys_rs1);
    assign fu1_rs2_val = forward_val(fu1_phys_rs2);
    assign fu2_rs1_val = forward_val(fu2_phys_rs1);
    assign fu2_rs2_val = forward_val(fu2_phys_rs2);
    assign fu3_rs1_val = forward_val(fu3_phys_rs1);
    assign fu3_rs2_val = forward_val(fu3_phys_rs2);
    assign agu_rs1_val = forward_val(agu_phys_rs1);
    assign agu_rs2_val = forward_val(agu_phys_rs2);

    assign mul_rs1_val = forward_val(mul_phys_rs1);
    assign mul_rs2_val = forward_val(mul_phys_rs2);

    assign agu_rs2_ready =
        (agu_phys_rs2 == 6'd0) ? 1'b1 : prf_valid[agu_phys_rs2];//store location available or not
        

endmodule
