-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
-- Date        : Sun Nov  9 21:41:48 2025
-- Host        : cranberry running 64-bit Ubuntu 22.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub -rename_top result -prefix
--               result_ u_ila_0_stub.vhdl
-- Design      : u_ila_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7vx485tffg1761-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity result is
  Port ( 
    clk : in STD_LOGIC;
    probe0 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe1 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe2 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe3 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe4 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe5 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe6 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe7 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe8 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe9 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe10 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe11 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe12 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe13 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe14 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe15 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe16 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe17 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe18 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe19 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe20 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe21 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe22 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe23 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe24 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe25 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe26 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe27 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe28 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe29 : in STD_LOGIC_VECTOR ( 2 downto 0 );
    probe30 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe31 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe32 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe33 : in STD_LOGIC_VECTOR ( 4 downto 0 );
    probe34 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe35 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe36 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe37 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe38 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe39 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe40 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe41 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe42 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe43 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe44 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe45 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe46 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe47 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe48 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe49 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe50 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe51 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe52 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe53 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe54 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe55 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe56 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe57 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe58 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    probe59 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    probe60 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    probe61 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    probe62 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    probe63 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    probe64 : in STD_LOGIC_VECTOR ( 2 downto 0 );
    probe65 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe66 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe67 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe68 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe69 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe70 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe71 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe72 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe73 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe74 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe75 : in STD_LOGIC_VECTOR ( 6 downto 0 );
    probe76 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe77 : in STD_LOGIC_VECTOR ( 31 downto 0 )
  );

end result;

architecture stub of result is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe0[0:0],probe1[0:0],probe2[0:0],probe3[0:0],probe4[0:0],probe5[0:0],probe6[0:0],probe7[0:0],probe8[0:0],probe9[0:0],probe10[0:0],probe11[0:0],probe12[0:0],probe13[0:0],probe14[0:0],probe15[0:0],probe16[0:0],probe17[0:0],probe18[0:0],probe19[0:0],probe20[0:0],probe21[0:0],probe22[0:0],probe23[0:0],probe24[0:0],probe25[0:0],probe26[0:0],probe27[0:0],probe28[0:0],probe29[2:0],probe30[0:0],probe31[7:0],probe32[0:0],probe33[4:0],probe34[7:0],probe35[7:0],probe36[7:0],probe37[7:0],probe38[7:0],probe39[7:0],probe40[7:0],probe41[7:0],probe42[7:0],probe43[7:0],probe44[7:0],probe45[7:0],probe46[7:0],probe47[7:0],probe48[7:0],probe49[7:0],probe50[0:0],probe51[0:0],probe52[0:0],probe53[0:0],probe54[7:0],probe55[7:0],probe56[7:0],probe57[7:0],probe58[11:0],probe59[11:0],probe60[11:0],probe61[11:0],probe62[3:0],probe63[3:0],probe64[2:0],probe65[0:0],probe66[0:0],probe67[0:0],probe68[0:0],probe69[0:0],probe70[0:0],probe71[0:0],probe72[0:0],probe73[0:0],probe74[0:0],probe75[6:0],probe76[0:0],probe77[31:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "ila,Vivado 2022.2";
begin
end;
