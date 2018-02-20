--
-- Copyright: 2013, Technical University of Denmark, DTU Compute
-- Author: Martin Schoeberl (martin@jopdesign.com)
--         Rasmus Bo Soerensen (rasmus@rbscloud.dk)
-- Modified: Luca Pezzarossa (lpez@dtu.dk)
-- License: Simplified BSD License
--

-- VHDL top level for Patmos in Chisel on Altera de2-115 board with the EthMac ethernet controller
--
-- Includes some 'magic' VHDL code to generate a reset after FPGA configuration.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity patmos_top is
	port(
		clk           : in    std_logic;
		oLedsPins_led : out   std_logic_vector(8 downto 0);
		iKeysPins_key : in    std_logic_vector(3 downto 0);
		oUartPins_txd : out   std_logic;
		iUartPins_rxd : in    std_logic;
		oSRAM_A       : out   std_logic_vector(19 downto 0);
		SRAM_DQ       : inout std_logic_vector(15 downto 0);
		oSRAM_CE_N    : out   std_logic;
		oSRAM_OE_N    : out   std_logic;
		oSRAM_WE_N    : out   std_logic;
		oSRAM_LB_N    : out   std_logic;
		oSRAM_UB_N    : out   std_logic;

		--PHY interface
		-- Tx
		mtx_clk_pad_i : in    std_logic; -- Transmit clock (from PHY)
		mtxd_pad_o    : out   std_logic_vector(3 downto 0); -- Transmit nibble (to PHY)
		mtxen_pad_o   : out   std_logic; -- Transmit enable (to PHY)
		mtxerr_pad_o  : out   std_logic; -- Transmit error (to PHY)

		-- Rx
		mrx_clk_pad_i : in    std_logic; -- Receive clock (from PHY)
		mrxd_pad_i    : in    std_logic_vector(3 downto 0); -- Receive nibble (from PHY)
		mrxdv_pad_i   : in    std_logic; -- Receive data valid (from PHY)
		mrxerr_pad_i  : in    std_logic; -- Receive data error (from PHY)

		-- Common Tx and Rx
		mcoll_pad_i   : in    std_logic; -- Collision (from PHY)
		mcrs_pad_i    : in    std_logic; -- Carrier sense (from PHY)

		-- MII Management interface
		mdc_pad_o     : out   std_logic; -- MII Management data clock (to PHY)
		mdio_pad_io   : inout std_logic;

		rst_n         : out   std_logic
	);
end entity patmos_top;

architecture rtl of patmos_top is
	component Patmos is
		port(
			clk                                   : in  std_logic;
			reset                                 : in  std_logic;

			io_comConf_M_Cmd                      : out std_logic_vector(2 downto 0);
			io_comConf_M_Addr                     : out std_logic_vector(31 downto 0);
			io_comConf_M_Data                     : out std_logic_vector(31 downto 0);
			io_comConf_M_ByteEn                   : out std_logic_vector(3 downto 0);
			io_comConf_M_RespAccept               : out std_logic;
			io_comConf_S_Resp                     : in  std_logic_vector(1 downto 0);
			io_comConf_S_Data                     : in  std_logic_vector(31 downto 0);
			io_comConf_S_CmdAccept                : in  std_logic;

			io_comSpm_M_Cmd                       : out std_logic_vector(2 downto 0);
			io_comSpm_M_Addr                      : out std_logic_vector(31 downto 0);
			io_comSpm_M_Data                      : out std_logic_vector(31 downto 0);
			io_comSpm_M_ByteEn                    : out std_logic_vector(3 downto 0);
			io_comSpm_S_Resp                      : in  std_logic_vector(1 downto 0);
			io_comSpm_S_Data                      : in  std_logic_vector(31 downto 0);

			io_cpuInfoPins_id                     : in  std_logic_vector(31 downto 0);
			io_cpuInfoPins_cnt                    : in  std_logic_vector(31 downto 0);
			io_ledsPins_led                       : out std_logic_vector(8 downto 0);
			io_keysPins_key                       : in  std_logic_vector(3 downto 0);
			io_uartPins_tx                        : out std_logic;
			io_uartPins_rx                        : in  std_logic;

			io_ethMacPins_MCmd                    : out std_logic_vector(2 downto 0); 
			io_ethMacPins_MAddr                   : out std_logic_vector(15 downto 0);
			io_ethMacPins_MData                   : out std_logic_vector(31 downto 0);
			io_ethMacPins_MByteEn                 : out std_logic_vector(3 downto 0);
			io_ethMacPins_SResp                   : in  std_logic_vector(1 downto 0);
			io_ethMacPins_SData                   : in  std_logic_vector(31 downto 0);

			io_sramCtrlPins_ramOut_addr           : out std_logic_vector(19 downto 0);
			io_sramCtrlPins_ramOut_doutEna        : out std_logic;
			io_sramCtrlPins_ramIn_din             : in  std_logic_vector(15 downto 0);
			io_sramCtrlPins_ramOut_dout           : out std_logic_vector(15 downto 0);
			io_sramCtrlPins_ramOut_nce            : out std_logic;
			io_sramCtrlPins_ramOut_noe            : out std_logic;
			io_sramCtrlPins_ramOut_nwe            : out std_logic;
			io_sramCtrlPins_ramOut_nlb            : out std_logic;
			io_sramCtrlPins_ramOut_nub            : out std_logic
		);
	end component;

