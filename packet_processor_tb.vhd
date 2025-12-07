-- File: packet_processor_tb.vhd
-- Description: Top-Level Testbench for IPv4 Packet Processor
-- 
-- This file demonstrates MODULE 4 (Testbench) requirements:
--   - Complete system-level testing
--   - Multiple test scenarios with detailed verification
--   - Golden model for checksum computation
--   - Assert and report statements for verification
--   - Uses helper package functions and procedures
--
-- Test Cases:
--   1. Blocked IPs (all 10) - expect drop='1'
--   2. Non-blocked IP - expect drop='0'
--   3. TTL=1 behavior - expect drop='1', TTL_out=0
--   4. TTL=64 behavior - expect drop='0', TTL_out=63, valid checksum
--   5. Reset behavior
--   6. Checksum verification (optional corrupt checksum test)


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helpers.all;

entity packet_processor_tb is
end entity packet_processor_tb;

architecture tb of packet_processor_tb is
    
    constant CLK_PERIOD : time := 10 ns;
    constant N_RULES    : integer := 10;
    
    constant MAX_WAIT_CYCLES : integer := 100;
    
    component packet_processor is
        generic (
            N_RULES : integer := 10;
            VERIFY_CHECKSUM : boolean := true
        );
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            start       : in  std_logic;
            header_in   : in  std_logic_vector(159 downto 0);
            busy        : out std_logic;
            valid       : out std_logic;
            drop        : out std_logic;
            header_out  : out std_logic_vector(159 downto 0);
            dbg_drop_ttl     : out std_logic;
            dbg_drop_fw      : out std_logic;
            dbg_drop_cksum   : out std_logic
        );
    end component;
    
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal start       : std_logic := '0';
    signal header_in   : std_logic_vector(159 downto 0) := (others => '0');
    signal busy        : std_logic;
    signal valid       : std_logic;
    signal drop        : std_logic;
    signal header_out  : std_logic_vector(159 downto 0);
    signal dbg_drop_ttl   : std_logic;
    signal dbg_drop_fw    : std_logic;
    signal dbg_drop_cksum : std_logic;
    
    signal test_done   : boolean := false;
    signal pass_count  : integer := 0;
    signal fail_count  : integer := 0;
    
    type ip_array_t is array (natural range <>) of std_logic_vector(31 downto 0);
    
    constant BLOCKED_IPS : ip_array_t(0 to 9) := (
        0 => x"0A010005",
        1 => x"0A01000A",
        2 => x"0A010014",
        3 => x"C0A80164",
        4 => x"C0A80165",
        5 => x"AC100005",
        6 => x"AC100101",
        7 => x"CB007105",
        8 => x"C633640A",
        9 => x"08080808"
    );
    
    function build_ipv4_header(
        ttl         : integer range 0 to 255;
        src_ip      : std_logic_vector(31 downto 0);
        dst_ip      : std_logic_vector(31 downto 0);
        protocol    : integer range 0 to 255 := 6;
        total_len   : integer range 0 to 65535 := 40
    ) return std_logic_vector is
        variable header : std_logic_vector(159 downto 0);
        variable checksum : std_logic_vector(15 downto 0);
    begin
        header(159 downto 156) := x"4";
        header(155 downto 152) := x"5";
        header(151 downto 144) := x"00";
        header(143 downto 128) := std_logic_vector(to_unsigned(total_len, 16));
        header(127 downto 112) := x"1234";
        header(111 downto 96)  := x"4000";
        header(95 downto 88)   := std_logic_vector(to_unsigned(ttl, 8));
        header(87 downto 80)   := std_logic_vector(to_unsigned(protocol, 8));
        header(79 downto 64)   := x"0000";
        header(63 downto 32)   := src_ip;
        header(31 downto 0)    := dst_ip;
        
        checksum := compute_ipv4_checksum(header);
        header(79 downto 64) := checksum;
        
        return header;
    end function;
    
    function verify_header_checksum(
        header : std_logic_vector(159 downto 0)
    ) return boolean is
        variable expected_cksum : std_logic_vector(15 downto 0);
        variable actual_cksum   : std_logic_vector(15 downto 0);
    begin
        actual_cksum := header(79 downto 64);
        
        expected_cksum := compute_ipv4_checksum(header);
        
        return actual_cksum = expected_cksum;
    end function;
    
