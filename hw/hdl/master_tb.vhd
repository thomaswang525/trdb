library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity master_tb is
end master_tb;

architecture testbench of master_tb is

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '0';
    signal n_reset : std_logic := '1';

    constant clk_period   : time := 10 ns;
    constant reset_period : time := 2.5 ns;

    signal pixel      : std_logic_vector(11 downto 0);
    signal linevalid  : std_logic;
    signal framevalid : std_logic;

    signal waitrequest : std_logic := '0';
    signal write       : std_logic;
    signal data        : std_logic_vector(31 downto 0);
    signal address     : std_logic_vector(31 downto 0);
    signal byteenable  : std_logic_vector(3 downto 0);
    signal burstcount  : std_logic_vector(3 downto 0);

    signal reg_start : std_logic := '0';
    signal reg_stop  : std_logic := '0';

    signal trigger  : std_logic;
    signal ready    : std_logic;

    constant base : std_logic_vector(31 downto 0) := (others => '0');
    constant size : std_logic_vector(31 downto 0)  := X"000000A0";

begin

    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process clk_process;

    sensor : entity work.cmos_sensor_output_generator
        generic map(pix_depth => 12, max_width => 640, max_height => 480)
        port map(clk         => clk,
                 reset       => reset,
                 reg_start   => reg_start,
                 reg_stop    => reg_stop,
                 frame_valid => framevalid,
                 line_valid  => linevalid,
                 data        => pixel);

    master : entity work.camera_master
        port map(clk     => clk,
                 n_reset => n_reset,

                 pixel      => pixel,
                 linevalid  => linevalid,
                 framevalid => framevalid,

                 waitrequest => waitrequest,
                 write       => write,
                 data        => data,
                 address     => address,
                 byteenable  => byteenable,
                 burstcount  => burstcount,

                 base    => base,
                 size    => size,
                 trigger => trigger,
                 ready   => ready);

    test : process
    begin
        wait for clk_period;
        n_reset <= '0';
        reset <= '1';
        wait for reset_period;
        n_reset <= '1';
        reset <= '0';

        wait for 1*clk_period;

        wait until rising_edge(clk);
        reg_start <= '1';
        trigger   <= '1';
        wait until rising_edge(clk);
        trigger   <= '0';

        wait until ready = '1';
        reg_start <= '0';
        reg_stop  <= '1';
        
        wait for 10*clk_period;

        assert false report "test finished" severity failure;
    end process test;

end architecture testbench;
