library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity nco_tx is

    generic (
        PHASE_WIDTH      : integer := 32;
        OUTPUT_FREQ_MHZ  : real;
        DUTY_CYCLE       : real;
        LINE_RATE_GBPS   : real := 5.0
    );

    port (

        ----------------------------------------------------------------------
        -- Clock do domínio TX
        --
        -- Para:
        --
        --     Line Rate = 5 Gb/s
        --     Data Width = 20
        --
        -- temos:
        --
        --     TXUSRCLK2 = 250 MHz
        ----------------------------------------------------------------------
        txusrclk2 : in std_logic;

        ----------------------------------------------------------------------
        -- Palavra paralela enviada ao GTX
        ----------------------------------------------------------------------
        txdata : out std_logic_vector(19 downto 0)

    );

end entity nco_tx;


architecture rtl of nco_tx is


    --------------------------------------------------------------------------
    -- FUNÇÃO:
    --
    -- Converte um valor REAL diretamente para UNSIGNED.
    --
    -- Não utilizamos INTEGER nesta conversão.
    --
    -- Isso é importante porque um UNSIGNED de 32 bits pode representar:
    --
    --     0 até 4294967295
    --
    -- enquanto um INTEGER positivo normalmente vai somente até:
    --
    --     2147483647
    --------------------------------------------------------------------------

    function real_to_unsigned (
        value : real;
        width : integer
    ) return unsigned is

        variable result    : unsigned(width-1 downto 0) := (others => '0');
        variable remaining : real := value;
        variable weight    : real;

    begin

        ----------------------------------------------------------------------
        -- Percorre os bits do MSB para o LSB
        ----------------------------------------------------------------------

        for i in width-1 downto 0 loop

            weight := 2.0 ** i;

            if remaining >= weight then

                result(i) := '1';
                remaining := remaining - weight;

            end if;

        end loop;

        return result;

    end function;


    --------------------------------------------------------------------------
    -- CONSTANTES DE CÁLCULO
    --------------------------------------------------------------------------

    constant PHASE_SCALE : real :=
        2.0 ** PHASE_WIDTH;


    --------------------------------------------------------------------------
    -- Line Rate convertido para Hz
    --------------------------------------------------------------------------

    constant LINE_RATE_HZ : real :=
        LINE_RATE_GBPS * 1.0E9;


    --------------------------------------------------------------------------
    -- Frequência desejada convertida para Hz
    --------------------------------------------------------------------------

    constant OUTPUT_FREQ_HZ : real :=
        OUTPUT_FREQ_MHZ * 1.0E6;


    --------------------------------------------------------------------------
    -- CÁLCULO DO INCREMENTO DE FASE
    --
    -- PHASE_INC =
    --
    --                Fout
    --          ------------------ * 2^PHASE_WIDTH
    --             Line Rate
    --
    --------------------------------------------------------------------------

    constant PHASE_INC_REAL : real :=
        (OUTPUT_FREQ_HZ / LINE_RATE_HZ) * PHASE_SCALE;


    --------------------------------------------------------------------------
    -- CÁLCULO DO LIMIAR DO DUTY CYCLE
    --
    -- Exemplo para 50%:
    --
    --     0.50 * 2^32
    --
    --     = 2147483648
    --------------------------------------------------------------------------

    constant DUTY_THRESHOLD_REAL : real :=
        (DUTY_CYCLE / 100.0) * PHASE_SCALE;


    --------------------------------------------------------------------------
    -- CONVERSÃO DO PHASE_INC
    --
    -- Agora:
    --
    --     REAL -> UNSIGNED
    --
    -- sem passar por INTEGER.
    --------------------------------------------------------------------------

    constant PHASE_INC :
        unsigned(PHASE_WIDTH-1 downto 0)
        := real_to_unsigned(
               PHASE_INC_REAL,
               PHASE_WIDTH
           );


    --------------------------------------------------------------------------
    -- CONVERSÃO DO DUTY_THRESHOLD
    --------------------------------------------------------------------------

    constant DUTY_THRESHOLD :
        unsigned(PHASE_WIDTH-1 downto 0)
        := real_to_unsigned(
               DUTY_THRESHOLD_REAL,
               PHASE_WIDTH
           );


    --------------------------------------------------------------------------
    -- ACUMULADOR DE FASE
    --------------------------------------------------------------------------

    signal phase_acc :
        unsigned(PHASE_WIDTH-1 downto 0)
        := (others => '0');


begin


    --------------------------------------------------------------------------
    -- VERIFICAÇÕES DOS PARÂMETROS
    --------------------------------------------------------------------------

    assert PHASE_WIDTH > 0
        report "ERRO: PHASE_WIDTH deve ser maior que zero."
        severity failure;


    assert OUTPUT_FREQ_MHZ >= 0.0
        report "ERRO: OUTPUT_FREQ_MHZ nao pode ser negativo."
        severity failure;


    assert DUTY_CYCLE >= 0.0 and DUTY_CYCLE <= 100.0
        report "ERRO: DUTY_CYCLE deve estar entre 0 e 100."
        severity failure;


    assert LINE_RATE_GBPS > 0.0
        report "ERRO: LINE_RATE_GBPS deve ser maior que zero."
        severity failure;


    --------------------------------------------------------------------------
    -- NCO
    --------------------------------------------------------------------------

    process(txusrclk2)

        ----------------------------------------------------------------------
        -- Cópia temporária do acumulador de fase
        ----------------------------------------------------------------------

        variable phase_temp :
            unsigned(PHASE_WIDTH-1 downto 0);


        ----------------------------------------------------------------------
        -- Palavra de 20 bits destinada ao GTX
        ----------------------------------------------------------------------

        variable data_word :
            std_logic_vector(19 downto 0);

    begin

        if rising_edge(txusrclk2) then

            ------------------------------------------------------------------
            -- Começa com a fase atual
            ------------------------------------------------------------------

            phase_temp := phase_acc;


            ------------------------------------------------------------------
            -- Gera os 20 bits da palavra paralela
            ------------------------------------------------------------------

            for i in 0 to 19 loop


                ----------------------------------------------------------------
                -- Determina o nível lógico de cada bit
                --
                -- fase < threshold -> 1
                -- fase >= threshold -> 0
                ----------------------------------------------------------------

                if phase_temp < DUTY_THRESHOLD then

                    data_word(i) := '1';

                else

                    data_word(i) := '0';

                end if;


                ----------------------------------------------------------------
                -- Avança a fase para o próximo bit serial
                ----------------------------------------------------------------

                phase_temp :=
                    phase_temp + PHASE_INC;

            end loop;


            ------------------------------------------------------------------
            -- Envia a palavra para o GTX
            ------------------------------------------------------------------

            txdata <= data_word;


            ------------------------------------------------------------------
            -- Salva a nova fase
            ------------------------------------------------------------------

            phase_acc <= phase_temp;

        end if;

    end process;

end architecture rtl;