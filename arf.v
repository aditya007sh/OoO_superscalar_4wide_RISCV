module ARF (
    input  wire        clk,
    input  wire        rst,

    // PORT A - COMMIT WRITE (from ROB, 4-wide)
    input  wire [3:0]  commit_valid,
    input  wire [3:0]  commit_rd_valid,
    input  wire [19:0] commit_arch_rd,
    input  wire [23:0] commit_phys_rd,
    input  wire [127:0] commit_result,

    // PORT B - RAT RESTORE (shadow RAT output, always valid)
    output wire [191:0] arch_to_phys_out,

    // PORT C - DEBUG READ PORTS
    input  wire [4:0]  dbg_rd_addr0,
    output wire [31:0] dbg_rd_data0,
    input  wire [4:0]  dbg_rd_addr1,
    output wire [31:0] dbg_rd_data1,
    output wire [1023:0] dbg_regfile_dump,
    output wire [191:0]  dbg_rat_dump
);

    // STORAGE
    reg [31:0] arch_val      [0:31];
    reg [5:0]  arch_to_phys_r[0:31];

    // Unpack commit channels
    wire [4:0]  c_arch_rd [0:3];
    wire [5:0]  c_phys_rd [0:3];
    wire [31:0] c_result  [0:3];

    assign c_arch_rd[0] = commit_arch_rd[4:0];
    assign c_arch_rd[1] = commit_arch_rd[9:5];
    assign c_arch_rd[2] = commit_arch_rd[14:10];
    assign c_arch_rd[3] = commit_arch_rd[19:15];

    assign c_phys_rd[0] = commit_phys_rd[5:0];
    assign c_phys_rd[1] = commit_phys_rd[11:6];
    assign c_phys_rd[2] = commit_phys_rd[17:12];
    assign c_phys_rd[3] = commit_phys_rd[23:18];

    assign c_result[0] = commit_result[31:0];
    assign c_result[1] = commit_result[63:32];
    assign c_result[2] = commit_result[95:64];
    assign c_result[3] = commit_result[127:96];

    // SEQUENTIAL WRITE - 4-wide commit port
    // Later slots in program order win on WAW (slot 3 > slot 2 > slot 1 > slot 0)
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                arch_val      [i] <= 32'b0;
                arch_to_phys_r[i] <= i[5:0];
            end
            arch_val      [0] <= 32'b0;
            arch_to_phys_r[0] <= 6'b0;
        end else begin
            // Write in program order: slot 0 first, slot 3 last (last write wins on WAW)
            if (commit_valid[0] && commit_rd_valid[0] && c_arch_rd[0] != 5'b0) begin
                arch_val      [c_arch_rd[0]] <= c_result[0];
                arch_to_phys_r[c_arch_rd[0]] <= c_phys_rd[0];
            end
            if (commit_valid[1] && commit_rd_valid[1] && c_arch_rd[1] != 5'b0) begin
                arch_val      [c_arch_rd[1]] <= c_result[1];
                arch_to_phys_r[c_arch_rd[1]] <= c_phys_rd[1];
            end
            if (commit_valid[2] && commit_rd_valid[2] && c_arch_rd[2] != 5'b0) begin
                arch_val      [c_arch_rd[2]] <= c_result[2];
                arch_to_phys_r[c_arch_rd[2]] <= c_phys_rd[2];
            end
            if (commit_valid[3] && commit_rd_valid[3] && c_arch_rd[3] != 5'b0) begin
                arch_val      [c_arch_rd[3]] <= c_result[3];
                arch_to_phys_r[c_arch_rd[3]] <= c_phys_rd[3];
            end
        end
    end

    // COMBINATORIAL OUTPUTS
    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : PACK_SHADOW_RAT
            assign arch_to_phys_out[g*6 +: 6] = arch_to_phys_r[g];
        end
    endgenerate

    assign dbg_rd_data0 = arch_val[dbg_rd_addr0];
    assign dbg_rd_data1 = arch_val[dbg_rd_addr1];

    generate
        for (g = 0; g < 32; g = g + 1) begin : PACK_REGFILE
            assign dbg_regfile_dump[g*32 +: 32] = arch_val[g];
        end
    endgenerate

    assign dbg_rat_dump = arch_to_phys_out;

endmodule
