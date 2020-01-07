-- #############################################################################
-- camera_master.vhd
--
-- BOARD         : DE0-Nano-SoC from Terasic
-- Author        : Andrea Caforio and Gabriel Tornare
-- Revision      : 0.1
-- Creation date : 07/01/2020
--
-- This file contains the implementation of the master unit.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The master unit takes care of parsing the raw pixel data that
-- stems from the camera sensor and convert it into a 320x240 565-RGB
-- image in memory.
entity camera_master is
    port(clk     : in std_logic;
         n_reset : in std_logic;

         -- TRDB-D5M signals.
         pixel      : in std_logic_vector(11 downto 0);
         linevalid  : in std_logic;
         framevalid : in std_logic;

         -- Avalon bus signals
         waitrequest : in  std_logic;
         write       : out std_logic;
         data        : out std_logic_vector(31 downto 0);
         address     : out std_logic_vector(31 downto 0);
         byteenable  : out std_logic_vector(3 downto 0);
         burstcount  : out std_logic_vector(3 downto 0);

         -- Slave registers (programmable interface)
         base    : in  std_logic_vector(31 downto 0);
         size    : in  std_logic_vector(31 downto 0);
         trigger : in  std_logic;
         ready   : out std_logic);
end entity camera_master;

architecture behaviour of camera_master is

    signal location       : std_logic_vector(31 downto 0);
    signal reset_location : std_logic;
    signal inc_location   : std_logic;

    signal burst       : integer range 0 to 7;
    signal reset_burst : std_logic;
    signal dec_burst   : std_logic;

    signal color        : std_logic_vector(31 downto 0);
    signal new_color    : std_logic_vector(31 downto 0);
    signal stage_color  : std_logic_vector(2 downto 0);
    signal update_color : std_logic;

    signal f0_data         : std_logic_vector(11 downto 0);
    signal f0_writerequest : std_logic;
    signal f0_readrequest  : std_logic;
    signal f0_count        : std_logic_vector(9 downto 0);

    signal f1_almostfull   : std_logic;
    signal f1_writerequest : std_logic;
    signal f1_readrequest  : std_logic;
    signal f1_count        : std_logic_vector(5 downto 0);

    signal count       : integer range 0 to 350000;
    signal pc          : integer range 0 to 5000000;
    signal inc_count   : std_logic;
    signal reset_count : std_logic;

    signal status : std_logic;

    constant size_const : std_logic_vector(31 downto 0) := X"00009600";

    type read_state_type is (start, idle_0, rg, idle_1, b1, g1, b2, g2);
    signal read_state, read_state_next : read_state_type;

    type store_state_type is (idle, trans);
    signal store_state, store_state_next : store_state_type;

