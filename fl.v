module Freelist(
    input clk,
    input rst,
    
    input alloc_stall,          // gate allocation when decode is stalled (rob_full, iq_full, flush)
    input [3:0] rd_valid,
    
    input [3:0] dealloc_en,
    input [23:0] old_phys_reg,
    input [3:0] rd_valid_at_rename,
    
    input [3:0]  flush_free_valid,
    input [23:0] flush_free_phys_rd,
    
    output wire [23:0] alloc_phys_rd,
    output reg full,
    output wire [63:0] bitmap_debug
);

    reg [63:0] bitmap;
    
    wire [5:0] old_phys_reg_0, old_phys_reg_1, old_phys_reg_2, old_phys_reg_3;
    assign old_phys_reg_0 = old_phys_reg[5:0];
    assign old_phys_reg_1 = old_phys_reg[11:6];
    assign old_phys_reg_2 = old_phys_reg[17:12];
    assign old_phys_reg_3 = old_phys_reg[23:18];
    
    wire [5:0] flush_prf_0, flush_prf_1, flush_prf_2, flush_prf_3;
    assign flush_prf_0 = flush_free_phys_rd[5:0];
    assign flush_prf_1 = flush_free_phys_rd[11:6];
    assign flush_prf_2 = flush_free_phys_rd[17:12];
    assign flush_prf_3 = flush_free_phys_rd[23:18];
    
    reg [5:0] alloc_phys_rd_0, alloc_phys_rd_1, alloc_phys_rd_2, alloc_phys_rd_3;
    
    assign alloc_phys_rd = {alloc_phys_rd_3, alloc_phys_rd_2, alloc_phys_rd_1, alloc_phys_rd_0};
    
    wire [2:0] rd_count;
    assign rd_count = {2'b0, rd_valid[0]} + {2'b0, rd_valid[1]} + 
                      {2'b0, rd_valid[2]} + {2'b0, rd_valid[3]};
    
    // ========== PRIORITY ENCODERS ==========
    wire [5:0] free_reg_0, free_reg_1, free_reg_2, free_reg_3;
    wire found_0, found_1, found_2, found_3;
    
    priority_encoder pe0(
        .bitmap(bitmap), 
        .reg_num(free_reg_0), 
        .found(found_0)
    );
    
    wire [63:0] bitmap_masked_1;
    assign bitmap_masked_1 = bitmap & ~(64'b1 << free_reg_0);
    priority_encoder pe1(
        .bitmap(bitmap_masked_1), 
        .reg_num(free_reg_1), 
        .found(found_1)
    );
    
    wire [63:0] bitmap_masked_2;
    assign bitmap_masked_2 = bitmap_masked_1 & ~(64'b1 << free_reg_1);
    priority_encoder pe2(
        .bitmap(bitmap_masked_2), 
        .reg_num(free_reg_2), 
        .found(found_2)
    );
    
    wire [63:0] bitmap_masked_3;
    assign bitmap_masked_3 = bitmap_masked_2 & ~(64'b1 << free_reg_2);
    priority_encoder pe3(
        .bitmap(bitmap_masked_3), 
        .reg_num(free_reg_3), 
        .found(found_3)
    );
    
    // ========== ALLOCATION LOGIC ==========
    integer alloc_idx;

    always @(*) begin
        // FIX #2: Use encoder found signals instead of 64-bit popcount
        case(rd_count)
            3'd0:    full = 1'b0;
            3'd1:    full = !found_0;
            3'd2:    full = !(found_0 && found_1);
            3'd3:    full = !(found_0 && found_1 && found_2);
            3'd4:    full = !(found_0 && found_1 && found_2 && found_3);
            default: full = 1'b1;
        endcase
        
        alloc_phys_rd_0 = 6'b0;
        alloc_phys_rd_1 = 6'b0;
        alloc_phys_rd_2 = 6'b0;
        alloc_phys_rd_3 = 6'b0;
        
        if(!full) begin
            alloc_idx = 0;
            
            if(rd_valid[0]) begin
                case(alloc_idx)
                    0: alloc_phys_rd_0 = free_reg_0;
                    1: alloc_phys_rd_0 = free_reg_1;
                    2: alloc_phys_rd_0 = free_reg_2;
                    3: alloc_phys_rd_0 = free_reg_3;
                endcase
                alloc_idx = alloc_idx + 1;
            end
            
            if(rd_valid[1]) begin
                case(alloc_idx)
                    0: alloc_phys_rd_1 = free_reg_0;
                    1: alloc_phys_rd_1 = free_reg_1;
                    2: alloc_phys_rd_1 = free_reg_2;
                    3: alloc_phys_rd_1 = free_reg_3;
                endcase
                alloc_idx = alloc_idx + 1;
            end
            
            if(rd_valid[2]) begin
                case(alloc_idx)
                    0: alloc_phys_rd_2 = free_reg_0;
                    1: alloc_phys_rd_2 = free_reg_1;
                    2: alloc_phys_rd_2 = free_reg_2;
                    3: alloc_phys_rd_2 = free_reg_3;
                endcase
                alloc_idx = alloc_idx + 1;
            end
            
            if(rd_valid[3]) begin
                case(alloc_idx)
                    0: alloc_phys_rd_3 = free_reg_0;
                    1: alloc_phys_rd_3 = free_reg_1;
                    2: alloc_phys_rd_3 = free_reg_2;
                    3: alloc_phys_rd_3 = free_reg_3;
                endcase
                alloc_idx = alloc_idx + 1;
            end
        end
    end
    
    // ========== UPDATE BITMAP ==========
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bitmap <= 64'hFFFFFFFF00000000;
        end
        else begin
            // COMMIT DEALLOCATION
            if(dealloc_en[0] && rd_valid_at_rename[0] && old_phys_reg_0 != 6'b0)
                bitmap[old_phys_reg_0] <= 1'b1;
            if(dealloc_en[1] && rd_valid_at_rename[1] && old_phys_reg_1 != 6'b0)
                bitmap[old_phys_reg_1] <= 1'b1;
            if(dealloc_en[2] && rd_valid_at_rename[2] && old_phys_reg_2 != 6'b0)
                bitmap[old_phys_reg_2] <= 1'b1;
            if(dealloc_en[3] && rd_valid_at_rename[3] && old_phys_reg_3 != 6'b0)
                bitmap[old_phys_reg_3] <= 1'b1;
            
            // FLUSH DEALLOCATION
            if(flush_free_valid[0] && flush_prf_0 != 6'b0)
                bitmap[flush_prf_0] <= 1'b1;
            if(flush_free_valid[1] && flush_prf_1 != 6'b0)
                bitmap[flush_prf_1] <= 1'b1;
            if(flush_free_valid[2] && flush_prf_2 != 6'b0)
                bitmap[flush_prf_2] <= 1'b1;
            if(flush_free_valid[3] && flush_prf_3 != 6'b0)
                bitmap[flush_prf_3] <= 1'b1;
            
            // ALLOCATION
            // ALLOCATION - only when not stalled and not full
            if(!full && !alloc_stall) begin
                if(rd_valid[0] && alloc_phys_rd_0 != 6'b0) bitmap[alloc_phys_rd_0] <= 1'b0;  // FIX #3: defensive
                if(rd_valid[1] && alloc_phys_rd_1 != 6'b0) bitmap[alloc_phys_rd_1] <= 1'b0;
                if(rd_valid[2] && alloc_phys_rd_2 != 6'b0) bitmap[alloc_phys_rd_2] <= 1'b0;
                if(rd_valid[3] && alloc_phys_rd_3 != 6'b0) bitmap[alloc_phys_rd_3] <= 1'b0;
            end
            
            // FIX #4: PR0 safety net - always keep allocated
            bitmap[0] <= 1'b0;
        end
    end
    
    assign bitmap_debug = bitmap;

endmodule


// ========================================
// PRIORITY ENCODER - Finds lowest index '1' bit
// ========================================
module priority_encoder(
    input [63:0] bitmap,      // 1=free, 0=allocated
    output reg [5:0] reg_num, // Register number of first free register found
    output reg found          // At least one free register found
);
    integer i;
    always @(*) begin
        found = 1'b0;
        reg_num = 6'b0;
        
        // Find first (lowest index) '1' in bitmap
        for( i = 0; i < 64; i=i+1) begin
            if(bitmap[i] && !found) begin
                reg_num = i;
                found = 1'b1;
            end
        end
    end
endmodule
