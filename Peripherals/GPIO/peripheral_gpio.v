`define WIDTH 31:0
`define ZEROWORD 32'h0
// GPIO
module GPIO (
clk, reset, address_in, data_in, data_out, write_enable_in, pins
);

// input and output from bus slave
input clk, reset, write_enable_in;
input [`WIDTH] data_in, address_in;
output reg [`WIDTH] data_out;

// gpio peripheral pins
inout [1:0] pins ; // considering 2 pins, pin could act as both input and output

// register map
localparam address_ctrl = 4'h0, address_data = 4'h4;
reg [31:0] data, ctrl;

// asynchronous read
always @(*) begin

    if(reset == 1'b1) data_out =  `ZEROWORD;
    else begin
        if(address_in[3:0] == address_ctrl) data_out = ctrl;
            else if (address_in[3:0] == address_data) data_out = data;
        else data_out = `ZEROWORD;
    end
end

// synchronous write
always @(posedge clk) begin

    if(reset == 1'b1) begin
        ctrl <= `ZEROWORD;
        data <= `ZEROWORD;
    end
    else begin
        if(write_enable_in == 1'b1) begin

            case(address_in[3:0])
               address_ctrl : ctrl <= data_in;
               address_data : data <= data_in;
            endcase
        end
        else begin
            // for my pin0
            if(ctrl[1:0] == 2'b10 ) data[0] <= pins[0];
            if(ctrl[3:2] == 2'b10 ) data[1] <= pins[1];

        end
    end
end
// output assignment cuz my inout out is not a register
assign pins[0] = (ctrl[1]==1'b1) ? (ctrl[0] == 1'b1 ? data[0] : 1'bz )  : (1'bz) ;
assign pins[1] = (ctrl[3]==1'b1) ? (ctrl[2] == 1'b1 ? data[1] : 1'bz )  : (1'bz) ;


endmodule
