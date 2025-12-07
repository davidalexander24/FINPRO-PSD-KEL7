-- File: firewall_checker_tb.vhd
-- Description: Testbench for Firewall ROM Checker Module
-- 
-- This file demonstrates MODULE 4 (Testbench) requirements:
--   - Component instantiation of DUT
--   - Clock and reset generation
--   - Stimulus generation with test vectors
--   - Output verification with assert statements
--   - Report statements for test results
--
-- Test Cases:
--   1. Check all 10 blocked IPs - expect drop='1'
--   2. Check non-blocked IPs - expect drop='0'
--   3. Test reset behavior
--   4. Verify timing (busy, done signals)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helpers.all;

entity firewall_checker_tb is

end entity firewall_checker_tb;

architecture tb of firewall_checker_tb is
    

    constant CLK_PERIOD : time := 10 ns;
    constant N_RULES    : integer := 10;

    component firewall_rom_checker is
        generic (
            N_RULES : integer := 10
        );
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            start       : in  std_logic;
            ip_to_check : in  std_logic_vector(31 downto 0);
            busy        : out std_logic;
            drop_fw     : out std_logic;
            done        : out std_logic
        );
    end component;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal start       : std_logic := '0';
    signal ip_to_check : std_logic_vector(31 downto 0) := (others => '0');
    signal busy        : std_logic;
    signal drop_fw     : std_logic;
    signal done        : std_logic;

    signal test_done   : boolean := false;
    signal pass_count  : integer := 0;
    signal fail_count  : integer := 0;
    
    type ip_array_t is array (natural range <>) of std_logic_vector(31 downto 0);
    
    constant BLOCKED_IPS : ip_array_t(0 to 9) := (
        0 => x"0A010005",   -- 10.1.0.5
        1 => x"0A01000A",   -- 10.1.0.10
        2 => x"0A010014",   -- 10.1.0.20
        3 => x"C0A80164",   -- 192.168.1.100
        4 => x"C0A80165",   -- 192.168.1.101
        5 => x"AC100005",   -- 172.16.0.5
        6 => x"AC100101",   -- 172.16.1.1
        7 => x"CB007105",   -- 203.0.113.5
        8 => x"C633640A",   -- 198.51.100.10
        9 => x"08080808"    -- 8.8.8.8
    );
    
    constant NON_BLOCKED_IPS : ip_array_t(0 to 4) := (
        0 => x"0A010007",   -- 10.1.0.7 (close to blocked but not blocked)
        1 => x"C0A80166",   -- 192.168.1.102
        2 => x"AC100006",   -- 172.16.0.6
        3 => x"01020304",   -- 1.2.3.4
        4 => x"FFFFFFFF"    -- 255.255.255.255
    );
    
begin
    
    dut : firewall_rom_checker
        generic map (
            N_RULES => N_RULES
        )
        port map (
            clk         => clk,
            rst         => rst,
            start       => start,
            ip_to_check => ip_to_check,
            busy        => busy,
            drop_fw     => drop_fw,
            done        => done
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
        
        procedure check_ip(
            ip          : std_logic_vector(31 downto 0);
            expect_drop : std_logic;
            test_name   : string
        ) is
        begin

            ip_to_check <= ip;
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';

            wait until rising_edge(clk);
            
            assert busy = '1'
                report "FAIL: " & test_name & " - busy not asserted"
                severity error;
            
            wait until done = '1';
            wait until rising_edge(clk);
            
            if drop_fw = expect_drop then
                report "PASS: " & test_name & " - IP " & ip_to_string(ip) & 
                       " drop=" & std_logic'image(drop_fw) severity note;
                pass_count <= pass_count + 1;
            else
                report "FAIL: " & test_name & " - IP " & ip_to_string(ip) & 
                       " expected drop=" & std_logic'image(expect_drop) & 
                       " got drop=" & std_logic'image(drop_fw) severity error;
                fail_count <= fail_count + 1;
            end if;
            
            wait until rising_edge(clk);
        end procedure;
        
    begin
        rst <= '1';
        start <= '0';
        ip_to_check <= (others => '0');
        wait for CLK_PERIOD * 5;
        report "=== Test 1: Reset Behavior ===" severity note;
        wait until rising_edge(clk);
        
        assert busy = '0' 
            report "FAIL: busy should be '0' after reset" severity error;
        assert drop_fw = '0' 
            report "FAIL: drop_fw should be '0' after reset" severity error;
        assert done = '0' 
            report "FAIL: done should be '0' after reset" severity error;
        
        report "PASS: Reset behavior verified" severity note;
        pass_count <= pass_count + 1;
        
        rst <= '0';
        wait for CLK_PERIOD * 2;

        report "=== Test 2: Blocked IPs (expect drop='1') ===" severity note;
        
        for i in BLOCKED_IPS'range loop
            check_ip(BLOCKED_IPS(i), '1', "Blocked IP " & integer'image(i));
        end loop;
        
        report "=== Test 3: Non-Blocked IPs (expect drop='0') ===" severity note;
        
        for i in NON_BLOCKED_IPS'range loop
            check_ip(NON_BLOCKED_IPS(i), '0', "Non-blocked IP " & integer'image(i));
        end loop;
        
        report "=== Test 4: Reset During Operation ===" severity note;
        
        ip_to_check <= BLOCKED_IPS(0);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until rising_edge(clk);
        
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        
        assert busy = '0'
            report "FAIL: busy should be '0' after reset during operation"
            severity error;
        
        report "PASS: Reset during operation verified" severity note;
        pass_count <= pass_count + 1;
        
        rst <= '0';
        wait for CLK_PERIOD * 2;
        
        report "========================================" severity note;
        report "Test Summary:" severity note;
        report "  PASSED: " & integer'image(pass_count) severity note;
        report "  FAILED: " & integer'image(fail_count) severity note;
        report "========================================" severity note;
        
        assert fail_count = 0
            report "SOME TESTS FAILED!"
            severity error;
        
        if fail_count = 0 then
            report "ALL TESTS PASSED!" severity note;
        end if;
        
        test_done <= true;
        wait;
    end process stim_proc;
    
end architecture tb;