begin

    ready <= status;

    read_state_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            read_state <= start;
        elsif rising_edge(clk) then
            read_state <= read_state_next;
        end if;
    end process read_state_reg;

    -- The read finit-state machine handles the parsing, buffering
    -- and conversion of the raw pixel data.
    --
    -- start:  inactive state before and after capture of a frame.
    -- idle_0: when triggered upon a new capture, or start of even-numbered rows.
    -- rg:     even-numbered rows (green1, red).
    -- idle_1: start of odd-numbered rows.
    -- b1:     blue color of pixel1.
    -- g1:     green2 color of pixel1.
    -- b1:     blue color of pixel2.
    -- g1:     green2 color of pixel2.
    read_state_fsm : process(read_state, linevalid, framevalid, trigger, status, color, f0_data, pixel)
    begin

        read_state_next <= read_state;

        f0_writerequest <= '0';
        f0_readrequest  <= '0';
        f1_writerequest <= '0';
        update_color    <= '0';
        reset_location  <= '0';
        reset_count     <= '0';
        stage_color     <= "111";

        case read_state is
            when start =>
                reset_location <= '1';
                reset_count    <= '1';
                if trigger = '1' then
                    read_state_next <= idle_0;
                end if;

            when idle_0 =>
                read_state_next <= idle_0;
                if status = '1' then -- frame has been completed.
                    read_state_next <= start;
                elsif linevalid = '1' and framevalid = '1' then -- start of a new line
                    read_state_next <= rg;
                    f0_writerequest <= '1';
                end if;

            when rg =>
                read_state_next <= rg;
                f0_writerequest <= '1'; -- buffer row in fifo_0
                if linevalid = '0' then -- line end
                    read_state_next <= idle_1;
                    f0_writerequest <= '0';
                end if;

            when idle_1 =>
                read_state_next <= idle_1;
                if linevalid = '1' and framevalid = '1' then -- new of a new line
                    read_state_next <= g1;
                    update_color    <= '1';
                    f0_readrequest  <= '1';
                    stage_color     <= "000";
                end if;

            when b1 =>
                if linevalid = '0' then
                    read_state_next <= idle_0; -- line end
                else
                    update_color    <= '1';
                    read_state_next <= g1;
                    f0_readrequest  <= '1';
                    stage_color     <= "000";
                end if;
            when g1 =>
                read_state_next <= b2;
                f0_readrequest  <= '1';
                update_color    <= '1';
                stage_color     <= "001";
            when b2 =>
                read_state_next <= g2;
                f0_readrequest  <= '1';
                update_color    <= '1';
                stage_color     <= "010";
            when g2 =>
                read_state_next <= b1;
                f1_writerequest <= '1';
                f0_readrequest  <= '1';
                stage_color     <= "011";
        end case;
    end process read_state_fsm;

    -- Pixel conversion unit convert 8 12-bit color pixels to
    -- two 565-RGB pixels that will be stored in memory.
    color_alu : process(stage_color, color, pixel, f0_data)
        variable b, r                         : std_logic_vector(4 downto 0);
        variable g1, g2                       : std_logic_vector(11 downto 0);
        variable g1g2a, g1g2b                 : std_logic_vector(5 downto 0);
        variable g1g2a_tmp, g1g2b_tmp         : std_logic_vector(11 downto 0);
        variable g1g2a_tmp_res, g1g2b_tmp_res : unsigned(12 downto 0);
    begin
        b  := pixel(11 downto 7);
        g1 := f0_data;
        g2 := pixel;
        r  := f0_data(11 downto 7);

        -- Calculate (g1 + g2)/2 for pixel 1 (g1g2a) and pixel 2 (g1g2b). This
        -- may overflow hence the resize to 13 bits.
        -- Note that extracting the most significant bits may not be the best solution.
        g1g2a_tmp_res := resize(unsigned(color(16 downto 5)), 13) + resize(unsigned(g2), 13);
        g1g2a_tmp     := std_logic_vector(g1g2a_tmp_res(12 downto 1));
        g1g2a         := g1g2a_tmp(11 downto 6);

        g1g2b_tmp_res := resize(unsigned(color(31 downto 21)) & '1', 13) + resize(unsigned(g2), 13);
        g1g2b_tmp     := std_logic_vector(g1g2b_tmp_res(12 downto 1));
        g1g2b         := g1g2b_tmp(11 downto 6);

        -- The creation of two pixels happens in four cycles.
        case stage_color is
            when "000"  => new_color <= "000000000000000" & g1 & b;
            when "001"  => new_color <= "0000000000000000" & r & g1g2a & color(4 downto 0);
            when "010"  => new_color <= g1(11 downto 1) & b & color(15 downto 0);
            when "011"  => new_color <= r & g1g2b & color(20 downto 0);
            when others => new_color <= (others => '0');
        end case;
    end process color_alu;

    store_state_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            store_state <= idle;
        elsif rising_edge(clk) then
            store_state <= store_state_next;
        end if;
    end process store_state_reg;

    -- The store finite-state machine takes care of passing the converted
    -- pixels to memory by accessing the Avalon bus. It operates
    -- with burst writes that are triggered once fifo_1 has reached
    -- a certain number of elements.
    store_state_fsm : process(store_state, f1_almostfull, waitrequest, burst)
    begin

        store_state_next <= store_state;

        dec_burst      <= '0';
        f1_readrequest <= '0';
        inc_location   <= '0';
        inc_count      <= '0';
        reset_burst    <= '0';
        write          <= '0';
        burstcount     <= "0000";
        byteenable     <= "0000";
        address        <= (others => '0');

        case store_state is
            when idle =>
                store_state_next <= idle;
                if f1_almostfull = '1' then -- fifo_1 trigger
                    store_state_next <= trans;
                end if;

            when trans =>
                store_state_next <= trans;
                write            <= '1';
                byteenable       <= "1111";
                burstcount       <= "0100";
                address          <= location;
                if burst = 0 then
                    store_state_next <= idle;
                    reset_burst      <= '1';
                    inc_location     <= '1';
                end if;
                -- only update registers if write can take place
                if waitrequest = '0' then
                    dec_burst      <= '1';
                    f1_readrequest <= '1';
                    inc_count      <= '1';
                end if;
        end case;
    end process store_state_fsm;

    -- The location register store the memory address where
    -- the next 2-pixel entry is written to.
    location_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            location <= (others => '0');
        elsif rising_edge(clk) then
            if reset_location = '1' then
                location <= base;
            elsif inc_location = '1' then
                location <= std_logic_vector(unsigned(location) + 16);
            end if;
        end if;
    end process location_reg;

    -- The burst register stores the remaining bursts
    -- until the limit has been reached.
    burst_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            burst <= 3;
        elsif rising_edge(clk) then
            if reset_burst = '1' then
                burst <= 3;
            elsif dec_burst = '1' then
                burst <= burst - 1;
            end if;
        end if;
    end process burst_reg;

    -- The color registers keeps the current 32-bit, two-pixel
    -- entry that is being built during the b1, g1, b2, g2 read FSM states.
    color_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            color <= (others => '0');
        elsif rising_edge(clk) then
            if update_color = '1' then
                color <= new_color;
            end if;
        end if;
    end process color_reg;

    -- The count registers keeps track of how many pixels
    -- have already been written to memory.
    count_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            count <= 0;
        elsif rising_edge(clk) then
            if reset_count = '1' then
                count <= 0;
            elsif inc_count = '1' then
                count <= count + 1;
            end if;
        end if;
    end process count_reg;

    -- The status register indicates whether all the pixels
    -- of a frame have been written to memory.
    status_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            status <= '0';
        elsif rising_edge(clk) then
            if trigger = '1' then
                status <= '0';
            elsif count >= to_integer(unsigned(size_const))-1 then
                status <= '1';
            end if;
        end if;
    end process status_reg;

    -- debug register to count the number of raw pixels
    -- the come from the sensor.
    pc_reg : process(clk, n_reset)
    begin
        if n_reset = '0' then
            pc <= 0;
        elsif rising_edge(clk) then
            if linevalid = '1' and framevalid = '1' then
                pc <= pc + 1;
            end if;
        end if;
    end process pc_reg;

    -- FIFO instantiations.
    f0 : entity work.fifo_0
        port map(clock => clk,
                 data  => pixel,
                 rdreq => f0_readrequest,
                 wrreq => f0_writerequest,
                 q     => f0_data,
                 usedw => f0_count);

    f1 : entity work.fifo_1
        port map(clock       => clk,
                 data        => new_color,
                 rdreq       => f1_readrequest,
                 wrreq       => f1_writerequest,
                 almost_full => f1_almostfull,
                 q           => data,
                 usedw       => f1_count);

end architecture behaviour;

