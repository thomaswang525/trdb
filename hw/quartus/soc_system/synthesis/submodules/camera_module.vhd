library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity camera_module is
    port (clk     : in std_logic;
          n_reset : in std_logic;

          -- slave bus input
          as_address    : in  std_logic_vector(2 downto 0);
          as_read       : in  std_logic;
          as_write      : in  std_logic;
          as_readdata   : out std_logic_vector(31 downto 0);
          as_writedata  : in  std_logic_vector(31 downto 0);

          -- master bus output
          am_waitrequest : in  std_logic;
          am_write       : out std_logic;
          am_data        : out std_logic_vector(31 downto 0);
          am_address     : out std_logic_vector(31 downto 0);
          am_byteenable  : out std_logic_vector(3 downto 0);
          am_burstcount  : out std_logic_vector(3 downto 0);

          -- camera interface import/export
          cam_pixel      : in  std_logic_vector(11 downto 0);
          cam_linevalid  : in  std_logic;
          cam_framevalid : in  std_logic;
          cam_trigger    : out std_logic);
end entity camera_module;

architecture structural of camera_module is

    signal base    : std_logic_vector(31 downto 0);
    signal size    : std_logic_vector(3 downto 0);
    signal ready   : std_logic;
    signal trigger : std_logic;

begin

    cam_trigger <= trigger;

    slave : entity work.camera_slave
        port map(clk     => clk,
                 n_reset => n_reset,

                 address    => as_address,
                 read       => as_read,
                 write      => as_write,
                 readdata   => as_readdata,
                 writedata  => as_writedata,

                 trigger => trigger,
                 base    => base,
                 size    => size,
                 ready   => ready);

    master : entity work.camera_master
        port map(clk     => clk,
                 n_reset => n_reset,

                 pixel      => cam_pixel,
                 linevalid  => cam_linevalid,
                 framevalid => cam_framevalid,

                 waitrequest => am_waitrequest,
                 write       => am_write,
                 data        => am_data,
                 address     => am_address,
                 byteenable  => am_byteenable,
                 burstcount  => am_burstcount,

                 base    => base,
                 size    => size,
                 trigger => trigger,
                 ready   => ready);

end architecture structural;

