-- File: microcode_rom.vhd
-- Description: Microcode ROM for Packet Processor Controller
-- 
-- This file demonstrates MODULE 9 (Microprogramming) requirements:
--   - ROM-based microinstruction storage
--   - Microinstruction encoding with multiple control fields
--   - Microprogram sequencing support
--
-- Microinstruction Format (16 bits):
--   Bit 15    : TTL_EN     - Enable TTL unit
--   Bit 14    : CKSUM_EN   - Enable Checksum unit
--   Bit 13    : FW_START   - Start firewall checker
--   Bit 12    : FW_SRC     - Check source IP (1) or dest IP (0)
--   Bit 11    : WAIT_FW    - Wait for firewall to complete
--   Bit 10    : SET_VALID  - Set output valid flag
--   Bit 9     : SET_DONE   - Set done flag (processing complete)
--   Bits 8:5  : RESERVED   - Reserved for future use
--   Bits 4:0  : NEXT_ADDR  - Next microinstruction address (5 bits = 32 max)
--
-- Microprogram Flow:
--   0: IDLE       - Wait for start, branch to TTL_PROC
--   1: TTL_PROC   - Enable TTL processing
--   2: CKSUM_PROC - Enable Checksum processing
--   3: FW_SRC_ST  - Start firewall check on source IP
--   4: FW_SRC_WT  - Wait for firewall (source) to complete
--   5: FW_DST_ST  - Start firewall check on dest IP
--   6: FW_DST_WT  - Wait for firewall (dest) to complete
--   7: OUTPUT     - Set valid and done, return to IDLE

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity microcode_rom is
    generic (
        ADDR_WIDTH : integer := 4;
        DATA_WIDTH : integer := 16
    );
    port (
        addr        : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        
        micro_instr : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity microcode_rom;

architecture rom of microcode_rom is
    
    constant TTL_EN_BIT     : integer := 15;
    constant CKSUM_EN_BIT   : integer := 14;
    constant FW_START_BIT   : integer := 13;
    constant FW_SRC_BIT     : integer := 12;
    constant WAIT_FW_BIT    : integer := 11;
    constant SET_VALID_BIT  : integer := 10;
    constant SET_DONE_BIT   : integer := 9;
    
    type rom_t is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    function make_uinstr(
        ttl_en      : std_logic := '0';
        cksum_en    : std_logic := '0';
        fw_start    : std_logic := '0';
        fw_src      : std_logic := '0';
        wait_fw     : std_logic := '0';
        set_valid   : std_logic := '0';
        set_done    : std_logic := '0';
        next_addr   : integer range 0 to 15 := 0
    ) return std_logic_vector is
        variable result : std_logic_vector(15 downto 0);
    begin
        result := (others => '0');
        result(15) := ttl_en;
        result(14) := cksum_en;
        result(13) := fw_start;
        result(12) := fw_src;
        result(11) := wait_fw;
        result(10) := set_valid;
        result(9)  := set_done;
        result(4 downto 0) := std_logic_vector(to_unsigned(next_addr, 5));
        return result;
    end function;
    
    constant MICROCODE : rom_t := (
        0 => make_uinstr(next_addr => 1),
        
        1 => make_uinstr(ttl_en => '1', next_addr => 2),
        
        2 => make_uinstr(cksum_en => '1', next_addr => 3),
        
        3 => make_uinstr(fw_start => '1', fw_src => '1', next_addr => 4),
        
        4 => make_uinstr(wait_fw => '1', next_addr => 5),
        
        5 => make_uinstr(fw_start => '1', fw_src => '0', next_addr => 6),
        
        6 => make_uinstr(wait_fw => '1', next_addr => 7),
        
        7 => make_uinstr(set_valid => '1', set_done => '1', next_addr => 0),
        
        8  => make_uinstr(next_addr => 0),
        9  => make_uinstr(next_addr => 0),
        10 => make_uinstr(next_addr => 0),
        11 => make_uinstr(next_addr => 0),
        12 => make_uinstr(next_addr => 0),
        13 => make_uinstr(next_addr => 0),
        14 => make_uinstr(next_addr => 0),
        15 => make_uinstr(next_addr => 0)
    );
    
begin
    
    micro_instr <= MICROCODE(to_integer(unsigned(addr)));
    
end architecture rom;
