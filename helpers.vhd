-- File: helpers.vhd
-- Description: Helper functions and procedures package for IPv4 packet processor
-- 
-- This file demonstrates MODULE 7 (Functions and Procedures) requirements:
--   - Pure functions for ones-complement arithmetic
--   - Function to convert prefix length to subnet mask
--   - Procedures for testbench reporting and formatting

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package helpers is
    
    function ones_complement_add(
        a : unsigned(15 downto 0);
        b : unsigned(15 downto 0)
    ) return unsigned;
    
    function ones_complement_add_fold(
        a : unsigned(15 downto 0);
        b : unsigned(15 downto 0)
    ) return unsigned;
    
    function prefix_to_mask(
        prefix : integer range 0 to 32
    ) return std_logic_vector;
    
    function ip_to_string(
        ip : std_logic_vector(31 downto 0)
    ) return string;
    
    function compute_ipv4_checksum(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector;
    
    procedure report_test_result(
        test_name   : in string;
        passed      : in boolean;
        signal pass_count : inout integer;
        signal fail_count : inout integer
    );
    
    procedure wait_cycles(
        signal clk    : in std_logic;
        constant n    : in positive
    );
    
    function extract_ttl(
        header : std_logic_vector(159 downto 0)
    ) return unsigned;
    
    function extract_src_ip(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector;
    
    function extract_dst_ip(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector;
    
end package helpers;

package body helpers is
    
    function ones_complement_add(
        a : unsigned(15 downto 0);
        b : unsigned(15 downto 0)
    ) return unsigned is
        variable sum : unsigned(16 downto 0);
    begin
        sum := ('0' & a) + ('0' & b);
        return sum;
    end function ones_complement_add;
    
    function ones_complement_add_fold(
        a : unsigned(15 downto 0);
        b : unsigned(15 downto 0)
    ) return unsigned is
        variable sum17  : unsigned(16 downto 0);
        variable sum16  : unsigned(15 downto 0);
        variable carry  : unsigned(15 downto 0);
    begin
        sum17 := ones_complement_add(a, b);
        sum16 := sum17(15 downto 0);
        carry := (others => '0');
        carry(0) := sum17(16);
        sum16 := sum16 + carry;
        return sum16;
    end function ones_complement_add_fold;
    
    function prefix_to_mask(
        prefix : integer range 0 to 32
    ) return std_logic_vector is
        variable mask : std_logic_vector(31 downto 0);
    begin
        mask := (others => '0');
        for i in 31 downto 0 loop
            if (31 - i) < prefix then
                mask(i) := '1';
            else
                mask(i) := '0';
            end if;
        end loop;
        return mask;
    end function prefix_to_mask;
    
    function ip_to_string(
        ip : std_logic_vector(31 downto 0)
    ) return string is
        variable octet1, octet2, octet3, octet4 : integer;
    begin
        octet1 := to_integer(unsigned(ip(31 downto 24)));
        octet2 := to_integer(unsigned(ip(23 downto 16)));
        octet3 := to_integer(unsigned(ip(15 downto 8)));
        octet4 := to_integer(unsigned(ip(7 downto 0)));
        return integer'image(octet1) & "." & 
               integer'image(octet2) & "." & 
               integer'image(octet3) & "." & 
               integer'image(octet4);
    end function ip_to_string;
    
    function compute_ipv4_checksum(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector is
        variable sum      : unsigned(31 downto 0);
        variable word     : unsigned(15 downto 0);
        variable result   : unsigned(15 downto 0);
        variable hdr_zero : std_logic_vector(159 downto 0);
    begin
        hdr_zero := header;
        hdr_zero(79 downto 64) := (others => '0');
        
        sum := (others => '0');
        
        for i in 0 to 9 loop
            word := unsigned(hdr_zero(159 - i*16 downto 144 - i*16));
            sum := sum + ("0000000000000000" & word);
        end loop;
        
        while sum(31 downto 16) /= x"0000" loop
            sum := ("0000000000000000" & sum(15 downto 0)) + 
                   ("0000000000000000" & sum(31 downto 16));
        end loop;
        
        result := not sum(15 downto 0);
        
        return std_logic_vector(result);
    end function compute_ipv4_checksum;
    
    procedure report_test_result(
        test_name   : in string;
        passed      : in boolean;
        signal pass_count : inout integer;
        signal fail_count : inout integer
    ) is
    begin
        if passed then
            report "PASS: " & test_name severity note;
            pass_count <= pass_count + 1;
        else
            report "FAIL: " & test_name severity error;
            fail_count <= fail_count + 1;
        end if;
    end procedure report_test_result;
    
    procedure wait_cycles(
        signal clk    : in std_logic;
        constant n    : in positive
    ) is
    begin
        for i in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure wait_cycles;
    
    function extract_ttl(
        header : std_logic_vector(159 downto 0)
    ) return unsigned is
    begin
        return unsigned(header(95 downto 88));
    end function extract_ttl;
    
    function extract_src_ip(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector is
    begin
        return header(63 downto 32);
    end function extract_src_ip;
    
    function extract_dst_ip(
        header : std_logic_vector(159 downto 0)
    ) return std_logic_vector is
    begin
        return header(31 downto 0);
    end function extract_dst_ip;
    
end package body helpers;
