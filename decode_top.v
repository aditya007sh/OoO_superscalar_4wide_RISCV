/*    module Decode_Top (
        input clk,
        input rst,

        // ============================================================
        // FROM FETCH STAGE
        // ============================================================
        input [31:0] ins0_in,
        input [31:0] ins1_in,
        input [31:0] ins2_in,
        input [31:0] ins3_in,
        input [3:0]  fetch_valid,

        // ============================================================
        // FROM COMMIT STAGE (ROB → Freelist deallocation)
        // ============================================================
        input [3:0]  dealloc_en,
        input [23:0] old_phys_reg_commit,
        input [3:0]  rd_valid_at_commit,    // ← FIX: separate signal from ROB

        // ============================================================
        // FROM ROB COMMIT (for RRAT, 4-wide)
        // ============================================================
        input [3:0]  commit_valid,
        input [19:0] commit_arch_rd,
        input [23:0] commit_phys_rd,
        input [3:0]  commit_rd_valid,

        // ============================================================
        // FROM ROB FLUSH
        // ============================================================
        input        flush,
        input [3:0]  flush_free_valid,
        input [23:0] flush_free_phys_rd,
        
        input wire rob_full,
        input wire iq_full,

        // ============================================================
        // DECODED INSTRUCTION FIELDS (to Issue Queue / ROB)
        // ============================================================
        output [4:0]  ins0_rs1, output [4:0]  ins0_rs2, output [4:0]  ins0_rd,
        output [31:0] ins0_imm, output [6:0]  ins0_opcode,
        output [2:0]  ins0_funct3, output [6:0]  ins0_funct7,
        output ins0_is_alu, output ins0_is_load, output ins0_is_store,
        output ins0_is_branch, output ins0_is_jal, output ins0_is_jalr,
        output ins0_is_lui, output ins0_is_auipc,

        output [4:0]  ins1_rs1, output [4:0]  ins1_rs2, output [4:0]  ins1_rd,
        output [31:0] ins1_imm, output [6:0]  ins1_opcode,
        output [2:0]  ins1_funct3, output [6:0]  ins1_funct7,
        output ins1_is_alu, output ins1_is_load, output ins1_is_store,
        output ins1_is_branch, output ins1_is_jal, output ins1_is_jalr,
        output ins1_is_lui, output ins1_is_auipc,

        output [4:0]  ins2_rs1, output [4:0]  ins2_rs2, output [4:0]  ins2_rd,
        output [31:0] ins2_imm, output [6:0]  ins2_opcode,
        output [2:0]  ins2_funct3, output [6:0]  ins2_funct7,
        output ins2_is_alu, output ins2_is_load, output ins2_is_store,
        output ins2_is_branch, output ins2_is_jal, output ins2_is_jalr,
        output ins2_is_lui, output ins2_is_auipc,

        output [4:0]  ins3_rs1, output [4:0]  ins3_rs2, output [4:0]  ins3_rd,
        output [31:0] ins3_imm, output [6:0]  ins3_opcode,
        output [2:0]  ins3_funct3, output [6:0]  ins3_funct7,
        output ins3_is_alu, output ins3_is_load, output ins3_is_store,
        output ins3_is_branch, output ins3_is_jal, output ins3_is_jalr,
        output ins3_is_lui, output ins3_is_auipc,

        // ============================================================
        // RENAMED PHYSICAL REGISTER BUNDLE (to Issue Queue / ROB)
        // ============================================================
        output [23:0] phys_rs1_out,
        output [23:0] phys_rs2_out,
        output [23:0] phys_rd_out,
        output [23:0] old_phys_reg_out,

        // ============================================================
        // VALIDITY / CONTROL OUTPUTS
        // ============================================================
        output [3:0]  rd_valid_out,
        output [3:0]  rs1_valid_out,
        output [3:0]  rs2_valid_out,
        output [3:0]  rd_valid_at_rename_out,
        output [3:0]  valid_out,
        output        stall_out,
        
        input [31:0] pc0_in, pc1_in, pc2_in, pc3_in,
        output [31:0] pc0_out, pc1_out, pc2_out, pc3_out,

        // ============================================================
        // DEBUG OUTPUTS
        // ============================================================
        output [63:0]  freelist_bitmap_debug,
        output [191:0] rat_debug
    );

        // ============================================================
        // PC PASSTHROUGH
        // ============================================================
        assign pc0_out = pc0_in;
        assign pc1_out = pc1_in;
        assign pc2_out = pc2_in;
        assign pc3_out = pc3_in;

        // ============================================================
        // INTERNAL WIRES
        // ============================================================
        wire dec_ins0_rs1_valid, dec_ins0_rs2_valid, dec_ins0_rd_valid;
        wire dec_ins1_rs1_valid, dec_ins1_rs2_valid, dec_ins1_rd_valid;
        wire dec_ins2_rs1_valid, dec_ins2_rs2_valid, dec_ins2_rd_valid;
        wire dec_ins3_rs1_valid, dec_ins3_rs2_valid, dec_ins3_rd_valid;

        wire [19:0] packed_rd  = {ins3_rd,  ins2_rd,  ins1_rd,  ins0_rd};
        wire [19:0] packed_rs1 = {ins3_rs1, ins2_rs1, ins1_rs1, ins0_rs1};
        wire [19:0] packed_rs2 = {ins3_rs2, ins2_rs2, ins1_rs2, ins0_rs2};

        wire [3:0] packed_rd_valid  = {dec_ins3_rd_valid,  dec_ins2_rd_valid,  dec_ins1_rd_valid,  dec_ins0_rd_valid};
        wire [3:0] packed_rs1_valid = {dec_ins3_rs1_valid, dec_ins2_rs1_valid, dec_ins1_rs1_valid, dec_ins0_rs1_valid};
        wire [3:0] packed_rs2_valid = {dec_ins3_rs2_valid, dec_ins2_rs2_valid, dec_ins1_rs2_valid, dec_ins0_rs2_valid};

        wire [23:0] alloc_phys_rd;
        wire        freelist_full;

        // FIX #1: stall_out includes ALL downstream stall sources
        assign stall_out = freelist_full || rob_full || iq_full;

        // FIX #2: Gate rd_valid for RAT/Rename when stalled OR flushing
        // Does NOT include freelist_full to avoid combinational loop
        // (freelist's own !full guard handles that case)
        wire [3:0] rd_valid_gated = (rob_full || iq_full || flush || freelist_full) ? 4'b0 : packed_rd_valid;

        wire [23:0] rat_phys_rs1;
        wire [23:0] rat_phys_rs2;
        wire [23:0] rat_old_phys_reg;
        wire [3:0]  rat_rd_valid_at_rename;

        // ============================================================
        // INSTANCE 1: DECODE_4WIDE
        // ============================================================
        Decode_4Wide u_decode (
            .ins0_in(ins0_in), .ins1_in(ins1_in), .ins2_in(ins2_in), .ins3_in(ins3_in),
            .valid_in(fetch_valid),

            .ins0_rs1(ins0_rs1), .ins0_rs2(ins0_rs2), .ins0_rd(ins0_rd), .ins0_imm(ins0_imm),
            .ins0_rs1_valid(dec_ins0_rs1_valid), .ins0_rs2_valid(dec_ins0_rs2_valid), .ins0_rd_valid(dec_ins0_rd_valid),
            .ins0_opcode(ins0_opcode), .ins0_funct3(ins0_funct3), .ins0_funct7(ins0_funct7),
            .ins0_is_alu(ins0_is_alu), .ins0_is_load(ins0_is_load), .ins0_is_store(ins0_is_store),
            .ins0_is_branch(ins0_is_branch), .ins0_is_jal(ins0_is_jal), .ins0_is_jalr(ins0_is_jalr),
            .ins0_is_lui(ins0_is_lui), .ins0_is_auipc(ins0_is_auipc),

            .ins1_rs1(ins1_rs1), .ins1_rs2(ins1_rs2), .ins1_rd(ins1_rd), .ins1_imm(ins1_imm),
            .ins1_rs1_valid(dec_ins1_rs1_valid), .ins1_rs2_valid(dec_ins1_rs2_valid), .ins1_rd_valid(dec_ins1_rd_valid),
            .ins1_opcode(ins1_opcode), .ins1_funct3(ins1_funct3), .ins1_funct7(ins1_funct7),
            .ins1_is_alu(ins1_is_alu), .ins1_is_load(ins1_is_load), .ins1_is_store(ins1_is_store),
            .ins1_is_branch(ins1_is_branch), .ins1_is_jal(ins1_is_jal), .ins1_is_jalr(ins1_is_jalr),
            .ins1_is_lui(ins1_is_lui), .ins1_is_auipc(ins1_is_auipc),

            .ins2_rs1(ins2_rs1), .ins2_rs2(ins2_rs2), .ins2_rd(ins2_rd), .ins2_imm(ins2_imm),
            .ins2_rs1_valid(dec_ins2_rs1_valid), .ins2_rs2_valid(dec_ins2_rs2_valid), .ins2_rd_valid(dec_ins2_rd_valid),
            .ins2_opcode(ins2_opcode), .ins2_funct3(ins2_funct3), .ins2_funct7(ins2_funct7),
            .ins2_is_alu(ins2_is_alu), .ins2_is_load(ins2_is_load), .ins2_is_store(ins2_is_store),
            .ins2_is_branch(ins2_is_branch), .ins2_is_jal(ins2_is_jal), .ins2_is_jalr(ins2_is_jalr),
            .ins2_is_lui(ins2_is_lui), .ins2_is_auipc(ins2_is_auipc),

            .ins3_rs1(ins3_rs1), .ins3_rs2(ins3_rs2), .ins3_rd(ins3_rd), .ins3_imm(ins3_imm),
            .ins3_rs1_valid(dec_ins3_rs1_valid), .ins3_rs2_valid(dec_ins3_rs2_valid), .ins3_rd_valid(dec_ins3_rd_valid),
            .ins3_opcode(ins3_opcode), .ins3_funct3(ins3_funct3), .ins3_funct7(ins3_funct7),
            .ins3_is_alu(ins3_is_alu), .ins3_is_load(ins3_is_load), .ins3_is_store(ins3_is_store),
            .ins3_is_branch(ins3_is_branch), .ins3_is_jal(ins3_is_jal), .ins3_is_jalr(ins3_is_jalr),
            .ins3_is_lui(ins3_is_lui), .ins3_is_auipc(ins3_is_auipc),

            .valid_out(valid_out)
        );

        // ============================================================
        // INSTANCE 2: FREELIST
        // ============================================================
        Freelist u_freelist (
            .clk               (clk),
            .rst               (rst),
            .alloc_stall       (rob_full || iq_full || flush),  // FIX #3: gate allocation on external stalls
            .rd_valid          (packed_rd_valid),                // raw for full computation (no comb loop)
            .dealloc_en        (dealloc_en),
            .old_phys_reg      (old_phys_reg_commit),
            .rd_valid_at_rename(rd_valid_at_commit),             // FIX #4: use ROB's saved rd_valid
            .flush_free_valid  (flush_free_valid),
            .flush_free_phys_rd(flush_free_phys_rd),
            .alloc_phys_rd     (alloc_phys_rd),
            .full              (freelist_full),
            .bitmap_debug      (freelist_bitmap_debug)
        );

        // ============================================================
        // INSTANCE 3: RAT (with RRAT)
        // ============================================================
        RAT u_rat (
            .clk               (clk),
            .rst               (rst),
            .rd                (packed_rd),
            .rs1               (packed_rs1),
            .rs2               (packed_rs2),
            .rs1_valid         (packed_rs1_valid),
            .rs2_valid         (packed_rs2_valid),
            .rd_valid          (rd_valid_gated),                 // gated: no RAT update during stall/flush
            .alloc_phys_rd     (alloc_phys_rd),
            .commit_valid      (commit_valid),
            .commit_arch_rd    (commit_arch_rd),
            .commit_phys_rd    (commit_phys_rd),
            .commit_rd_valid   (commit_rd_valid),
            .flush             (flush),
            .phys_rs1          (rat_phys_rs1),
            .phys_rs2          (rat_phys_rs2),
            .old_phys_reg      (rat_old_phys_reg),
            .rd_valid_at_rename(rat_rd_valid_at_rename),
            .rat_debug         (rat_debug)
        );

        // ============================================================
        // INSTANCE 4: RENAME_DISPATCH
        // ============================================================
        Rename_Dispatch u_rename (
            .rd                      (packed_rd),
            .rs1                     (packed_rs1),
            .rs2                     (packed_rs2),
            .rs1_valid               (packed_rs1_valid),
            .rs2_valid               (packed_rs2_valid),
            .rd_valid                (rd_valid_gated),            // gated: no forwarding for stalled insts
            .phys_rs1_rat            (rat_phys_rs1),
            .phys_rs2_rat            (rat_phys_rs2),
            .old_phys_reg_rat        (rat_old_phys_reg),
            .rd_valid_at_rename      (rat_rd_valid_at_rename),
            .alloc_phys_rd           (alloc_phys_rd),
            .freelist_full           (freelist_full),
            .phys_rs1_final          (phys_rs1_out),
            .phys_rs2_final          (phys_rs2_out),
            .phys_rd_final           (phys_rd_out),
            .old_phys_reg_final      (old_phys_reg_out),
            .rd_valid_final          (rd_valid_out),
            .rs1_valid_final         (rs1_valid_out),
            .rs2_valid_final         (rs2_valid_out),
            .rd_valid_at_rename_final(rd_valid_at_rename_out)
        );
    
    endmodule*/
    
        module Decode_Top (
        input clk,
        input rst,

        // ============================================================
        // FROM FETCH STAGE
        // ============================================================
        input [31:0] ins0_in,
        input [31:0] ins1_in,
        input [31:0] ins2_in,
        input [31:0] ins3_in,
        input [3:0]  fetch_valid,

        // ============================================================
        // FROM COMMIT STAGE (ROB → Freelist deallocation)
        // ============================================================
        input [3:0]  dealloc_en,
        input [23:0] old_phys_reg_commit,
        input [3:0]  rd_valid_at_commit,    // ← FIX: separate signal from ROB

        // ============================================================
        // FROM ROB COMMIT (for RRAT, 4-wide)
        // ============================================================
        input [3:0]  commit_valid,
        input [19:0] commit_arch_rd,
        input [23:0] commit_phys_rd,
        input [3:0]  commit_rd_valid,

        // ============================================================
        // FROM ROB FLUSH
        // ============================================================
        input        flush,
        input [3:0]  flush_free_valid,
        input [23:0] flush_free_phys_rd,
        
        input wire rob_full,
        input wire iq_full,

        // ============================================================
        // DECODED INSTRUCTION FIELDS (to Issue Queue / ROB)
        // ============================================================
        output [4:0]  ins0_rs1, output [4:0]  ins0_rs2, output [4:0]  ins0_rd,
        output [31:0] ins0_imm, output [6:0]  ins0_opcode,
        output [2:0]  ins0_funct3, output [6:0]  ins0_funct7,
        output ins0_is_alu, output ins0_is_mul, output ins0_is_load, output ins0_is_store,
        output ins0_is_branch, output ins0_is_jal, output ins0_is_jalr,
        output ins0_is_lui, output ins0_is_auipc,

        output [4:0]  ins1_rs1, output [4:0]  ins1_rs2, output [4:0]  ins1_rd,
        output [31:0] ins1_imm, output [6:0]  ins1_opcode,
        output [2:0]  ins1_funct3, output [6:0]  ins1_funct7,
        output ins1_is_alu, output ins1_is_mul, output ins1_is_load, output ins1_is_store,
        output ins1_is_branch, output ins1_is_jal, output ins1_is_jalr,
        output ins1_is_lui, output ins1_is_auipc,

        output [4:0]  ins2_rs1, output [4:0]  ins2_rs2, output [4:0]  ins2_rd,
        output [31:0] ins2_imm, output [6:0]  ins2_opcode,
        output [2:0]  ins2_funct3, output [6:0]  ins2_funct7,
        output ins2_is_alu, output ins2_is_mul, output ins2_is_load, output ins2_is_store,
        output ins2_is_branch, output ins2_is_jal, output ins2_is_jalr,
        output ins2_is_lui, output ins2_is_auipc,

        output [4:0]  ins3_rs1, output [4:0]  ins3_rs2, output [4:0]  ins3_rd,
        output [31:0] ins3_imm, output [6:0]  ins3_opcode,
        output [2:0]  ins3_funct3, output [6:0]  ins3_funct7,
        output ins3_is_alu, output ins3_is_mul, output ins3_is_load, output ins3_is_store,
        output ins3_is_branch, output ins3_is_jal, output ins3_is_jalr,
        output ins3_is_lui, output ins3_is_auipc,

        // ============================================================
        // RENAMED PHYSICAL REGISTER BUNDLE (to Issue Queue / ROB)
        // ============================================================
        output [23:0] phys_rs1_out,
        output [23:0] phys_rs2_out,
        output [23:0] phys_rd_out,
        output [23:0] old_phys_reg_out,

        // ============================================================
        // VALIDITY / CONTROL OUTPUTS
        // ============================================================
        output [3:0]  rd_valid_out,
        output [3:0]  rs1_valid_out,
        output [3:0]  rs2_valid_out,
        output [3:0]  rd_valid_at_rename_out,
        output [3:0]  valid_out,
        output        stall_out,
        
        input [31:0] pc0_in, pc1_in, pc2_in, pc3_in,
        output [31:0] pc0_out, pc1_out, pc2_out, pc3_out,

        // ============================================================
        // DEBUG OUTPUTS
        // ============================================================
        output [63:0]  freelist_bitmap_debug,
        output [191:0] rat_debug
    );

        // ============================================================
        // PC PASSTHROUGH
        // ============================================================
        assign pc0_out = pc0_in;
        assign pc1_out = pc1_in;
        assign pc2_out = pc2_in;
        assign pc3_out = pc3_in;

        // ============================================================
        // INTERNAL WIRES
        // ============================================================
        wire dec_ins0_rs1_valid, dec_ins0_rs2_valid, dec_ins0_rd_valid;
        wire dec_ins1_rs1_valid, dec_ins1_rs2_valid, dec_ins1_rd_valid;
        wire dec_ins2_rs1_valid, dec_ins2_rs2_valid, dec_ins2_rd_valid;
        wire dec_ins3_rs1_valid, dec_ins3_rs2_valid, dec_ins3_rd_valid;

        wire [19:0] packed_rd  = {ins3_rd,  ins2_rd,  ins1_rd,  ins0_rd};
        wire [19:0] packed_rs1 = {ins3_rs1, ins2_rs1, ins1_rs1, ins0_rs1};
        wire [19:0] packed_rs2 = {ins3_rs2, ins2_rs2, ins1_rs2, ins0_rs2};

        wire [3:0] packed_rd_valid  = {dec_ins3_rd_valid,  dec_ins2_rd_valid,  dec_ins1_rd_valid,  dec_ins0_rd_valid};
        wire [3:0] packed_rs1_valid = {dec_ins3_rs1_valid, dec_ins2_rs1_valid, dec_ins1_rs1_valid, dec_ins0_rs1_valid};
        wire [3:0] packed_rs2_valid = {dec_ins3_rs2_valid, dec_ins2_rs2_valid, dec_ins1_rs2_valid, dec_ins0_rs2_valid};

        wire [23:0] alloc_phys_rd;
        wire        freelist_full;

        // FIX #1: stall_out includes ALL downstream stall sources
        assign stall_out = freelist_full || rob_full || iq_full;

        // FIX #2: Gate rd_valid for RAT/Rename when stalled OR flushing
        // Does NOT include freelist_full to avoid combinational loop
        // (freelist's own !full guard handles that case)
        wire [3:0] rd_valid_gated = (rob_full || iq_full || flush || freelist_full) ? 4'b0 : packed_rd_valid;

        wire [23:0] rat_phys_rs1;
        wire [23:0] rat_phys_rs2;
        wire [23:0] rat_old_phys_reg;
        wire [3:0]  rat_rd_valid_at_rename;

        // ============================================================
        // INSTANCE 1: DECODE_4WIDE
        // ============================================================
        Decode_4Wide u_decode (
            .ins0_in(ins0_in), .ins1_in(ins1_in), .ins2_in(ins2_in), .ins3_in(ins3_in),
            .valid_in(fetch_valid),

            .ins0_rs1(ins0_rs1), .ins0_rs2(ins0_rs2), .ins0_rd(ins0_rd), .ins0_imm(ins0_imm),
            .ins0_rs1_valid(dec_ins0_rs1_valid), .ins0_rs2_valid(dec_ins0_rs2_valid), .ins0_rd_valid(dec_ins0_rd_valid),
            .ins0_opcode(ins0_opcode), .ins0_funct3(ins0_funct3), .ins0_funct7(ins0_funct7),
            .ins0_is_alu(ins0_is_alu), .ins0_is_mul(ins0_is_mul), .ins0_is_load(ins0_is_load), .ins0_is_store(ins0_is_store),
            .ins0_is_branch(ins0_is_branch), .ins0_is_jal(ins0_is_jal), .ins0_is_jalr(ins0_is_jalr),
            .ins0_is_lui(ins0_is_lui), .ins0_is_auipc(ins0_is_auipc),

            .ins1_rs1(ins1_rs1), .ins1_rs2(ins1_rs2), .ins1_rd(ins1_rd), .ins1_imm(ins1_imm),
            .ins1_rs1_valid(dec_ins1_rs1_valid), .ins1_rs2_valid(dec_ins1_rs2_valid), .ins1_rd_valid(dec_ins1_rd_valid),
            .ins1_opcode(ins1_opcode), .ins1_funct3(ins1_funct3), .ins1_funct7(ins1_funct7),
            .ins1_is_alu(ins1_is_alu), .ins1_is_mul(ins1_is_mul), .ins1_is_load(ins1_is_load), .ins1_is_store(ins1_is_store),
            .ins1_is_branch(ins1_is_branch), .ins1_is_jal(ins1_is_jal), .ins1_is_jalr(ins1_is_jalr),
            .ins1_is_lui(ins1_is_lui), .ins1_is_auipc(ins1_is_auipc),

            .ins2_rs1(ins2_rs1), .ins2_rs2(ins2_rs2), .ins2_rd(ins2_rd), .ins2_imm(ins2_imm),
            .ins2_rs1_valid(dec_ins2_rs1_valid), .ins2_rs2_valid(dec_ins2_rs2_valid), .ins2_rd_valid(dec_ins2_rd_valid),
            .ins2_opcode(ins2_opcode), .ins2_funct3(ins2_funct3), .ins2_funct7(ins2_funct7),
            .ins2_is_alu(ins2_is_alu), .ins2_is_mul(ins2_is_mul), .ins2_is_load(ins2_is_load), .ins2_is_store(ins2_is_store),
            .ins2_is_branch(ins2_is_branch), .ins2_is_jal(ins2_is_jal), .ins2_is_jalr(ins2_is_jalr),
            .ins2_is_lui(ins2_is_lui), .ins2_is_auipc(ins2_is_auipc),

            .ins3_rs1(ins3_rs1), .ins3_rs2(ins3_rs2), .ins3_rd(ins3_rd), .ins3_imm(ins3_imm),
            .ins3_rs1_valid(dec_ins3_rs1_valid), .ins3_rs2_valid(dec_ins3_rs2_valid), .ins3_rd_valid(dec_ins3_rd_valid),
            .ins3_opcode(ins3_opcode), .ins3_funct3(ins3_funct3), .ins3_funct7(ins3_funct7),
            .ins3_is_alu(ins3_is_alu), .ins3_is_mul(ins3_is_mul), .ins3_is_load(ins3_is_load), .ins3_is_store(ins3_is_store),
            .ins3_is_branch(ins3_is_branch), .ins3_is_jal(ins3_is_jal), .ins3_is_jalr(ins3_is_jalr),
            .ins3_is_lui(ins3_is_lui), .ins3_is_auipc(ins3_is_auipc),

            .valid_out(valid_out)
        );

        // ============================================================
        // INSTANCE 2: FREELIST
        // ============================================================
        Freelist u_freelist (
            .clk               (clk),
            .rst               (rst),
            .alloc_stall       (rob_full || iq_full || flush),  // FIX #3: gate allocation on external stalls
            .rd_valid          (packed_rd_valid),                // raw for full computation (no comb loop)
            .dealloc_en        (dealloc_en),
            .old_phys_reg      (old_phys_reg_commit),
            .rd_valid_at_rename(rd_valid_at_commit),             // FIX #4: use ROB's saved rd_valid
            .flush_free_valid  (flush_free_valid),
            .flush_free_phys_rd(flush_free_phys_rd),
            .alloc_phys_rd     (alloc_phys_rd),
            .full              (freelist_full),
            .bitmap_debug      (freelist_bitmap_debug)
        );

        // ============================================================
        // INSTANCE 3: RAT (with RRAT)
        // ============================================================
        RAT u_rat (
            .clk               (clk),
            .rst               (rst),
            .rd                (packed_rd),
            .rs1               (packed_rs1),
            .rs2               (packed_rs2),
            .rs1_valid         (packed_rs1_valid),
            .rs2_valid         (packed_rs2_valid),
            .rd_valid          (rd_valid_gated),                 // gated: no RAT update during stall/flush
            .alloc_phys_rd     (alloc_phys_rd),
            .commit_valid      (commit_valid),
            .commit_arch_rd    (commit_arch_rd),
            .commit_phys_rd    (commit_phys_rd),
            .commit_rd_valid   (commit_rd_valid),
            .flush             (flush),
            .phys_rs1          (rat_phys_rs1),
            .phys_rs2          (rat_phys_rs2),
            .old_phys_reg      (rat_old_phys_reg),
            .rd_valid_at_rename(rat_rd_valid_at_rename),
            .rat_debug         (rat_debug)
        );

        // ============================================================
        // INSTANCE 4: RENAME_DISPATCH
        // ============================================================
        Rename_Dispatch u_rename (
            .rd                      (packed_rd),
            .rs1                     (packed_rs1),
            .rs2                     (packed_rs2),
            .rs1_valid               (packed_rs1_valid),
            .rs2_valid               (packed_rs2_valid),
            .rd_valid                (rd_valid_gated),            // gated: no forwarding for stalled insts
            .phys_rs1_rat            (rat_phys_rs1),
            .phys_rs2_rat            (rat_phys_rs2),
            .old_phys_reg_rat        (rat_old_phys_reg),
            .rd_valid_at_rename      (rat_rd_valid_at_rename),
            .alloc_phys_rd           (alloc_phys_rd),
            .freelist_full           (freelist_full),
            .phys_rs1_final          (phys_rs1_out),
            .phys_rs2_final          (phys_rs2_out),
            .phys_rd_final           (phys_rd_out),
            .old_phys_reg_final      (old_phys_reg_out),
            .rd_valid_final          (rd_valid_out),
            .rs1_valid_final         (rs1_valid_out),
            .rs2_valid_final         (rs2_valid_out),
            .rd_valid_at_rename_final(rd_valid_at_rename_out)
        );
    
    endmodule

