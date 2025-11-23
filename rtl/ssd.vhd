
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ssd is
    Port (
        bin_in  : in  STD_LOGIC_VECTOR(3 downto 0);  -- Binary input (0-9)
        ssd_out : out STD_LOGIC_VECTOR(6 downto 0)   -- Seven segment output (active low)
    );
end ssd;

architecture Behavioral of ssd is
begin
    process(bin_in)
    begin
        case bin_in is
            when "0000" => ssd_out <= "1000000"; -- 0
            when "0001" => ssd_out <= "1111001"; -- 1
            when "0010" => ssd_out <= "0100100"; -- 2
            when "0011" => ssd_out <= "0110000"; -- 3
            when "0100" => ssd_out <= "0011001"; -- 4
            when "0101" => ssd_out <= "0010010"; -- 5
            when "0110" => ssd_out <= "0000010"; -- 6
            when "0111" => ssd_out <= "1111000"; -- 7
            when "1000" => ssd_out <= "0000000"; -- 8
            when "1001" => ssd_out <= "0010000"; -- 9
            when others => ssd_out <= "1111111"; -- Blank
        end case;
    end process;
end Behavioral;