component eth_controller_top is
	generic(
		BUFF_ADDR_WIDTH : natural       --word based (2^(BUFF_ADDR_WIDTH+2) = # of bytes)
	);
	port(
		clk           : in  std_logic;
		rst           : in  std_logic;

		-- OCP IN (slave) for Patmos
		MCmd          : in  std_logic_vector(2 downto 0);
		MAddr         : in  std_logic_vector(15 downto 0);
		MData         : in  std_logic_vector(31 downto 0);
		MByteEn       : in  std_logic_vector(3 downto 0);
		SResp         : out std_logic_vector(1 downto 0);
		SData         : out std_logic_vector(31 downto 0);

		--PHY interface
		-- Tx
		mtx_clk_pad_i : in  std_logic;  -- Transmit clock (from PHY)
		mtxd_pad_o    : out std_logic_vector(3 downto 0); -- Transmit nibble (to PHY)
		mtxen_pad_o   : out std_logic;  -- Transmit enable (to PHY)
		mtxerr_pad_o  : out std_logic;  -- Transmit error (to PHY)

		-- Rx
		mrx_clk_pad_i : in  std_logic;  -- Receive clock (from PHY)
		mrxd_pad_i    : in  std_logic_vector(3 downto 0); -- Receive nibble (from PHY)
		mrxdv_pad_i   : in  std_logic;  -- Receive data valid (from PHY)
		mrxerr_pad_i  : in  std_logic;  -- Receive data error (from PHY)

		-- Common Tx and Rx
		mcoll_pad_i   : in  std_logic;  -- Collision (from PHY)
		mcrs_pad_i    : in  std_logic;  -- Carrier sense (from PHY)

		--// MII Management interface
		md_pad_i      : in  std_logic;  -- MII data input (from I/O cell)
		mdc_pad_o     : out std_logic;  -- MII Management data clock (to PHY)
		md_pad_o      : out std_logic;  -- MII data output (to I/O cell)
		md_padoe_o    : out std_logic   -- MII data output enable (to I/O cell)
	);
end component;

	-- DE2-70: 50 MHz clock => 80 MHz
	-- BeMicro: 16 MHz clock => 25.6 MHz
	constant pll_infreq : real    := 50.0;
	constant pll_mult   : natural := 8;
	constant pll_div    : natural := 5;

	signal clk_int : std_logic;

			-- OCP IN (slave) for Patmos
	signal MCmd_int      : std_logic_vector(2 downto 0);
	signal MAddr_int     : std_logic_vector(15 downto 0);
	signal MData_int     : std_logic_vector(31 downto 0);
	signal MByteEn_int   : std_logic_vector(3 downto 0);
	signal SResp_int     : std_logic_vector(1 downto 0);
	signal SData_int     : std_logic_vector(31 downto 0);

	-- signals for converting i o in io (MII)
	signal md_pad_o_int   : std_logic;
	signal md_padoe_o_int : std_logic;

	-- for generation of internal reset
	signal int_res            : std_logic;
	signal res_reg1, res_reg2 : std_logic;
	signal res_cnt            : unsigned(2 downto 0) := "000"; -- for the simulation

	-- sram signals for tristate inout
	signal sram_out_dout_ena : std_logic;
	signal sram_out_dout     : std_logic_vector(15 downto 0);

	attribute altera_attribute : string;
	attribute altera_attribute of res_cnt : signal is "POWER_UP_LEVEL=LOW";

begin
	mdio_pad_io <= md_pad_o_int when (md_padoe_o_int = '1') else 'Z';
	rst_n       <= not int_res;

	pll_inst : entity work.pll generic map(
			input_freq  => pll_infreq,
			multiply_by => pll_mult,
			divide_by   => pll_div
		)
		port map(
			inclk0 => clk,
			c0     => clk_int
		);
	-- we use a PLL
	-- clk_int <= clk;

	--
	--	internal reset generation
	--	should include the PLL lock signal
	--
	process(clk_int)
	begin
		if rising_edge(clk_int) then
			if (res_cnt /= "111") then
				res_cnt <= res_cnt + 1;
			end if;
			res_reg1 <= not res_cnt(0) or not res_cnt(1) or not res_cnt(2);
			res_reg2 <= res_reg1;
			int_res  <= res_reg2;
		end if;
	end process;

	-- tristate output to ssram
	process(sram_out_dout_ena, sram_out_dout)
	begin
		if sram_out_dout_ena = '1' then
			SRAM_DQ <= sram_out_dout;
		else
			SRAM_DQ <= (others => 'Z');
		end if;
	end process;

	comp : Patmos port map(clk_int, int_res,
			               open, open, open, open, open,
			               (others => '0'), (others => '0'), '0',
			               open, open, open, open,
			               (others => '0'), (others => '0'),
			               X"00000000", X"00000001",
			               oLedsPins_led,
			               iKeysPins_key,
			               oUartPins_txd, 
								iUartPins_rxd,
								MCmd_int, 
								MAddr_int, 
								MData_int, 
								MByteEn_int, 
								SResp_int, 
								SData_int,
			               oSRAM_A, 
								sram_out_dout_ena, SRAM_DQ, sram_out_dout, oSRAM_CE_N, oSRAM_OE_N, oSRAM_WE_N, oSRAM_LB_N, oSRAM_UB_N);

eth_controller_top_comp_0 : eth_controller_top
	generic map(
		BUFF_ADDR_WIDTH => 16
	)
	port map(
		clk  => clk_int,
		rst  => int_res,

		-- OCP IN (slave) for Patmos
		MCmd => MCmd_int,
		MAddr => MAddr_int,
		MData => MData_int,
		MByteEn => MByteEn_int,
		SResp => SResp_int,
		SData => SData_int,

		--// Tx
		mtx_clk_pad_i            => mtx_clk_pad_i,
		mtxd_pad_o               => mtxd_pad_o,
		mtxen_pad_o              => mtxen_pad_o,
		mtxerr_pad_o             => mtxerr_pad_o,

		--// Rx
		mrx_clk_pad_i            => mrx_clk_pad_i,
		mrxd_pad_i               => mrxd_pad_i,
		mrxdv_pad_i              => mrxdv_pad_i,
		mrxerr_pad_i             => mrxerr_pad_i,

		--// Common Tx and Rx
		mcoll_pad_i              => mcoll_pad_i,
		mcrs_pad_i               => mcrs_pad_i,

		--// MII Management interface
		md_pad_i                 => mdio_pad_io,
		mdc_pad_o                => mdc_pad_o,
		md_pad_o                 => md_pad_o_int,
		md_padoe_o               => md_padoe_o_int
	);

end architecture rtl;