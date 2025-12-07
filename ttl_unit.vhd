-- File: ttl_unit.vhd
-- Description: TTL (Time To Live) Processing Unit for IPv4 Packet Processor
-- 
-- This file demonstrates MODULE 3 (Behavioral Description) requirements:
--   - Process-based behavioral description
--   - Sequential logic with clock and reset
--   - Conditional logic for TTL decrement and drop detection
--
-- IPv4 Header Layout (relevant fields):
--   - TTL is at byte 8 (bits 95:88 in 160-bit header)
--
-- Behavior:
--   - Extracts TTL field from input header
--   - Decrements TTL by 1 (saturating at 0)
--   - Sets drop_ttl='1' if original TTL <= 1 (packet would expire)
--   - Outputs modified header with new TTL value

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helpers.all;

entity ttl_unit is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        enable        : in  std_logic;

        header_in     : in  std_logic_vector(159 downto 0);

        header_ttl_out: out std_logic_vector(159 downto 0);

        drop_ttl      : out std_logic;

        valid         : out std_logic
    );
end entity ttl_unit;

architecture behavioral of ttl_unit is

    signal ttl_in       : unsigned(7 downto 0);
    signal ttl_out      : unsigned(7 downto 0);
    signal header_reg   : std_logic_vector(159 downto 0);
    signal drop_reg     : std_logic;
    signal valid_reg    : std_logic;

begin

    ttl_process : process(clk, rst)
        variable ttl_temp : unsigned(7 downto 0);
    begin
        if rst = '1' then
            header_reg <= (others => '0');
            drop_reg   <= '0';
            valid_reg  <= '0';

        elsif rising_edge(clk) then
            if enable = '1' then
                ttl_temp := unsigned(header_in(95 downto 88));

                if ttl_temp <= 1 then
                    drop_reg <= '1';
                    ttl_out <= (others => '0');
                else
                    drop_reg <= '0';
                    ttl_out <= ttl_temp - 1;
                end if;

                header_reg <= header_in;

                if ttl_temp <= 1 then
                    header_reg(95 downto 88) <= (others => '0');
                else
                    header_reg(95 downto 88) <= std_logic_vector(ttl_temp - 1);
                end if;

                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process ttl_process;

    header_ttl_out <= header_reg;
    drop_ttl       <= drop_reg;
    valid          <= valid_reg;

end architecture behavioral;
