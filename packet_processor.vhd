-- File: packet_processor.vhd
-- Description: Top-Level Structural Entity for IPv4 Packet Processor
-- 
-- This file demonstrates MODULE 5 (Structural Description) requirements:
--   - Component declarations for all submodules
--   - Component instantiation with port mapping
--   - Internal signal wiring between modules
--   - Hierarchical design organization
--
-- System Overview:
--   The packet processor accepts a 160-bit IPv4 header and performs:
--   1. TTL decrement (drop if TTL expires)
--   2. Checksum recomputation
--   3. Firewall exact-match checking (source and destination IP)
--   4. Combines drop reasons and outputs processed header
--
-- Processing Flow (controlled by microcontroller):
--   START -> TTL Unit -> Checksum Unit -> Firewall (src) -> 
--   Firewall (dst) -> OUTPUT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helpers.all;

entity packet_processor is
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
end entity packet_processor;

architecture structural of packet_processor is

    component ttl_unit is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            enable        : in  std_logic;
            header_in     : in  std_logic_vector(159 downto 0);
            header_ttl_out: out std_logic_vector(159 downto 0);
            drop_ttl      : out std_logic;
            valid         : out std_logic
        );
    end component;

    component checksum_unit is
        generic (
            VERIFY_INPUT_CHECKSUM : boolean := true
        );
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            enable          : in  std_logic;
            header_in       : in  std_logic_vector(159 downto 0);
            header_cksum_out: out std_logic_vector(159 downto 0);
            checksum_error  : out std_logic;
            valid           : out std_logic
        );
    end component;

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

    component micro_controller is
        generic (
            ADDR_WIDTH : integer := 4;
            DATA_WIDTH : integer := 16
        );
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            start           : in  std_logic;
            fw_done         : in  std_logic;
            fw_busy         : in  std_logic;
            ttl_enable      : out std_logic;
            cksum_enable    : out std_logic;
            fw_start        : out std_logic;
            fw_check_src    : out std_logic;
            proc_valid      : out std_logic;
            proc_done       : out std_logic;
            proc_busy       : out std_logic;
            dbg_mpc         : out std_logic_vector(3 downto 0);
            dbg_uinstr      : out std_logic_vector(15 downto 0)
        );
    end component;

    signal ctrl_ttl_en      : std_logic;
    signal ctrl_cksum_en    : std_logic;
    signal ctrl_fw_start    : std_logic;
    signal ctrl_fw_check_src: std_logic;
    signal ctrl_valid       : std_logic;
    signal ctrl_done        : std_logic;
    signal ctrl_busy        : std_logic;

    signal ttl_header_out   : std_logic_vector(159 downto 0);
    signal ttl_drop         : std_logic;
    signal ttl_valid        : std_logic;

    signal cksum_header_out : std_logic_vector(159 downto 0);
    signal cksum_error      : std_logic;
    signal cksum_valid      : std_logic;

    signal fw_busy          : std_logic;
    signal fw_drop          : std_logic;
    signal fw_done          : std_logic;
    signal fw_ip_to_check   : std_logic_vector(31 downto 0);

    signal fw_drop_src_latch: std_logic;
    signal fw_drop_dst_latch: std_logic;
    signal fw_combined_drop : std_logic;

    signal header_reg       : std_logic_vector(159 downto 0);
    signal header_processed : std_logic_vector(159 downto 0);

    signal drop_ttl_latch   : std_logic;
    signal drop_cksum_latch : std_logic;

    signal drop_final       : std_logic;
    signal output_valid     : std_logic;

    signal dbg_mpc          : std_logic_vector(3 downto 0);
    signal dbg_uinstr       : std_logic_vector(15 downto 0);

begin

    u_micro_ctrl : micro_controller
        generic map (
            ADDR_WIDTH => 4,
            DATA_WIDTH => 16
        )
        port map (
            clk          => clk,
            rst          => rst,
            start        => start,
            fw_done      => fw_done,
            fw_busy      => fw_busy,
            ttl_enable   => ctrl_ttl_en,
            cksum_enable => ctrl_cksum_en,
            fw_start     => ctrl_fw_start,
            fw_check_src => ctrl_fw_check_src,
            proc_valid   => ctrl_valid,
            proc_done    => ctrl_done,
            proc_busy    => ctrl_busy,
            dbg_mpc      => dbg_mpc,
            dbg_uinstr   => dbg_uinstr
        );

    u_ttl : ttl_unit
        port map (
            clk            => clk,
            rst            => rst,
            enable         => ctrl_ttl_en,
            header_in      => header_reg,
            header_ttl_out => ttl_header_out,
            drop_ttl       => ttl_drop,
            valid          => ttl_valid
        );

    u_checksum : checksum_unit
        generic map (
            VERIFY_INPUT_CHECKSUM => VERIFY_CHECKSUM
        )
        port map (
            clk              => clk,
            rst              => rst,
            enable           => ctrl_cksum_en,
            header_in        => ttl_header_out,
            header_cksum_out => cksum_header_out,
            checksum_error   => cksum_error,
            valid            => cksum_valid
        );

    u_firewall : firewall_rom_checker
        generic map (
            N_RULES => N_RULES
        )
        port map (
            clk         => clk,
            rst         => rst,
            start       => ctrl_fw_start,
            ip_to_check => fw_ip_to_check,
            busy        => fw_busy,
            drop_fw     => fw_drop,
            done        => fw_done
        );

    fw_ip_to_check <= cksum_header_out(63 downto 32) when ctrl_fw_check_src = '1'
                      else cksum_header_out(31 downto 0);

    latch_process : process(clk, rst)
    begin
        if rst = '1' then
            header_reg       <= (others => '0');
            header_processed <= (others => '0');
            drop_ttl_latch   <= '0';
            drop_cksum_latch <= '0';
            fw_drop_src_latch<= '0';
            fw_drop_dst_latch<= '0';

        elsif rising_edge(clk) then
            if start = '1' then
                header_reg       <= header_in;
                drop_ttl_latch   <= '0';
                drop_cksum_latch <= '0';
                fw_drop_src_latch<= '0';
                fw_drop_dst_latch<= '0';
            end if;

            if ttl_valid = '1' then
                drop_ttl_latch <= ttl_drop;
            end if;

            if cksum_valid = '1' then
                drop_cksum_latch <= cksum_error;
                header_processed <= cksum_header_out;
            end if;

            if fw_done = '1' then
                if ctrl_fw_check_src = '1' then
                    fw_drop_src_latch <= fw_drop;
                else
                    fw_drop_dst_latch <= fw_drop;
                end if;
            end if;
        end if;
    end process latch_process;

    fw_combined_drop <= fw_drop_src_latch or fw_drop_dst_latch;
    drop_final       <= drop_ttl_latch or drop_cksum_latch or fw_combined_drop;

    busy        <= ctrl_busy;
    valid       <= ctrl_valid;
    drop        <= drop_final;
    header_out  <= header_processed;

    dbg_drop_ttl   <= drop_ttl_latch;
    dbg_drop_fw    <= fw_combined_drop;
    dbg_drop_cksum <= drop_cksum_latch;

end architecture structural;
