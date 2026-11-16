library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity top is    
    generic (
        output_freq_mhz : real := 200.0;
        duty_cycle : real := 75.0
    );

    port (
        btn_start : in std_logic;       -- Botão de iniciar o código
        btn_stop  : in std_logic;    -- parar   (ativo em nivel baixo)

        ----------------------------------------------------------------------
        -- Clock de sistema da AX7350B
        -- Oscilador onboard: 50 MHz
        ----------------------------------------------------------------------
        sys_clk : in std_logic;

        ----------------------------------------------------------------------
        -- MGTREFCLK1 do BANK 111
        -- 156.25 MHz diferencial
        ----------------------------------------------------------------------
        gt_refclk_n : in std_logic;
        gt_refclk_p : in std_logic;

        -- LED para indicar quando a placa está enviando o sinal
        led_idle  : out std_logic;     -- aceso = parado, apagado = rodando

        ----------------------------------------------------------------------
        -- Saída diferencial do GTX
        -- Ligada às SMA_TX da placa
        ----------------------------------------------------------------------
        sma_tx_n : out std_logic;
        sma_tx_p : out std_logic
    );
end entity top;


architecture rtl of top is
    
    -- Sinais para colocar o botão de iniciar e sincronizar os dois clocks (PL e gtx)
    signal start_sync : std_logic_vector(1 downto 0) := "11";
    signal stop_sync  : std_logic_vector(1 downto 0) := "11";
    signal rodando    : std_logic := '0';
    signal rodando_tx : std_logic_vector(1 downto 0) := "00";

    signal nco_txdata : std_logic_vector(19 downto 0);   -- saída do NCO
    -- gt0_txdata continua existindo: é a entrada do GTX

    --------------------------------------------------------------------------
    -- TXDATA que será entregue ao GTX
    --------------------------------------------------------------------------
    signal gt0_txdata : std_logic_vector(19 downto 0);


    --------------------------------------------------------------------------
    -- Clocks fornecidos pelo GTX
    --
    -- Com:
    --
    -- Line Rate = 5 Gb/s
    -- Data Width = 20 bits
    --
    -- TXUSRCLK2 = 250 MHz
    --------------------------------------------------------------------------
    signal gt0_txusrclk  : std_logic;
    signal gt0_txusrclk2 : std_logic;


    --------------------------------------------------------------------------
    -- Status interno do GTX
    --------------------------------------------------------------------------
    signal gt0_tx_fsm_done : std_logic;
    signal gt0_txresetdone : std_logic;

    --------------------------------------------------------------------------
    -- Sinais para CPLL ou QPLL
    --------------------------------------------------------------------------

    signal gt0_cplllock      : std_logic;
    signal gt0_cpllfbclklost : std_logic;

    -- signal gt0_qplllock         : std_logic;
    -- signal gt0_qpllrefclklost   : std_logic;

    --------------------------------------------------------------------------
    -- Saídas físicas do GTX
    --------------------------------------------------------------------------
    signal gt0_gtxtxp : std_logic;
    signal gt0_gtxtxn : std_logic;


