// Copyright TU Wien
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1


module vproc_vwca #(
        parameter int unsigned        WCA_OP_W         = 64,   // VWCA operand width in bits
        parameter bit                 BUF_OPERANDS     = 1'b1, // insert pipeline stage after operand extraction
        parameter bit                 BUF_INTERMEDIATE = 1'b1, // insert pipeline stage for intermediate results
        parameter bit                 BUF_RESULTS      = 1'b1, // insert pipeline stage after computing result
        parameter type                CTRL_T           = logic,
        parameter bit                 DONT_CARE_ZERO   = 1'b0  // initialize don't care values to zero
    )(
        input  logic                  clk_i,
        input  logic                  async_rst_ni,
        input  logic                  sync_rst_ni,

        input  logic                  pipe_in_valid_i,
        output logic                  pipe_in_ready_o,
        input  CTRL_T                 pipe_in_ctrl_i,
        input  logic [WCA_OP_W  -1:0] pipe_in_op1_i,
        input  logic [WCA_OP_W  -1:0] pipe_in_op2_i,
        input  logic [WCA_OP_W/8-1:0] pipe_in_mask_i,

        output logic                  pipe_out_valid_o,
        input  logic                  pipe_out_ready_i,
        output CTRL_T                 pipe_out_ctrl_o,
        output logic [WCA_OP_W  -1:0] pipe_out_res_o,
        output logic [WCA_OP_W/8-1:0] pipe_out_res_cmp_o,
        output logic [WCA_OP_W/8-1:0] pipe_out_mask_o
    );

    import vproc_pkg::*;

    always_ff @(posedge clk_i) begin
        if (pipe_out_valid_o) begin
            $display("WCA WRITEBACK: %h", pipe_out_res_o);
            $display("MASK: %h", pipe_out_mask_o);
        end
    end

    // Parameter asserts
    initial begin
        // Operand width must be a multiple of 32
        assert ( (WCA_OP_W & 31) == 0 ) else begin
            $error("WCA operand width (WCA_OP_W) must be a multiple of 32. It is currently %d",WCA_OP_W);
        end
    end

    // ///////////////////////////////////////////////////////////////////////////
    // // VWCA BUFFERS

    // logic  state_ex1_ready,                      state_ex2_ready,   state_res_ready;
    // logic  state_ex1_valid_q, state_ex1_valid_d, state_ex2_valid_q, state_res_valid_q;
    // CTRL_T state_ex1_q,       state_ex1_d,       state_ex2_q,       state_res_q;

    // // operands and result:
    // // logic [WCA_OP_W*9/8-1:0] operand1_q,     operand1_d;
    // // logic [WCA_OP_W*9/8-1:0] operand2_q,     operand2_d;
    // logic [WCA_OP_W  /8-1:0] operand_mask_q, operand_mask_d;
    // logic [WCA_OP_W    -1:0] result_vwca_q,   result_vwca_d;
    // // logic [WCA_OP_W  /8-1:0] result_cmp_q,   result_cmp_d;
    // logic [WCA_OP_W  /8-1:0] result_mask_q,  result_mask_d;

    // generate
    //     if (BUF_OPERANDS) begin
    //         always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_vwca_stage_ex1_valid
    //             if (~async_rst_ni) begin
    //                 state_ex1_valid_q <= 1'b0;
    //             end
    //             else if (~sync_rst_ni) begin
    //                 state_ex1_valid_q <= 1'b0;
    //             end
    //             else if (state_ex1_ready) begin
    //                 state_ex1_valid_q <= state_ex1_valid_d;
    //             end
    //         end
    //         always_ff @(posedge clk_i) begin : vproc_vwca_stage_ex1
    //             if (state_ex1_ready & state_ex1_valid_d) begin
    //                 state_ex1_q    <= state_ex1_d;
    //             end
    //         end
    //         assign state_ex1_ready = ~state_ex1_valid_q | state_ex2_ready;
    //     end else begin
    //         always_comb begin
    //             state_ex1_valid_q = state_ex1_valid_d;
    //             state_ex1_q       = state_ex1_d;
    //         end
    //         assign state_ex1_ready = state_ex2_ready;
    //     end

    //     if (BUF_INTERMEDIATE) begin
    //         always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_vwca_stage_ex2_valid
    //             if (~async_rst_ni) begin
    //                 state_ex2_valid_q <= 1'b0;
    //             end
    //             else if (~sync_rst_ni) begin
    //                 state_ex2_valid_q <= 1'b0;
    //             end
    //             else if (state_ex2_ready) begin
    //                 state_ex2_valid_q <= state_ex1_valid_q;
    //             end
    //         end
    //         always_ff @(posedge clk_i) begin : vproc_vwca_stage_ex2
    //             if (state_ex2_ready & state_ex1_valid_q) begin
    //                 state_ex2_q        <= state_ex1_q;
    //             end
    //         end
    //         assign state_ex2_ready = ~state_ex2_valid_q | state_res_ready;
    //     end else begin
    //         always_comb begin
    //             state_ex2_valid_q   = state_ex1_valid_q;
    //             state_ex2_q         = state_ex1_q;
    //         end
    //         assign state_ex2_ready = state_res_ready;
    //     end

    //     if (BUF_RESULTS) begin
    //         always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_vwca_stage_res_valid
    //             if (~async_rst_ni) begin
    //                 state_res_valid_q <= 1'b0;
    //             end
    //             else if (~sync_rst_ni) begin
    //                 state_res_valid_q <= 1'b0;
    //             end
    //             else if (state_res_ready) begin
    //                 state_res_valid_q <= state_ex2_valid_q;
    //             end
    //         end
    //         always_ff @(posedge clk_i) begin : vproc_vwca_stage_res
    //             if (state_res_ready & state_ex2_valid_q) begin
    //                 state_res_q   <= state_ex2_q;
    //                 result_vwca_q  <= result_vwca_d;
    //                 result_mask_q <= result_mask_d;
    //             end
    //         end
    //         assign state_res_ready = ~state_res_valid_q | pipe_out_ready_i;
    //     end else begin
    //         always_comb begin
    //             state_res_valid_q = state_ex2_valid_q;
    //             state_res_q       = state_ex2_q;
    //             result_vwca_q      = result_vwca_d;
    //             result_mask_q     = result_mask_d;
    //         end
    //         assign state_res_ready = pipe_out_ready_i;
    //     end
    // endgenerate

    // ///////////////////////////////////////////////////////////////////////////
    // // VWCA OPERAND AND RESULT CONVERSION
    // // TODO

    // assign pipe_in_ready_o   = state_ex1_ready;
    // assign state_ex1_valid_d = pipe_in_valid_i;
    // assign state_ex1_d       = pipe_in_ctrl_i;
    // assign operand_mask_d    = pipe_in_mask_i;

    // // result byte mask
    // // logic [WCA_OP_W/8-1:0] vl_mask;
    // // assign vl_mask       = ~state_ex2_q.vl_part_0 ? ({(WCA_OP_W/8){1'b1}} >> (~state_ex2_q.vl_part)) : '0;
    // // assign result_mask_d = vl_mask;
    // assign result_mask_d = '1;

    // assign pipe_out_valid_o   = state_res_valid_q;
    // assign pipe_out_ctrl_o    = state_res_q;
    // always_comb begin
    //     // The result is inverted for averaging subtract instructions (i.e., instructions for
    //     // which the operands are shifted right and at least one operand is being inverted).
    //     // This is required to allow using the carry logic for rounding.
    //     pipe_out_res_vwca_o = result_vwca_q;
    // end
    // // assign pipe_out_res_cmp_o = result_cmp_q;
    // assign pipe_out_mask_o    = result_mask_q;


    // // arithmetic result
    // always_comb begin
    //     result_vwca_d = DONT_CARE_ZERO ? '0 : 'x;
    //     for (int i = 0; i < WCA_OP_W / 8; i++) begin
    //         result_vwca_d[8*i +: 8] = i;
    //     end
    //     // unique case (state_ex2_q.mode.alu.opx2.res)
    //     //     default: ;
    //     // endcase
    // end
    typedef struct packed {
        CTRL_T ctrl;
        logic [WCA_OP_W  -1:0] op1;
        logic [WCA_OP_W  -1:0] op2;
        logic [WCA_OP_W/8-1:0] mask;
    } wca_instr;

    ///////////////////////////////////////////////////////////////////////////
    // BUFFERS

    localparam PIPELINE_STAGES = 3;
    wca_instr stage[PIPELINE_STAGES];

    // Handshake vars
    logic valid[PIPELINE_STAGES];
    /* verilator lint_off UNOPTFLAT */
    logic ready[PIPELINE_STAGES];
    /* verilator lint_on UNOPTFLAT */

    generate
        // Input Stage
        if (BUF_OPERANDS) begin
            always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_wca_input_stage_valid
                if (~async_rst_ni) begin
                    valid[0] <= 1'b0;
                end
                else if (~sync_rst_ni) begin
                    valid[0] <= 1'b0;
                end
                else if (ready[0]) begin
                    valid[0] <= pipe_in_valid_i;
                end
            end
            always_ff @(posedge clk_i) begin : vproc_wca_input_stage
                if (ready[0] & pipe_in_valid_i) begin
                    stage[0].ctrl <= pipe_in_ctrl_i;
                    stage[0].op1 <= pipe_in_op1_i;
                    stage[0].op2 <= pipe_in_op2_i;
                    stage[0].mask <= pipe_in_mask_i;
                end
            end
            assign ready[0] = ~valid[0] | ready[1];
        end else begin
            always_comb begin : vproc_wca_input_stage
                stage[0].ctrl = pipe_in_ctrl_i;
                stage[0].op1 = pipe_in_op1_i;
                stage[0].op2 = pipe_in_op2_i;
                stage[0].mask = pipe_in_mask_i;
                valid[0] = pipe_in_valid_i;
                ready[0] = ready[1];
            end
        end
        assign pipe_in_ready_o = ready[0];

        // Intermediate Stage(s)
        genvar idx;
        for(idx=1; idx<PIPELINE_STAGES-1; idx++) begin
            if (BUF_INTERMEDIATE) begin
                always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_wca_intermediate_stage_valid
                    if (~async_rst_ni) begin
                        valid[idx] <= 1'b0;
                    end
                    else if (~sync_rst_ni) begin
                        valid[idx] <= 1'b0;
                    end
                    else if (ready[idx]) begin
                        valid[idx] <= valid[idx-1];
                    end
                end
                always_ff @(posedge clk_i) begin : vproc_wca_intermediate_stage
                    if (ready[idx] & valid[idx-1]) begin
                        stage[idx] <= stage[idx-1];
                    end
                end
                assign ready[idx] = ~valid[idx] | ready[idx+1];
            end else begin
                always_comb begin : vproc_wca_intermediate_stage
                    stage[idx] = stage[idx-1];
                    valid[idx] = valid[idx-1];
                    ready[idx] = ready[idx+1];
                end
            end
        end

        // Output Stage
        if (BUF_RESULTS) begin
            always_ff @(posedge clk_i or negedge async_rst_ni) begin : vproc_wca_output_stage_valid
                if (~async_rst_ni) begin
                    pipe_out_valid_o <= 1'b0;
                end
                else if (~sync_rst_ni) begin
                    pipe_out_valid_o <= 1'b0;
                end
                else if (ready[PIPELINE_STAGES-1]) begin
                    pipe_out_valid_o <= valid[PIPELINE_STAGES-2];
                end
            end
            always_ff @(posedge clk_i) begin : vproc_wca_output_stage
                if (ready[PIPELINE_STAGES-1] & valid[PIPELINE_STAGES-2]) begin
                    stage[PIPELINE_STAGES-1] <= stage[PIPELINE_STAGES-2];
                    pipe_out_res_o <= result;
                end
            end
            assign ready[PIPELINE_STAGES-1] = ~valid[PIPELINE_STAGES-1] | pipe_out_ready_i;
        end else begin
            always_comb begin : vproc_wca_output_stage
                stage[PIPELINE_STAGES-1] = stage[PIPELINE_STAGES-2];
                valid[PIPELINE_STAGES-1] = valid[PIPELINE_STAGES-2];
                ready[PIPELINE_STAGES-1] = pipe_out_ready_i;
            end
            assign pipe_out_valid_o = valid[PIPELINE_STAGES-1];
            assign pipe_out_res_o = result;
        end
        assign pipe_out_ctrl_o = stage[PIPELINE_STAGES-1].ctrl;

        // result byte mask
        logic [WCA_OP_W/8-1:0] vl_mask;
        // assign vl_mask        = ~stage[PIPELINE_STAGES-1].ctrl.vl_part_0 ? ({(WCA_OP_W/8){1'b1}} >> (~stage[PIPELINE_STAGES-1].ctrl.vl_part)) : '0;
        assign vl_mask        = -1; // ~stage[PIPELINE_STAGES-1].ctrl.vl_part_0 ? ({(WCA_OP_W/8){1'b1}} >> (~stage[PIPELINE_STAGES-1].ctrl.vl_part)) : '0;
        assign pipe_out_mask_o = (stage[PIPELINE_STAGES-1].ctrl.mode.wca.masked ? stage[PIPELINE_STAGES-1].mask : {(WCA_OP_W/8){1'b1}}) & vl_mask;

    endgenerate

    // BUFFERS END
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // VECTOR AND-NOT
    // logic [WCA_OP_W-1:0] result_vandn = ~stage[PIPELINE_STAGES-2].op1 & stage[PIPELINE_STAGES-2].op2;
    // END VECTOR AND-NOT
    ///////////////////////////////////////////////////////////////////////////



    ///////////////////////////////////////////////////////////////////////////
    // VECTOR WIDENING SHIFT LEFT
    logic [WCA_OP_W-1:0] result_vwsll;
    always_comb begin : chooseWideningShiftLeftResult
        result_vwsll = DONT_CARE_ZERO ? '0 : 'x;
        unique case (stage[PIPELINE_STAGES-2].ctrl.eew)
            VSEW_8: ; // No SEW=8 should happen
            VSEW_16: begin
                for (int i=0; i < WCA_OP_W/16; i++) begin
                    result_vwsll[16*i +: 16] = {8'b0,stage[PIPELINE_STAGES-2].op2[16*i +: 8]} << stage[PIPELINE_STAGES-2].op1[16*i +: 4];
                end
            end
            VSEW_32: begin
                for (int i=0; i < WCA_OP_W/32; i++) begin
                    result_vwsll[32*i +: 32] = {16'b0,stage[PIPELINE_STAGES-2].op2[32*i +: 16]} << stage[PIPELINE_STAGES-2].op1[32*i +: 5];
                end
            end
            default: ;
        endcase
    end
    // END VECTOR WIDENING SHIFT LEFT
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // VECTOR UNPACK CLUSTERS 2 bit -> 8 bit
    logic [WCA_OP_W-1:0] result_unpack_clusters_2b;
    always_comb begin : chooseUnpackClusters2BResult
        result_unpack_clusters_2b = DONT_CARE_ZERO ? '0 : 'x;
        // result_unpack_clusters_2b = 123;
        unique case (stage[PIPELINE_STAGES-2].ctrl.eew)
            VSEW_8: begin
                for (int i=0; i < WCA_OP_W/8; i++) begin
                    result_unpack_clusters_2b[8*i +: 8] = {6'b0,stage[PIPELINE_STAGES-2].op2[2*i +: 2]};
                end
            end
            VSEW_16: begin
                for (int i=0; i < WCA_OP_W/16; i++) begin
                    result_unpack_clusters_2b[16*i +: 16] = {14'b0,stage[PIPELINE_STAGES-2].op2[2*i +: 2]};
                end
            end
            VSEW_32: begin
                for (int i=0; i < WCA_OP_W/32; i++) begin
                    result_unpack_clusters_2b[32*i +: 32] = {30'b0,stage[PIPELINE_STAGES-2].op2[2*i +: 2]};
                end
            end
            default: ;
        endcase
    end
    // END VECTOR UNPACK CLUSTERS 2 bit -> 8 bit
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // RESULT
    logic [WCA_OP_W-1:0] result;
    always_comb begin
        // result = DONT_CARE_ZERO ? '0 : 'x;
        // result = result_vwsll;
        result = result_unpack_clusters_2b;
        // unique case (stage[PIPELINE_STAGES-2].ctrl.mode.wca.op)
        //     // Vector and-not
        //     WCA_VANDN: result = result_vandn;
        //     // Vector Reverse bits/bytes
        //     WCA_VBREV,
        //     WCA_VBREV8,
        //     WCA_VREV8: result = result_rev;
        //     // Vector count zero
        //     WCA_VCLZ,
        //     WCA_VCTZ: result = result_cz;
        //     // Vector population count
        //     WCA_VCPOP: result = result_vcpop;
        //     // Vector rotate
        //     WCA_VROL,
        //     WCA_VROR: result = result_rot;
        //     // Vector widening shift left
        //     WCA_VWSLL: result = result_vwsll;
        //     default: ;
        // endcase
    end
    // RESULT END
    ///////////////////////////////////////////////////////////////////////////


endmodule