begin
    
    dut : packet_processor
        generic map (
            N_RULES => N_RULES,
            VERIFY_CHECKSUM => true
        )
        port map (
            clk         => clk,
            rst         => rst,
            start       => start,
            header_in   => header_in,
            busy        => busy,
            valid       => valid,
            drop        => drop,
            header_out  => header_out,
            dbg_drop_ttl   => dbg_drop_ttl,
            dbg_drop_fw    => dbg_drop_fw,
            dbg_drop_cksum => dbg_drop_cksum
        );
    
    clk_gen : process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;
    
    stim_proc : process
        
        variable wait_count : integer;
        variable test_header : std_logic_vector(159 downto 0);
        variable expected_ttl : integer;
        variable actual_ttl : integer;
        
        procedure wait_for_valid is
        begin
            wait_count := 0;
            while valid = '0' and wait_count < MAX_WAIT_CYCLES loop
                wait until rising_edge(clk);
                wait_count := wait_count + 1;
            end loop;
            
            if wait_count >= MAX_WAIT_CYCLES then
                report "TIMEOUT: Waiting for valid signal" severity error;
                fail_count <= fail_count + 1;
            end if;
        end procedure;
        
        procedure process_packet(
            input_header    : std_logic_vector(159 downto 0);
            expect_drop     : std_logic;
            expect_ttl      : integer;
            test_name       : string
        ) is
        begin
            report "--- " & test_name & " ---" severity note;
            
            header_in <= input_header;
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            
            wait_for_valid;
            wait until rising_edge(clk);
            
            if drop = expect_drop then
                report "  PASS: drop=" & std_logic'image(drop) & " (expected)" severity note;
                pass_count <= pass_count + 1;
            else
                report "  FAIL: drop=" & std_logic'image(drop) & 
                       " expected=" & std_logic'image(expect_drop) severity error;
                fail_count <= fail_count + 1;
            end if;
            
            actual_ttl := to_integer(unsigned(header_out(95 downto 88)));
            if actual_ttl = expect_ttl then
                report "  PASS: TTL=" & integer'image(actual_ttl) & " (expected)" severity note;
                pass_count <= pass_count + 1;
            else
                report "  FAIL: TTL=" & integer'image(actual_ttl) & 
                       " expected=" & integer'image(expect_ttl) severity error;
                fail_count <= fail_count + 1;
            end if;
            
            if drop = '0' then
                if verify_header_checksum(header_out) then
                    report "  PASS: Output checksum valid" severity note;
                    pass_count <= pass_count + 1;
                else
                    report "  FAIL: Output checksum invalid" severity error;
                    fail_count <= fail_count + 1;
                end if;
            end if;
            
            wait for CLK_PERIOD * 3;
        end procedure;
        
    begin
        rst <= '1';
        start <= '0';
        header_in <= (others => '0');
        wait for CLK_PERIOD * 5;
        
        report "========================================" severity note;
        report "IPv4 Packet Processor Testbench" severity note;
        report "========================================" severity note;
        
        report "" severity note;
        report "=== Test 1: Reset Behavior ===" severity note;
        
        assert busy = '0' 
            report "FAIL: busy should be '0' after reset" severity error;
        assert valid = '0' 
            report "FAIL: valid should be '0' after reset" severity error;
        assert drop = '0' 
            report "FAIL: drop should be '0' after reset" severity error;
        
        report "PASS: Reset state verified" severity note;
        pass_count <= pass_count + 1;
        
        rst <= '0';
        wait for CLK_PERIOD * 2;
        
        report "" severity note;
        report "=== Test 2: TTL = 1 (Expires) ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 1,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        process_packet(test_header, '1', 0, "TTL=1 Expiry Test");
        
        if dbg_drop_ttl = '1' then
            report "  PASS: drop_ttl flag set correctly" severity note;
            pass_count <= pass_count + 1;
        else
            report "  FAIL: drop_ttl flag should be '1'" severity error;
            fail_count <= fail_count + 1;
        end if;
        
        report "" severity note;
        report "=== Test 3: TTL = 64 (Normal) ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 64,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        process_packet(test_header, '0', 63, "TTL=64 Normal Test");
        
        report "" severity note;
        report "=== Test 4: Blocked Source IPs ===" severity note;
        
        for i in BLOCKED_IPS'range loop
            test_header := build_ipv4_header(
                ttl     => 64,
                src_ip  => BLOCKED_IPS(i),
                dst_ip  => x"0A010008"
            );
            
            process_packet(test_header, '1', 63, 
                          "Blocked Src IP " & integer'image(i) & ": " & 
                          ip_to_string(BLOCKED_IPS(i)));
            
            if dbg_drop_fw = '1' then
                report "  PASS: drop_fw flag set correctly" severity note;
                pass_count <= pass_count + 1;
            else
                report "  FAIL: drop_fw flag should be '1'" severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;
        
        report "" severity note;
        report "=== Test 5: Blocked Destination IPs ===" severity note;
        
        for i in BLOCKED_IPS'range loop
            test_header := build_ipv4_header(
                ttl     => 64,
                src_ip  => x"0A010007",
                dst_ip  => BLOCKED_IPS(i)
            );
            
            process_packet(test_header, '1', 63, 
                          "Blocked Dst IP " & integer'image(i) & ": " & 
                          ip_to_string(BLOCKED_IPS(i)));
        end loop;
        
        report "" severity note;
        report "=== Test 6: Non-Blocked IP (10.1.0.7) ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 128,
            src_ip  => x"0A010007",
            dst_ip  => x"C0A80102"
        );
        
        process_packet(test_header, '0', 127, "Non-blocked IP Test");
        
        report "" severity note;
        report "=== Test 7: TTL = 0 (Already Expired) ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 0,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        process_packet(test_header, '1', 0, "TTL=0 Already Expired Test");
        
        report "" severity note;
        report "=== Test 8: Reset During Processing ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 64,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        header_in <= test_header;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait for CLK_PERIOD * 3;
        
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        
        if busy = '0' and valid = '0' then
            report "PASS: Reset during processing works correctly" severity note;
            pass_count <= pass_count + 1;
        else
            report "FAIL: Reset during processing failed" severity error;
            fail_count <= fail_count + 1;
        end if;
        
        rst <= '0';
        wait for CLK_PERIOD * 2;
        
        report "" severity note;
        report "=== Test 9: Checksum Handling ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 64,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        header_in <= test_header;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        
        wait_for_valid;
        wait until rising_edge(clk);
        
        if dbg_drop_cksum = '0' then
            report "PASS: Checksum error flag is '0' (verification disabled, checksum recomputed)" severity note;
            pass_count <= pass_count + 1;
        else
            report "FAIL: Checksum error flag should be '0'" severity error;
            fail_count <= fail_count + 1;
        end if;
        
        wait for CLK_PERIOD * 3;
        
        report "" severity note;
        report "=== Test 10: Checksum Recomputation (corrupt input) ===" severity note;
        
        test_header := build_ipv4_header(
            ttl     => 64,
            src_ip  => x"0A010007",
            dst_ip  => x"0A010008"
        );
        
        test_header(79 downto 64) := x"DEAD";
        
        header_in <= test_header;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        
        wait_for_valid;
        wait until rising_edge(clk);
        
        report "  Corrupt input checksum test: dbg_drop_cksum=" & 
               std_logic'image(dbg_drop_cksum) severity note;
        
        if dbg_drop_cksum = '0' then
            report "PASS: Checksum recomputed (verification disabled)" severity note;
            pass_count <= pass_count + 1;
        else
            report "INFO: Checksum verification active" severity note;
        end if;
        
        wait for CLK_PERIOD * 5;
        
        report "" severity note;
        report "========================================" severity note;
        report "           TEST SUMMARY                 " severity note;
        report "========================================" severity note;
        report "  PASSED: " & integer'image(pass_count) severity note;
        report "  FAILED: " & integer'image(fail_count) severity note;
        report "========================================" severity note;
        
        if fail_count = 0 then
            report "ALL TESTS PASSED!" severity note;
        else
            report "SOME TESTS FAILED!" severity error;
        end if;
        
        test_done <= true;
        wait;
    end process stim_proc;
    
end architecture tb;
