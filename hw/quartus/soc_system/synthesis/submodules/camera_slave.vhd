library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The camera slave module comprises the programmable interface writeable
-- and readable by a NIOS2 softcore program.
entity camera_slave is
    port(clk     : in std_logic;
         n_reset : in std_logic;

         address   : in  std_logic_vector(2 downto 0);
         read      : in  std_logic;
         write     : in  std_logic;
         readdata  : out std_logic_vector(31 downto 0);
         writedata : in  std_logic_vector(31 downto 0);

         trigger : out std_logic;
         base    : out std_logic_vector(31 downto 0);
         size    : out std_logic_vector(3 downto 0);
         ready   : in  std_logic);
end entity camera_slave;

architecture behaviour of camera_slave is

    signal reset_reg   : std_logic;
    signal address_reg : std_logic_vector(31 downto 0);
    signal size_reg    : std_logic_vector(3 downto 0);
    signal ready_reg   : std_logic;
    signal trigger_reg : std_logic;

begin

    base    <= address_reg;
    size    <= size_reg;
    trigger <= trigger_reg;

    pi_write : process(clk, n_reset)
    begin
        if n_reset = '0' then
            reset_reg   <= '1';
            address_reg <= (others => '0');
            size_reg    <= (others => '0');
            ready_reg   <= '0';
            trigger_reg <= '0';
        elsif rising_edge(clk) then
            if write = '1' then
                case address is
                    when "000"  => reset_reg   <= writedata(0);
                    when "001"  => address_reg <= writedata;
                    when "010"  => size_reg    <= writedata(3 downto 0);
                    when "011"  => null;
                    when "100"  => trigger_reg <= writedata(0);
                    when others => null;
                end case;
            end if;
        end if;
    end process pi_write;

    pi_read : process(clk)
    begin
        if rising_edge(clk) then
            readdata <= (others => '0');
            if read = '1' then
                case address is
                    when "000"  => readdata(0)          <= reset_reg;
                    when "001"  => readdata             <= address_reg;
                    when "010"  => readdata(3 downto 0) <= size_reg;
                    when "011"  => readdata(0)          <= ready;
                    when "100"  => readdata(0)          <= trigger_reg;
                    when others => null;
                end case;
            end if;
        end if;
    end process pi_read;

end architecture behaviour;
