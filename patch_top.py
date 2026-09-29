import re

with open('IP/TinyNPU200/src/tinynpu_top.v', 'r') as f:
    code = f.read()

# Add BRAM ports
bram_ports = '''    // Interrupt
    output wire                         interrupt,

    // ADAS Detection Head BRAM Interface
    output wire                         bram_wr_en,
    output wire [9:0]                   bram_wr_addr,
    output wire [127:0]                 bram_wr_data,
    output wire                         bram_clk,
    output wire                         bram_rst
);'''
code = re.sub(r'    // Interrupt\s*output wire\s*interrupt\s*\);', bram_ports, code)

# Add internal wires for CSRs
csr_wires = '''    wire [15:0] csr_num_tiles_x;
    wire [15:0] csr_num_tiles_y;
    
    // ADAS CSR Wires
    wire signed [7:0] csr_thresh_logit;
    wire [9:0]        csr_max_candidates;
    wire              csr_clear_frame;
    wire [15:0]       csr_scale_id;'''
code = re.sub(r'    wire \[15:0\] csr_num_tiles_x;\n\s*wire \[15:0\] csr_num_tiles_y;', csr_wires, code)

# Add ADAS CSRs to axi4_lite_slave instantiation
axi_inst = '''        .csr_frame_w(csr_frame_w),
        .csr_frame_h(csr_frame_h),
        // ADAS CSRs
        .csr_thresh_logit(csr_thresh_logit),
        .csr_max_candidates(csr_max_candidates),
        .csr_clear_frame(csr_clear_frame),
        .csr_scale_id(csr_scale_id),'''
code = re.sub(r'        \.csr_frame_w\(csr_frame_w\),\n\s*\.csr_frame_h\(csr_frame_h\),', axi_inst, code)

# Add ADAS Aggregator and Detection Head instantiation at the very end
adas_logic = '''
    // =========================================================================
    // Module 11: ADAS Stream Aggregator & Detection Head
    // =========================================================================
    wire        adas_valid;
    wire [2143:0] adas_data;

    adas_stream_aggregator u_adas_agg (
        .clk(clk_postproc),
        .rst_n(rst_n),
        .s_axis_tvalid(outbuf_axis_valid),
        .s_axis_tdata(outbuf_axis_data),
        .s_axis_tready(), // Open, passive tap
        .m_adas_valid(adas_valid),
        .m_adas_data(adas_data)
    );

    wire [1599:0] class_logits = adas_data[1599:0];
    wire [135:0]  reg_l        = adas_data[1735:1600];
    wire [135:0]  reg_t        = adas_data[1871:1736];
    wire [135:0]  reg_r        = adas_data[2007:1872];
    wire [135:0]  reg_b        = adas_data[2143:2008];

    assign bram_clk = clk_postproc;
    assign bram_rst = ~rst_n;

    npu_detection_head u_adas_head (
        .clk(clk_postproc),
        .rst_n(rst_n),
        .thresh_logit(csr_thresh_logit),
        .max_candidates(csr_max_candidates),
        .clear_frame(csr_clear_frame),
        .scale_id(csr_scale_id),
        .stream_valid(adas_valid),
        .class_logits(class_logits),
        .reg_l(reg_l),
        .reg_t(reg_t),
        .reg_r(reg_r),
        .reg_b(reg_b),
        .grid_x(16'd0), // To be calculated correctly in the future if needed
        .grid_y(16'd0),
        .stride(csr_stride),
        .bram_wr_en(bram_wr_en),
        .bram_wr_addr(bram_wr_addr),
        .bram_wr_data(bram_wr_data),
        .candidate_count(),
        .overflow_flag()
    );

endmodule
'''
code = re.sub(r'endmodule', adas_logic, code)

with open('IP/TinyNPU200/src/tinynpu_top.v', 'w') as f:
    f.write(code)