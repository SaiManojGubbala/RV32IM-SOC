`define WIDTH 31:0
`define ZEROWORD 32'h0
// timer module code
module TIMER(
clk, reset, write_enable_in, address_in, data_in, data_out, send_interrupt
);

// inputs/outputs from slave bus
input clk, reset, write_enable_in;
input [`WIDTH] address_in, data_in;
output reg [`WIDTH] data_out;

// timer outputs
output send_interrupt;

//REGISTER MAP 0 -> CTRL REGISTER 4 -> COUNT REGISTER 8 -> VALUE REGISTER
// CTRL REGISTER  CTRL[0] -> COUNTING IS PENDING / COUNTING IS COMPLETED
//                CTRL[1] -> COUNTER IS ENABLE OR DISABLE
//                CTRL[2] -> (DATA_IN[2] == 1 CLEAR COUNTER) ELSE LEAVE WHATEVER STATUS IT IS IN
localparam ctrl_address = 4'h0;
localparam count_address = 4'h4;
localparam value_address = 4'h8;

//REGISTERS
reg [`WIDTH] ctrl, count, value;

assign send_interrupt = ctrl[2] && ctrl[1] ; // my status says it's completed and my timer is enabled

// asynchronous read of data
always @(*) begin
    if(reset == 1'b1) data_out = `ZEROWORD;
    else begin
        case(address_in[3:0])

        ctrl_address : data_out = ctrl;
        count_address : data_out = count;
        value_address : data_out = value;

        endcase
    end
end

//synchronous write of data

always @(posedge clk) begin
    if(reset == 1'b1) begin
        ctrl <= `ZEROWORD;
        value <=`ZEROWORD;
    end
    else begin
        if(write_enable_in == 1'b1) begin
        if(address_in[3:0] == ctrl_address) ctrl <= {data_in[31:3],{ctrl[2] & ~data_in[2]},data_in[1:0]};
        else if(address_in[3:0] == value_address) value <= data_in;
        end
        else begin
            if(ctrl[0] == 1'b1 && count >= value ) begin
                ctrl[0] <= 1'b0;
                ctrl[2] <= 1'b1;
            end
        end
    end
end

// now i need to update my counter

always @(posedge clk) begin
    if(reset == 1'b1) count <= `ZEROWORD;
    else begin
        if(ctrl[1:0] == 2'b11 ) begin
         if(count < value)
             count <= count + 1'b1;
         else if (count >= value) begin
             count <= `ZEROWORD;
         end
        end
        else count <= `ZEROWORD;
    end
end

endmodule
