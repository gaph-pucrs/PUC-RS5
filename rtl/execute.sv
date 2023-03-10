/*!\file execute.sv
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
 * Execute Unit is the fourth stage of the processor.
 *
 * \detailed
 * Execute Unit is the fourth stage of the PUCRS-RV processor. At the
 * entry it implements a dispatcher that assigns the operands only to the
 * module responsible for that kind of instruction, the modules are: 
 * 1) Adder 2) Branch 3) Bypass 4) Logic 5) Memory 6) Shift. Each module is
 * defined in a separeted file. These files must be included in this Unit
 * if not compiled separately. At the other end it has a demux that collects
 * the result only from the given module and BYPASS it to the next stage.
 */

import my_pkg::*;

module execute(
    input   logic          clk,
    input   logic          stall,

    input   logic [31:0]   instruction_i,
    input   logic [31:0]   pc_i,               // Operand from Operand Fetch stage
    input   logic [31:0]   first_operand_i,    //              ||
    input   logic [31:0]   second_operand_i,   //              ||
    input   logic [31:0]   third_operand_i,    //              ||
    input   iType_e        instruction_operation_i,
    input   logic [2:0]    tag_i,              // Instruction tag

    output  iType_e        instruction_operation_o,
    output  logic [31:0]   instruction_o,
    output  logic [31:0]   pc_o,
    output  logic [31:0]   result_o [1:0],     // Results array
    output  logic [2:0]    tag_o,              // Instruction tag
    output  logic          jump_o,             // Signal that indicates a branch taken
    output  logic          write_enable_o,     // Write enable to regbank

    output  logic [31:0]   mem_read_address_o, // Memory Read Address
    output  logic [3:0]    mem_write_enable_o, // Signal that indicates the write memory operation to retire
    output  logic          mem_read_o,         // Allows memory read

    output  logic          csr_read_enable_o,
    output  logic          csr_write_enable_o,
    output  csrOperation_e csr_operation_o,
    output  logic [11:0]   csr_address_o,
    output  logic [31:0]   csr_data_o,
    input   logic [31:0]   csr_data_read_i,

    input   logic          exception_i,
    output  logic          exception_o
);
    
    logic jump_int;
    logic write_enable_regbank_branch_unit, write_enable_regbank_memory_unit;
    logic csr_exception;
    logic [3:0] mem_write_enable_int;
    logic [31:0] results_int [7:0];

    operationType_e execution_unit_operation;
    executionUnit_e execution_unit_selector;

    assign execution_unit_selector = executionUnit_e'(instruction_operation_i[5:3]);
    assign execution_unit_operation = operationType_e'(instruction_operation_i[2:0]);

//////////////////////////////////////////////////////////////////////////////
// Instantiation of execution units
//////////////////////////////////////////////////////////////////////////////

    adderUnit adder1 (
        .first_operand_i(first_operand_i),
        .second_operand_i(second_operand_i),
        .operation_i(execution_unit_operation),
        .result_o(results_int[0])
    );

    logicUnit logical1 (
        .first_operand_i(first_operand_i),
        .second_operand_i(second_operand_i),
        .operation_i(execution_unit_operation),
        .result_o(results_int[1])
    );
    
    shiftUnit shift1 (
        .first_operand_i(first_operand_i),
        .second_operand_i(second_operand_i[4:0]),
        .operation_i(execution_unit_operation),
        .result_o(results_int[2])
    );
    
    branchUnit branch1 (
        .first_operand_i(first_operand_i),
        .second_operand_i(second_operand_i),
        .offset_i(third_operand_i),
        .pc_i(pc_i),
        .operation_i(execution_unit_operation),
        .result_o(results_int[4]),
        .result_jal_o(results_int[3]),
        .jump_o(jump_int),
        .write_enable_o(write_enable_regbank_branch_unit)
    );

    LSUnit memory1 (
        .first_operand_i(first_operand_i),
        .second_operand_i(second_operand_i),
        .data_i(third_operand_i),
        .operation_i(execution_unit_operation),
        .enable_i(execution_unit_selector == MEMORY_UNIT),
        .read_address_o(mem_read_address_o),
        .read_o(mem_read_o),
        .write_address_o(results_int[7]),
        .write_data_o(results_int[6]),
        .write_enable_o(mem_write_enable_int),
        .write_enable_regBank(write_enable_regbank_memory_unit)
    );
    
    csrUnit CSRaccess (
        .first_operand_i(first_operand_i),
        .instruction_i(instruction_i),
        .operation_i(execution_unit_operation),
        .privilege_i(privilegeLevel_e'(2'b11)),
        .read_enable_o(csr_read_enable_o),
        .write_enable_o(csr_write_enable_o),
        .operation_o(csr_operation_o),
        .address_o(csr_address_o),
        .data_o(csr_data_o),
        .exception_o(csr_exception)
    );
    
    assign results_int[5] = second_operand_i; // BYPASS

//////////////////////////////////////////////////////////////////////////////
// Demux
//////////////////////////////////////////////////////////////////////////////

    always @(posedge clk) begin 
        if (stall == 0) begin
            if (execution_unit_selector == ADDER_UNIT)
                result_o[0] <= results_int[0];
            else if (execution_unit_selector == LOGICAL_UNIT)
                result_o[0] <= results_int[1];
            else if (execution_unit_selector == SHIFTER_UNIT)
                result_o[0] <= results_int[2];
            else if (execution_unit_selector == BRANCH_UNIT)
                result_o[0] <= results_int[3];
            else if (execution_unit_selector == MEMORY_UNIT)
                result_o[0] <= results_int[6];
            else if (execution_unit_selector == CSR_UNIT)
                result_o[0] <= csr_data_read_i;
            else
                result_o[0] <= results_int[5];
        end
    end

    always @(posedge clk) begin
        if (stall == 0) begin
            if (execution_unit_selector == BRANCH_UNIT)
                result_o[1] <= results_int[4];
            else if (execution_unit_selector == MEMORY_UNIT)
                result_o[1] <= results_int[7];
            else 
                result_o[1] <= '0;
        end
    end  
    
    always @(posedge clk) begin
        if (stall == 0) begin
            if (execution_unit_selector == BRANCH_UNIT)
                jump_o <= jump_int;
            else
                jump_o <= '0;
        end
    end  

    always @(posedge clk) begin
        if (stall == 0) begin
            if (execution_unit_selector == MEMORY_UNIT)
                mem_write_enable_o <= mem_write_enable_int;
            else 
                mem_write_enable_o <= '0;
        end
    end  

    always @(posedge clk) begin
        if (stall == 0) begin
            if (execution_unit_selector == BRANCH_UNIT)
                write_enable_o <= write_enable_regbank_branch_unit;
            else if (execution_unit_selector == MEMORY_UNIT)
                write_enable_o <= write_enable_regbank_memory_unit;
            else
                write_enable_o <= 1;
        end
    end  

    always @(posedge clk) begin
        if (stall == 0) begin
            tag_o <= tag_i;
            instruction_operation_o <= instruction_operation_i;
            instruction_o <= instruction_i;
            pc_o <= pc_i;
            exception_o <= exception_i | csr_exception;
        end
    end

endmodule
