-- File: micro_controller.vhd
-- Description: Microcontroller for Packet Processor - Interprets Microinstructions
-- 
-- This file demonstrates MODULE 9 (Microprogramming) requirements:
--   - Microinstruction interpretation and execution
--   - Microprogram counter (MPC) management
--   - Control signal generation from microinstructions
--
-- The microcontroller:
--   1. Reads microinstructions from microcode_rom
--   2. Decodes control fields
--   3. Generates control signals for processing units
--   4. Manages microprogram counter sequencing
--   5. Handles conditional branching (wait states)
--
-- Microinstruction Format (from microcode_rom.vhd):
--   Bit 15    : TTL_EN     - Enable TTL unit
--   Bit 14    : CKSUM_EN   - Enable Checksum unit
--   Bit 13    : FW_START   - Start firewall checker
--   Bit 12    : FW_SRC     - Check source IP (1) or dest IP (0)
--   Bit 11    : WAIT_FW    - Wait for firewall to complete
--   Bit 10    : SET_VALID  - Set output valid flag
--   Bit 9     : SET_DONE   - Set done flag (processing complete)
--   Bits 8:5  : RESERVED
--   Bits 4:0  : NEXT_ADDR  - Next microinstruction address

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity micro_controller is
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
        
        dbg_mpc         : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        dbg_uinstr      : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity micro_controller;

architecture rtl of micro_controller is
    
    component microcode_rom is
        generic (
            ADDR_WIDTH : integer := 4;
            DATA_WIDTH : integer := 16
        );
        port (
            addr        : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            micro_instr : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    signal mpc          : unsigned(ADDR_WIDTH-1 downto 0);
    signal mpc_next     : unsigned(ADDR_WIDTH-1 downto 0);
    
    signal micro_instr  : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal ui_ttl_en    : std_logic;
    signal ui_cksum_en  : std_logic;
    signal ui_fw_start  : std_logic;
    signal ui_fw_src    : std_logic;
    signal ui_wait_fw   : std_logic;
    signal ui_set_valid : std_logic;
    signal ui_set_done  : std_logic;
    signal ui_next_addr : unsigned(4 downto 0);
    
    signal running      : std_logic;
    signal wait_state   : std_logic;
    
    signal ttl_en_reg   : std_logic;
    signal cksum_en_reg : std_logic;
    signal fw_start_reg : std_logic;
    signal fw_src_reg   : std_logic;
    signal valid_reg    : std_logic;
    signal done_reg     : std_logic;
    signal busy_reg     : std_logic;
    
begin
    
    u_microcode_rom : microcode_rom
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            addr        => std_logic_vector(mpc),
            micro_instr => micro_instr
        );
    
    ui_ttl_en    <= micro_instr(15);
    ui_cksum_en  <= micro_instr(14);
    ui_fw_start  <= micro_instr(13);
    ui_fw_src    <= micro_instr(12);
    ui_wait_fw   <= micro_instr(11);
    ui_set_valid <= micro_instr(10);
    ui_set_done  <= micro_instr(9);
    ui_next_addr <= unsigned(micro_instr(4 downto 0));
    
    mpc_next_logic : process(mpc, ui_next_addr, ui_wait_fw, fw_done, start, running)
    begin
        if running = '0' then
            if start = '1' then
                mpc_next <= to_unsigned(1, ADDR_WIDTH);
            else
                mpc_next <= (others => '0');
            end if;
        elsif ui_wait_fw = '1' then
            if fw_done = '1' then
                mpc_next <= resize(ui_next_addr, ADDR_WIDTH);
            else
                mpc_next <= mpc;
            end if;
        else
            mpc_next <= resize(ui_next_addr, ADDR_WIDTH);
        end if;
    end process mpc_next_logic;
    
    mpc_register : process(clk, rst)
    begin
        if rst = '1' then
            mpc         <= (others => '0');
            running     <= '0';
            wait_state  <= '0';
            ttl_en_reg  <= '0';
            cksum_en_reg<= '0';
            fw_start_reg<= '0';
            fw_src_reg  <= '0';
            valid_reg   <= '0';
            done_reg    <= '0';
            busy_reg    <= '0';
            
        elsif rising_edge(clk) then
            ttl_en_reg   <= '0';
            cksum_en_reg <= '0';
            fw_start_reg <= '0';
            done_reg     <= '0';
            
            if running = '0' then
                valid_reg <= '0';
                
                if start = '1' then
                    running  <= '1';
                    busy_reg <= '1';
                    mpc      <= to_unsigned(1, ADDR_WIDTH);
                end if;
                
            else
                
                if ui_wait_fw = '1' and fw_done = '0' then
                    wait_state <= '1';
                else
                    wait_state <= '0';
                    
                    ttl_en_reg   <= ui_ttl_en;
                    cksum_en_reg <= ui_cksum_en;
                    fw_start_reg <= ui_fw_start;
                    fw_src_reg   <= ui_fw_src;
                    
                    if ui_set_valid = '1' then
                        valid_reg <= '1';
                    end if;
                    
                    if ui_set_done = '1' then
                        done_reg <= '1';
                        running  <= '0';
                        busy_reg <= '0';
                    end if;
                    
                    mpc <= mpc_next;
                    
                    if mpc_next = 0 then
                        running <= '0';
                        busy_reg <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process mpc_register;
    
    ttl_enable   <= ttl_en_reg;
    cksum_enable <= cksum_en_reg;
    fw_start     <= fw_start_reg;
    fw_check_src <= fw_src_reg;
    proc_valid   <= valid_reg;
    proc_done    <= done_reg;
    proc_busy    <= busy_reg;
    
    dbg_mpc    <= std_logic_vector(mpc);
    dbg_uinstr <= micro_instr;
    
end architecture rtl;
