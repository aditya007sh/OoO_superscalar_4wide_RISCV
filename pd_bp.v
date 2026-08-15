module PD_and_BP(
input [31:0] pc,// we add immed value to this
input [31:0] inst1,inst2,inst3,inst4,

output [31:0] inst1_out,inst2_out,inst3_out,inst4_out,//inst to be given to fifo
output reg [31:0] pc_out,
output reg [3:0] valid_inst// while decoding we tell thru this about which insts out of 4 is valid
    );
    
    wire [6:0] opcode1,opcode2,opcode3,opcode4;
    
    assign opcode1=inst1[6:0];
    assign opcode2=inst2[6:0];
    assign opcode3=inst3[6:0];
    assign opcode4=inst4[6:0];
    
    wire branch1,branch2, branch3, branch4;
    
    assign branch1=(opcode1==7'b1100011);
    assign branch2=(opcode2==7'b1100011);
    assign branch3=(opcode3==7'b1100011);
    assign branch4=(opcode4==7'b1100011);
    
    wire jump1,jump2,jump3,jump4;
    
    assign jump1=(opcode1 == 7'b1101111);
    assign jump2=(opcode2 == 7'b1101111);
    assign jump3=(opcode3 == 7'b1101111);
    assign jump4=(opcode4 == 7'b1101111);
    
    wire jalr1,jalr2,jalr3,jalr4;
    
    assign jalr1=(opcode1 == 7'b1100111);
    assign jalr2=(opcode2 == 7'b1100111);
    assign jalr3=(opcode3 == 7'b1100111);
    assign jalr4=(opcode4 == 7'b1100111);
    
    function [31:0] branch_target;
    input [31:0] pc;
    input [31:0] inst;
    begin
    branch_target=pc+{{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};  
    end
    endfunction
    
    function [31:0] jump_target;
    input [31:0] pc;
    input [31:0] inst;
    begin
    jump_target=pc+{{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};  
    end
    endfunction
    
    //didnt include jalr for now, as idk about register through which data is accessed
    
    
    
    always @(*)
    begin
    if(branch1 || jump1)
    begin
    valid_inst=4'b0001;
    if(branch1)
    pc_out=branch_target(pc,inst1);
    else if(jump1)
    pc_out=jump_target(pc,inst1);
    
    end
    
    else if(branch2 || jump2) 
    begin
    valid_inst=4'b0011;    
    if (branch2)
    pc_out = branch_target(pc + 32'd4, inst2);
    else if (jump2)
    pc_out = jump_target(pc + 32'd4, inst2);
    end
    
    
    else if (branch3 || jump3) 
    begin
    valid_inst=4'b0111;
    if (branch3)
    pc_out = branch_target(pc + 32'd8, inst3);
    else if (jump3)
    pc_out = jump_target(pc + 32'd8, inst3);
    end
    
    else if (branch4 || jump4) 
    begin
    valid_inst=4'b1111;
    if (branch4)
    pc_out = branch_target(pc + 32'd12, inst4);
    else if (jump4)
    pc_out = jump_target(pc + 32'd12, inst4);
    end
    
    else
    begin
    pc_out=pc+ 32'd16;
    valid_inst=4'b1111;

    end
    end
    
    assign inst1_out=inst1;
    assign inst2_out=inst2;
    assign inst3_out=inst3;
    assign inst4_out=inst4;
    
    
endmodule
