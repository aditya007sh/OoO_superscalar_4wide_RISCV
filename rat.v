module RAT(
    input clk,
    input rst,
    
    // ========== INPUTS FROM DECODE STAGE ==========
    input [19:0] rd,
    input [19:0] rs1,
    input [19:0] rs2,
    input [3:0] rs1_valid,
    input [3:0] rs2_valid,
    input [3:0] rd_valid,
    input [23:0] alloc_phys_rd,
    
    // ========== INPUTS FROM ROB COMMIT (for RRAT, 4-wide) ==========
    input [3:0]  commit_valid,
    input [19:0] commit_arch_rd,
    input [23:0] commit_phys_rd,
    input [3:0]  commit_rd_valid,
    
    // ========== FLUSH (from ROB) ==========
    input        flush,
    
    // ========== OUTPUTS TO DISPATCH STAGE ==========
    output wire [23:0] phys_rs1,
    output wire [23:0] phys_rs2,
    output wire [23:0] phys_rd,
    output wire [23:0] old_phys_reg,
    output wire [3:0] rd_valid_at_rename,
    output wire [191:0] rat_debug
);

    // ========== RAT TABLE (speculative) ==========
    reg [5:0] rat_table [31:0];
    
    // ========== RRAT TABLE (committed / architectural) ==========
    reg [5:0] rrat_table [31:0];
    
    // ========== UNPACK DESTINATION REGISTERS ==========
    wire [4:0] rd_0, rd_1, rd_2, rd_3;
    assign rd_0 = rd[4:0];
    assign rd_1 = rd[9:5];
    assign rd_2 = rd[14:10];
    assign rd_3 = rd[19:15];
    
    // ========== UNPACK SOURCE1 REGISTERS ==========
    wire [4:0] rs1_0, rs1_1, rs1_2, rs1_3;
    assign rs1_0 = rs1[4:0];
    assign rs1_1 = rs1[9:5];
    assign rs1_2 = rs1[14:10];
    assign rs1_3 = rs1[19:15];
    
    // ========== UNPACK SOURCE2 REGISTERS ==========
    wire [4:0] rs2_0, rs2_1, rs2_2, rs2_3;
    assign rs2_0 = rs2[4:0];
    assign rs2_1 = rs2[9:5];
    assign rs2_2 = rs2[14:10];
    assign rs2_3 = rs2[19:15];
    
    // ========== UNPACK ALLOCATED PHYSICAL REGISTERS ==========
    wire [5:0] alloc_phys_rd_0, alloc_phys_rd_1, alloc_phys_rd_2, alloc_phys_rd_3;
    assign alloc_phys_rd_0 = alloc_phys_rd[5:0];
    assign alloc_phys_rd_1 = alloc_phys_rd[11:6];
    assign alloc_phys_rd_2 = alloc_phys_rd[17:12];
    assign alloc_phys_rd_3 = alloc_phys_rd[23:18];
    
    // ========== COMBINATORIAL: SOURCE1 LOOKUPS ==========
    wire [5:0] phys_rs1_0, phys_rs1_1, phys_rs1_2, phys_rs1_3;
    assign phys_rs1_0 = (rs1_valid[0]) ? rat_table[rs1_0] : 6'b0;
    assign phys_rs1_1 = (rs1_valid[1]) ? rat_table[rs1_1] : 6'b0;
    assign phys_rs1_2 = (rs1_valid[2]) ? rat_table[rs1_2] : 6'b0;
    assign phys_rs1_3 = (rs1_valid[3]) ? rat_table[rs1_3] : 6'b0;
    
    // ========== COMBINATORIAL: SOURCE2 LOOKUPS ==========
    wire [5:0] phys_rs2_0, phys_rs2_1, phys_rs2_2, phys_rs2_3;
    assign phys_rs2_0 = (rs2_valid[0]) ? rat_table[rs2_0] : 6'b0;
    assign phys_rs2_1 = (rs2_valid[1]) ? rat_table[rs2_1] : 6'b0;
    assign phys_rs2_2 = (rs2_valid[2]) ? rat_table[rs2_2] : 6'b0;
    assign phys_rs2_3 = (rs2_valid[3]) ? rat_table[rs2_3] : 6'b0;
    
    // ========== COMBINATORIAL: OLD PHYSICAL REGISTERS ==========
    wire [5:0] old_phys_reg_0, old_phys_reg_1, old_phys_reg_2, old_phys_reg_3;
    assign old_phys_reg_0 = (rd_valid[0]) ? rat_table[rd_0] : 6'b0;
    assign old_phys_reg_1 = (rd_valid[1]) ? rat_table[rd_1] : 6'b0;
    assign old_phys_reg_2 = (rd_valid[2]) ? rat_table[rd_2] : 6'b0;
    assign old_phys_reg_3 = (rd_valid[3]) ? rat_table[rd_3] : 6'b0;
    
    // ========== PACK OUTPUTS ==========
    assign phys_rs1 = {phys_rs1_3, phys_rs1_2, phys_rs1_1, phys_rs1_0};
    assign phys_rs2 = {phys_rs2_3, phys_rs2_2, phys_rs2_1, phys_rs2_0};
    assign phys_rd = alloc_phys_rd;
    assign old_phys_reg = {old_phys_reg_3, old_phys_reg_2, old_phys_reg_1, old_phys_reg_0};
    assign rd_valid_at_rename = rd_valid;
    
    // ========== UNPACK COMMIT CHANNELS ==========
    wire [4:0] c_arch_rd [0:3];
    wire [5:0] c_phys_rd [0:3];
    assign c_arch_rd[0] = commit_arch_rd[4:0];
    assign c_arch_rd[1] = commit_arch_rd[9:5];
    assign c_arch_rd[2] = commit_arch_rd[14:10];
    assign c_arch_rd[3] = commit_arch_rd[19:15];
    assign c_phys_rd[0] = commit_phys_rd[5:0];
    assign c_phys_rd[1] = commit_phys_rd[11:6];
    assign c_phys_rd[2] = commit_phys_rd[17:12];
    assign c_phys_rd[3] = commit_phys_rd[23:18];

    // ========== SEQUENTIAL: RAT + RRAT UPDATES ==========
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rat_table[i]  <= i[5:0];
                rrat_table[i] <= i[5:0];
            end
        end
        else begin
            // ===== RRAT UPDATE (4-wide): later slots win on WAW =====
            if (commit_valid[0] && commit_rd_valid[0] && c_arch_rd[0] != 5'b0)
                rrat_table[c_arch_rd[0]] <= c_phys_rd[0];
            if (commit_valid[1] && commit_rd_valid[1] && c_arch_rd[1] != 5'b0)
                rrat_table[c_arch_rd[1]] <= c_phys_rd[1];
            if (commit_valid[2] && commit_rd_valid[2] && c_arch_rd[2] != 5'b0)
                rrat_table[c_arch_rd[2]] <= c_phys_rd[2];
            if (commit_valid[3] && commit_rd_valid[3] && c_arch_rd[3] != 5'b0)
                rrat_table[c_arch_rd[3]] <= c_phys_rd[3];
            
            // ===== FLUSH: restore RAT from RRAT =====
            if (flush) begin
                for (i = 0; i < 32; i = i + 1)
                    rat_table[i] <= rrat_table[i];
                // Apply all committing instruction mappings directly
                // (RRAT NBA hasn't taken effect yet, last NBA wins)
                if (commit_valid[0] && commit_rd_valid[0] && c_arch_rd[0] != 5'b0)
                    rat_table[c_arch_rd[0]] <= c_phys_rd[0];
                if (commit_valid[1] && commit_rd_valid[1] && c_arch_rd[1] != 5'b0)
                    rat_table[c_arch_rd[1]] <= c_phys_rd[1];
                if (commit_valid[2] && commit_rd_valid[2] && c_arch_rd[2] != 5'b0)
                    rat_table[c_arch_rd[2]] <= c_phys_rd[2];
                if (commit_valid[3] && commit_rd_valid[3] && c_arch_rd[3] != 5'b0)
                    rat_table[c_arch_rd[3]] <= c_phys_rd[3];
            end
            // ===== NORMAL: speculative RAT update =====
            else begin
                if (rd_valid[0] && rd_0 != 5'b0)
                    rat_table[rd_0] <= alloc_phys_rd_0;
                if (rd_valid[1] && rd_1 != 5'b0)
                    rat_table[rd_1] <= alloc_phys_rd_1;
                if (rd_valid[2] && rd_2 != 5'b0)
                    rat_table[rd_2] <= alloc_phys_rd_2;
                if (rd_valid[3] && rd_3 != 5'b0)
                    rat_table[rd_3] <= alloc_phys_rd_3;
            end
            
            // PR0 safety net - always keep at 0
            rat_table[0]  <= 6'b0;
            rrat_table[0] <= 6'b0;
        end
    end
    
    // ========== DEBUG ==========
    assign rat_debug = {
        rat_table[31], rat_table[30], rat_table[29], rat_table[28],
        rat_table[27], rat_table[26], rat_table[25], rat_table[24],
        rat_table[23], rat_table[22], rat_table[21], rat_table[20],
        rat_table[19], rat_table[18], rat_table[17], rat_table[16],
        rat_table[15], rat_table[14], rat_table[13], rat_table[12],
        rat_table[11], rat_table[10], rat_table[9],  rat_table[8],
        rat_table[7],  rat_table[6],  rat_table[5],  rat_table[4],
        rat_table[3],  rat_table[2],  rat_table[1],  rat_table[0]
    };

endmodule
