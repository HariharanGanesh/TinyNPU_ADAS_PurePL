`timescale 1ns / 1ps

module tb_adas_features();

    reg clk;
    reg rst_n;

    // Sensor Fusion Inputs
    reg ped_detected;
    reg obs_detected;
    reg lane_detected;
    reg sign_overspeed;
    reg [1:0] lane_severity;
    reg ped_en;
    reg obs_en;
    reg lane_en;

    // Safety Unit Inputs
    reg wdt_pet;
    reg stop_petting;

    // Security Unit Inputs
    reg sw_brake_arm;

    // Outputs
    wire emergency_trigger;
    wire warning_ped;
    wire warning_lane;
    wire warning_sign;
    wire system_fault;
    wire brake_authorized;

    // Instantiations
    sensor_fusion u_fusion (
        .clk(clk),
        .rst_n(rst_n),
        .ped_detected(ped_detected),
        .obs_detected(obs_detected),
        .lane_detected(lane_detected),
        .sign_overspeed(sign_overspeed),
        .lane_severity(lane_severity),
        .ped_en(ped_en),
        .obs_en(obs_en),
        .lane_en(lane_en),
        .emergency_trigger(emergency_trigger),
        .warning_ped(warning_ped),
        .warning_lane(warning_lane),
        .warning_sign(warning_sign)
    );

    safety_unit #(
        .TIMEOUT_CYCLES(50) // Small timeout for fast simulation
    ) u_safety (
        .clk(clk),
        .rst_n(rst_n),
        .wdt_pet(wdt_pet),
        .system_fault(system_fault)
    );

    security_unit u_security (
        .clk(clk),
        .rst_n(rst_n),
        .sw_brake_arm(sw_brake_arm),
        .emergency_trigger(emergency_trigger),
        .system_fault(system_fault),
        .brake_authorized(brake_authorized)
    );

    // Clock gen
    always #4 clk = ~clk; // 125 MHz

    initial begin
        // Setup GTKWave / XSIM tracing
        $dumpfile("adas_features.vcd");
        $dumpvars(0, tb_adas_features);
        
        // Initialize
        clk = 0;
        rst_n = 0;
        ped_detected = 0;
        obs_detected = 0;
        lane_detected = 0;
        sign_overspeed = 0;
        lane_severity = 0;
        ped_en = 1;
        obs_en = 1;
        lane_en = 1;
        wdt_pet = 0;
        sw_brake_arm = 0;
        stop_petting = 0;

        repeat(3) @(negedge clk);
        rst_n = 1;

        // ----------------------------------------------------
        // TEST 1: Pedestrian Detection & Normal Brake
        // ----------------------------------------------------
        $display("TEST 1: Pedestrian Detection");
        repeat(3) @(negedge clk);
        sw_brake_arm = 1; // Driver arms the system
        repeat(3) @(negedge clk);
        ped_detected = 1; // NPU sees pedestrian
        repeat(5) @(negedge clk);
        if (warning_ped && brake_authorized) $display("PASS: Brake applied for pedestrian.");
        else $display("FAIL: Brake not applied! (Due to sensor_fusion.v bug: hazard_score < 3)");
        ped_detected = 0;

        // ----------------------------------------------------
        // TEST 2: Security Interlock (Brake Disarmed)
        // ----------------------------------------------------
        $display("TEST 2: Disarmed System");
        sw_brake_arm = 0; // Driver disarms system
        // We will force a hazard score of 3 using lane severity
        @(negedge clk);
        lane_detected = 1;
        lane_severity = 2'b11; 
        repeat(5) @(negedge clk);
        if (!brake_authorized) $display("PASS: Brake was correctly blocked by security unit.");
        else $display("FAIL: Brake bypassed security!");
        lane_detected = 0;
        lane_severity = 0;
        
        // Because emergency_trigger is sticky, we need a hard reset to clear it for the next tests
        rst_n = 0;
        repeat(3) @(negedge clk);
        rst_n = 1;

        // ----------------------------------------------------
        // TEST 3: Lane Departure Warning
        // ----------------------------------------------------
        $display("TEST 3: Lane Departure Warning");
        sw_brake_arm = 1;
        @(negedge clk);
        lane_detected = 1;
        lane_severity = 2'b11; // Critical severity
        repeat(5) @(negedge clk);
        if (warning_lane && brake_authorized) $display("PASS: Lane warning triggered and brake applied.");
        lane_detected = 0;

        rst_n = 0;
        repeat(3) @(negedge clk);
        rst_n = 1;
        sw_brake_arm = 1;
        
        // ----------------------------------------------------
        // TEST 4: Speed Sign Overspeed
        // ----------------------------------------------------
        $display("TEST 4: Speed Sign Overspeed");
        @(negedge clk);
        sign_overspeed = 1;
        repeat(5) @(negedge clk);
        if (warning_sign) $display("PASS: Sign warning triggered.");
        sign_overspeed = 0;

        // ----------------------------------------------------
        // TEST 5: Watchdog System Fault
        // ----------------------------------------------------
        $display("TEST 5: Watchdog System Fault");
        @(negedge clk);
        stop_petting = 1; // STOP PETTING THE WATCHDOG
        
        // Wait for watchdog to expire (50 cycles)
        repeat(60) @(negedge clk);
        if (system_fault) $display("PASS: System fault triggered.");
        else $display("FAIL: Watchdog did not fault.");
        
        // Try to trigger an emergency while fault is active
        @(negedge clk);
        lane_detected = 1;
        lane_severity = 2'b11; 
        repeat(5) @(negedge clk);
        if (!brake_authorized) $display("PASS: Brake correctly blocked due to system fault safe-state!");
        else $display("FAIL: Brake authorized during fault!");

        repeat(10) @(negedge clk);
        $finish;
    end

    // Background Watchdog Petting 
    always begin
        #50;
        if (!stop_petting && !system_fault) wdt_pet = ~wdt_pet;
    end

endmodule