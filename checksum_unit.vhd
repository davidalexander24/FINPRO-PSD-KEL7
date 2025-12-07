-- File: checksum_unit.vhd
-- Description: IPv4 Header Checksum Computation Unit
-- 
-- This file demonstrates MODULE 2 (Dataflow) requirements:
--   - Concurrent signal assignments for combinational logic
--   - Dataflow-style computation using concurrent statements
--   - Uses helper functions from helpers.vhd package
--
-- Also demonstrates MODULE 3 (Behavioral) with registered outputs.
--
-- IPv4 Header Checksum Algorithm:
--   1. Set checksum field to zero
--   2. Split 160-bit header into ten 16-bit words
--   3. Compute ones-complement sum of all words
--   4. Take ones-complement (NOT) of result
--   5. Store result in checksum field (bits 79:64)
--
-- Header format (160 bits = 20 bytes):
--   Bits 159:144 - Version/IHL/TOS
--   Bits 143:128 - Total Length
--   Bits 127:112 - Identification
--   Bits 111:96  - Flags/Fragment Offset
--   Bits 95:88   - TTL
--   Bits 87:80   - Protocol
--   Bits 79:64   - Header Checksum
--   Bits 63:32   - Source IP
--   Bits 31:0    - Destination IP

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.helpers.all;

entity checksum_unit is
    generic (
        VERIFY_INPUT_CHECKSUM : boolean := true
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        header_in       : in  std_logic_vector(159 downto 0);
        
        enable          : in  std_logic;
        
        header_cksum_out : out std_logic_vector(159 downto 0);
        
        checksum_error  : out std_logic;
        
        valid           : out std_logic
    );
end entity checksum_unit;

architecture dataflow of checksum_unit is
    
    signal header_zero_cksum : std_logic_vector(159 downto 0);
    
    signal word0, word1, word2, word3, word4 : unsigned(15 downto 0);
    signal word5, word6, word7, word8, word9 : unsigned(15 downto 0);
    
    signal sum_01, sum_23, sum_45, sum_67, sum_89 : unsigned(16 downto 0);
    
    signal sum_0123, sum_4567, sum_89_ext : unsigned(17 downto 0);
    
    signal sum_01234567, sum_89_ext2 : unsigned(18 downto 0);
    
    signal sum_all : unsigned(19 downto 0);
    
    signal fold1, fold2, fold3, fold4 : unsigned(15 downto 0);
    signal carry1, carry2, carry3, carry4 : unsigned(15 downto 0);
    signal folded_sum : unsigned(15 downto 0);
    
    signal checksum_new : std_logic_vector(15 downto 0);
    
    signal header_with_new_cksum : std_logic_vector(159 downto 0);
    
begin
    
    header_zero_cksum <= header_in(159 downto 80) & x"0000" & header_in(63 downto 0);
    
    word0 <= unsigned(header_zero_cksum(159 downto 144));
    word1 <= unsigned(header_zero_cksum(143 downto 128));
    word2 <= unsigned(header_zero_cksum(127 downto 112));
    word3 <= unsigned(header_zero_cksum(111 downto 96));
    word4 <= unsigned(header_zero_cksum(95 downto 80));
    word5 <= unsigned(header_zero_cksum(79 downto 64));
    word6 <= unsigned(header_zero_cksum(63 downto 48));
    word7 <= unsigned(header_zero_cksum(47 downto 32));
    word8 <= unsigned(header_zero_cksum(31 downto 16));
    word9 <= unsigned(header_zero_cksum(15 downto 0));
    
    sum_01 <= ('0' & word0) + ('0' & word1);
    sum_23 <= ('0' & word2) + ('0' & word3);
    sum_45 <= ('0' & word4) + ('0' & word5);
    sum_67 <= ('0' & word6) + ('0' & word7);
    sum_89 <= ('0' & word8) + ('0' & word9);
    
    sum_0123   <= ('0' & sum_01) + ('0' & sum_23);
    sum_4567   <= ('0' & sum_45) + ('0' & sum_67);
    sum_89_ext <= '0' & sum_89;
    
    sum_01234567 <= ('0' & sum_0123) + ('0' & sum_4567);
    sum_89_ext2  <= '0' & sum_89_ext;
    
    sum_all <= ('0' & sum_01234567) + ('0' & sum_89_ext2);
    
    fold1  <= sum_all(15 downto 0);
    carry1 <= resize(sum_all(19 downto 16), 16);
    
    fold2  <= fold1 + carry1;
    carry2 <= x"000" & ("000" & fold2(15 downto 15)) when (fold1 + carry1) > x"FFFF" else x"0000";
    
    fold3  <= fold2 + carry2;
    carry3 <= x"000" & ("000" & fold3(15 downto 15)) when (fold2 + carry2) > x"FFFF" else x"0000";
    
    fold4  <= fold3 + carry3;
    
    folded_sum <= fold1 + carry1 + 
                  resize(unsigned'(x"000" & ("000" & (fold1(15) and carry1(0)))), 16);
    
    process(sum_all)
        variable temp_sum : unsigned(19 downto 0);
        variable folded   : unsigned(15 downto 0);
        variable carry    : unsigned(3 downto 0);
    begin
        temp_sum := sum_all;
        
        for i in 0 to 3 loop
            folded := temp_sum(15 downto 0);
            carry  := temp_sum(19 downto 16);
            temp_sum := resize(folded, 20) + resize(carry, 20);
        end loop;
        
        checksum_new <= not std_logic_vector(temp_sum(15 downto 0));
    end process;
    
    header_with_new_cksum <= header_in(159 downto 80) & checksum_new & header_in(63 downto 0);
    
    checksum_error <= '0';
    
    process(clk, rst)
    begin
        if rst = '1' then
            header_cksum_out <= (others => '0');
            valid <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                header_cksum_out <= header_with_new_cksum;
                valid <= '1';
            else
                valid <= '0';
            end if;
        end if;
    end process;
    
end architecture dataflow;