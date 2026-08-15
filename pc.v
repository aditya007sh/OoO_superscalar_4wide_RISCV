module PC(
input clk,
input rst,
input enable,// want this cuz when inst reservation station is filled , you dont want to move forward
input [31:0] pc_in,
output reg [31:0] pc_out

    );
    always @(posedge clk or posedge rst) //async 
    begin
    if(rst)
    pc_out<=32'b0;
    else if (enable)
    pc_out<=pc_in;// trying to include the pc value in mux
    end
    
    
endmodule