begin
    -- Botões: sincroniza e controla "rodando" (domínio sys_clk)
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            start_sync <= start_sync(0) & btn_start;
            stop_sync  <= stop_sync(0)  & btn_stop;

            if stop_sync(1) = '0' then        -- parar tem prioridade
                rodando <= '0';
            elsif start_sync(1) = '0' then
                rodando <= '1';
            end if;
        end if;
    end process;

    -- Passa "rodando" para o domínio do TXUSRCLK2 e libera o dado do NCO
    process(gt0_txusrclk2)
    begin
        if rising_edge(gt0_txusrclk2) then
            rodando_tx <= rodando_tx(0) & rodando;
            if rodando_tx(1) = '1' then
                gt0_txdata <= nco_txdata;
            else
                gt0_txdata <= (others => '0');
            end if;
        end if;
    end process;

    -- LED aceso enquanto rodando não está ativo
    led_idle <= not rodando;

    --------------------------------------------------------------------------
    -- CONEXÃO DAS SAÍDAS DO GTX ÀS SAÍDAS DO TOP
    --------------------------------------------------------------------------

    sma_tx_p <= gt0_gtxtxp;
    sma_tx_n <= gt0_gtxtxn;


    --------------------------------------------------------------------------
    -- NCO
    --
    -- O NCO gera os 20 bits de TXDATA.
    --
    -- Clock:
    --     TXUSRCLK2 = 250 MHz
    --
    -- Saída:
    --     20 bits
    --
    -- Frequência configurada atualmente no NCO:
    --     500 MHz
    --------------------------------------------------------------------------

    nco_tx_i : entity work.nco_tx
        generic map (
            OUTPUT_FREQ_MHZ => output_freq_mhz,
            DUTY_CYCLE => duty_cycle
        )

        port map (
            txusrclk2 => gt0_txusrclk2,
            txdata    => nco_txdata
        );

    --------------------------------------------------------------------------
    -- GT WIZARD
    --------------------------------------------------------------------------

    gtwizard_0_i : entity work.gtwizard_0

        port map
        (

            ------------------------------------------------------------------
            -- RESET / CONTROLE
            ------------------------------------------------------------------

            SOFT_RESET_TX_IN =>
                '0',

            DONT_RESET_ON_DATA_ERROR_IN =>
                '0',


            ------------------------------------------------------------------
            -- MGTREFCLK1
            ------------------------------------------------------------------

            Q2_CLK1_GTREFCLK_PAD_N_IN =>
                gt_refclk_n,

            Q2_CLK1_GTREFCLK_PAD_P_IN =>
                gt_refclk_p,


            ------------------------------------------------------------------
            -- RESET FSM
            ------------------------------------------------------------------

            GT0_TX_FSM_RESET_DONE_OUT =>
                gt0_tx_fsm_done,

            GT0_RX_FSM_RESET_DONE_OUT =>
                open,

            GT0_DATA_VALID_IN =>
                '1',


            ------------------------------------------------------------------
            -- CLOCKS DO TX
            ------------------------------------------------------------------

            GT0_TXUSRCLK_OUT =>
                gt0_txusrclk,

            GT0_TXUSRCLK2_OUT =>
                gt0_txusrclk2,


            ------------------------------------------------------------------
            -- CPLL
            ------------------------------------------------------------------

            gt0_cpllfbclklost_out =>
                gt0_cpllfbclklost,

            gt0_cplllock_out =>
                gt0_cplllock,

            gt0_cpllreset_in =>
                '0',


            ------------------------------------------------------------------
            -- DRP
            -- Não utilizado.
            ------------------------------------------------------------------

            gt0_drpaddr_in =>
                (others => '0'),

            gt0_drpdi_in =>
                (others => '0'),

            gt0_drpdo_out =>
                open,

            gt0_drpen_in =>
                '0',

            gt0_drprdy_out =>
                open,

            gt0_drpwe_in =>
                '0',


            ------------------------------------------------------------------
            -- DIGITAL MONITOR
            ------------------------------------------------------------------

            gt0_dmonitorout_out =>
                open,


            ------------------------------------------------------------------
            -- RX / EYE SCAN
            -- RX não utilizado.
            ------------------------------------------------------------------

            gt0_eyescanreset_in =>
                '0',

            gt0_eyescandataerror_out =>
                open,

            gt0_eyescantrigger_in =>
                '0',

            gt0_rxmonitorout_out =>
                open,

            gt0_rxmonitorsel_in =>
                (others => '0'),

            gt0_gtrxreset_in =>
                '0',


            ------------------------------------------------------------------
            -- TX RESET / USER READY
            ------------------------------------------------------------------

            gt0_gttxreset_in =>
                '0',

            gt0_txuserrdy_in =>
                '1',


            ------------------------------------------------------------------
            -- TX DATA
            --
            -- Aqui está a principal ligação:
            --
            --       NCO
            --        |
            --        v
            --   gt0_txdata
            --        |
            --        v
            --   GT Wizard
            --
            ------------------------------------------------------------------

            gt0_txdata_in =>
                gt0_txdata,


            ------------------------------------------------------------------
            -- SAÍDA DIFERENCIAL DO GTX
            ------------------------------------------------------------------

            gt0_gtxtxn_out =>
                gt0_gtxtxn,

            gt0_gtxtxp_out =>
                gt0_gtxtxp,


            ------------------------------------------------------------------
            -- TX OUTPUT CLOCKS
            ------------------------------------------------------------------

            gt0_txoutclkfabric_out =>
                open,

            gt0_txoutclkpcs_out =>
                open,


            ------------------------------------------------------------------
            -- TX RESET DONE
            ------------------------------------------------------------------

            gt0_txresetdone_out =>
                gt0_txresetdone,


            ------------------------------------------------------------------
            -- QPLL
            -- Não utilizado na configuração atual
            -- Comentários para o caso de utilizar o QPLL
            ------------------------------------------------------------------

            -- GT0_QPLLLOCK_OUT =>
            --     gt0_qplllock,

            -- GT0_QPLLREFCLKLOST_OUT =>
            --     gt0_qpllrefclklost,

            GT0_QPLLOUTCLK_OUT =>
                open,

            GT0_QPLLOUTREFCLK_OUT =>
                open,


            ------------------------------------------------------------------
            -- CLOCK DE SISTEMA / DRP
            --
            -- Clock de 50 MHz da placa.
            ------------------------------------------------------------------

            sysclk_in =>
                sys_clk

        );

end architecture rtl;