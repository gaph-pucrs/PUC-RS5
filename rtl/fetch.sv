/*!\file fetch.sv
 * PUCRS-RV VERSION - 1.0 - Public Release
 *
 * Distribution:  September 2021
 *
 * Willian Nunes   <willian.nunes@edu.pucrs.br>
 * Marcos Sartori  <marcos.sartori@acad.pucrs.br>
 * Ney calazans    <ney.calazans@pucrs.br>
 *
 * Research group: GAPH-PUCRS  <>
 *
 * \brief
 * Fetch Unit is the first stage of the processor and fetch the instruction in memory.
 *
 * \detailed
 * Fetch Unit is the first stage of the PUCRS-RV processor. It has an
 * internal loop that contains the Program Counter(pc) that is increased by four 
 * on a new clock cycle or is replaced by a new address in case of a branch. 
 * It has a internal tag calculator that is increased in branchs and mantained
 * in regular flows, the tag leaves the unit with the instruction fetched.
 */

module fetch  #(parameter start_address='0)(  //Generic start address
    input   logic           clk,
    input   logic           reset,
    input   logic           stall,

    input   logic           hazard_i,
    input   logic           jump_i,
    input   logic [31:0]    jump_target_i,
    
    output  logic [31:0]    instruction_address_o,
    output  logic [31:0]    pc_o,
    output  logic [2:0]     tag_o,

    input   logic [31:0]    mtvec_i,
    input   logic [31:0]    mepc_i,
    input   logic           exception_raised_i,
    input   logic           machine_return_i,
    input   logic           interrupt_ack_i
);

    logic [31:0] pc, pc_plus4;
    logic [2:0] next_tag, current_tag;

//////////////////////////////////////////////////////////////////////////////
// PC Control
//////////////////////////////////////////////////////////////////////////////

    always @(posedge clk) begin
        if (reset) begin
            pc <= start_address;
        end
        else if (machine_return_i == 1) begin                              
            pc <= mepc_i;
        end
        else if (exception_raised_i == 1 || interrupt_ack_i == 1) begin                               
            pc <= mtvec_i;
        end
        else if (jump_i == 1) begin
            pc <= jump_target_i;
        end
        else if (hazard_i == 0 && stall == 0) begin
            pc <= pc_plus4;
        end
    end

    assign pc_plus4 = pc + 4;

//////////////////////////////////////////////////////////////////////////////
// Sensitive Outputs 
//////////////////////////////////////////////////////////////////////////////

    always @(posedge clk) begin
        if(hazard_i == 0 && stall == 0) begin
            pc_o <= pc;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// Non-Sensitive Outputs 
//////////////////////////////////////////////////////////////////////////////

    assign instruction_address_o = pc;
    assign tag_o = current_tag;

//////////////////////////////////////////////////////////////////////////////
// TAG Calculator 
//////////////////////////////////////////////////////////////////////////////

    always @(posedge clk) begin
        if (reset) begin
            current_tag <= 0;
            next_tag <= 0;
        end
        else if (jump_i == 1 || exception_raised_i == 1 || machine_return_i == 1 || interrupt_ack_i == 1) begin
            next_tag <= current_tag + 1;
        end
        else if (hazard_i == 0 && stall == 0) begin
            current_tag <= next_tag;
        end

    end

endmodule
