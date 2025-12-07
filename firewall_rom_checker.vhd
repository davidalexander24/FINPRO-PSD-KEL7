-- File: firewall_rom_checker.vhd
-- Description: Exact-Match Firewall Checker with ROM-based Blocked IP List
-- 
-- This file demonstrates:
--   - MODULE 6 (Loops and Generate): FOR-GENERATE for concurrent comparators
--   - MODULE 8 (FSM): State machine for sequential rule checking
--
-- Behavior:
--   - Compares input IP address against a compile-time constant ROM of blocked IPs
--   - Performs EXACT MATCH only (no CIDR/subnet matching)
--   - Sequential comparison: one rule per clock cycle
--   - Sets drop_fw='1' if any match is found
--
-- Blocked IPs (10 entries - compile-time constant):
--   10.1.0.5        -> x"0A010005"
--   10.1.0.10       -> x"0A01000A"
--   10.1.0.20       -> x"0A010014"
--   192.168.1.100   -> x"C0A80164"
--   192.168.1.101   -> x"C0A80165"
--   172.16.0.5      -> x"AC100005"
--   172.16.1.1      -> x"AC100101"
--   203.0.113.5     -> x"CB007105"
--   198.51.100.10   -> x"C633640A"
--   8.8.8.8         -> x"08080808"

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity firewall_rom_checker is
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
end entity firewall_rom_checker;

architecture rtl of firewall_rom_checker is
    

    type ip_rom_t is array (0 to N_RULES-1) of std_logic_vector(31 downto 0);
    
    constant BLOCKED_IPS : ip_rom_t := (
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
    

    type state_t is (
        IDLE,           
        CHECKING,       
        DONE_STATE      
    );
    
    signal state      : state_t;

    signal rule_index     : integer range 0 to N_RULES;
    signal ip_reg         : std_logic_vector(31 downto 0);
    signal match_found    : std_logic;
    signal busy_reg       : std_logic;
    signal drop_reg       : std_logic;
    signal done_reg       : std_logic;

    type match_array_t is array (0 to N_RULES-1) of std_logic;
    signal concurrent_matches : match_array_t;
    signal any_match_concurrent : std_logic;
    
begin
    
    gen_comparators: for i in 0 to N_RULES-1 generate
        concurrent_matches(i) <= '1' when ip_reg = BLOCKED_IPS(i) else '0';
    end generate gen_comparators;
    
    process(concurrent_matches)
        variable temp : std_logic;
    begin
        temp := '0';
        for i in 0 to N_RULES-1 loop
            temp := temp or concurrent_matches(i);
        end loop;
        any_match_concurrent <= temp;
    end process;
    
    fsm_process : process(clk, rst)
        variable current_rule : std_logic_vector(31 downto 0);
        variable check_count  : integer range 0 to N_RULES + 1;
    begin
        if rst = '1' then
            state       <= IDLE;
            rule_index  <= 0;
            ip_reg      <= (others => '0');
            match_found <= '0';
            busy_reg    <= '0';
            drop_reg    <= '0';
            done_reg    <= '0';
            
        elsif rising_edge(clk) then
            done_reg <= '0';
            
            case state is
                when IDLE =>
                    busy_reg    <= '0';
                    drop_reg    <= '0';
                    match_found <= '0';
                    rule_index  <= 0;
                    
                    if start = '1' then
                        ip_reg   <= ip_to_check;
                        busy_reg <= '1';
                        state    <= CHECKING;
                    end if;
                    
                when CHECKING =>
                    busy_reg <= '1';

                    if rule_index < N_RULES then
                        current_rule := BLOCKED_IPS(rule_index);

                        if ip_reg = current_rule then
                            match_found <= '1';
                            drop_reg    <= '1';
                  
                            state <= DONE_STATE;
                        else
                            if rule_index >= N_RULES - 1 then
                                state <= DONE_STATE;
                            else
                                rule_index <= rule_index + 1;
                            end if;
                        end if;
                    else
                        state <= DONE_STATE;
                    end if;
                    
                when DONE_STATE =>
                    busy_reg <= '0';
                    done_reg <= '1';
                    state    <= IDLE;
                    
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process fsm_process;

    busy    <= busy_reg;
    drop_fw <= drop_reg;
    done    <= done_reg;
    
end architecture rtl;
