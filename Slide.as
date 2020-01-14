; Grupo 51:
; Francisco Abrunhosa n95580
; Diogo Venancio n95555

;--------------------------------------------------------------------------
; Inicializacao dos dados/constantes/variaveis

                ORIG    0000h
                
STACKBASE       EQU     8000h  ; valor do stack base
ACELEROMETRO    EQU     FFEBh  ; porto do acelerometro
GRAVIDADE_255   EQU     1      ; Q11.5 => 10/255 = 0,0392
ASTERISCO       EQU     002Ah  ; codigo ascii do asterisco
BOLA            EQU     006Fh  ; codigo ascii do "o" que representa a bola
IO_CTRL         EQU     FFFCh  ; posicao do cursor
IO_WRITE        EQU     FFFEh  ; escrita no terminal
INIT_MASK       EQU     FFFAh  ; local para escrever as interrupcoes a ativar
INIT_MASK_VALUE EQU     8000h  ; ativa o cronometro
INIT_TEMP       EQU     FFF7h  ; local para ativar o cronometro
INIT_VALOR_TEMP EQU     1      ; chave para ativar o cronometro
PORTO_TEMPO     EQU     FFF6h  ; local onde escrever o valor da contagem
VALOR_TEMPO     EQU     1      ; valor da contagem

POS_0           WORD    1      ; Q11.5 => ...0,00000
VEL_0           WORD    0      ; Q11.5 => ...0,00000
DELTA_T         WORD    2      ; Q12.4 => tempo = 0,1
FLAG_CONTROLO   WORD    0      ; variavel para controlar o ciclo
POS_ATLZD       WORD    5      ; guarda a parte inteira da posicao tendo
                               ; sido inicializada a 5 para nao interferir
                               ; com as paredes no primeiro ciclo
                               
POS_T           TAB     1      ; local onde vai ser guardado os valores da posicao
VEL_T           TAB     1      ; local onde vai ser guardado os valores da velocidade


; -------------------------------------------------------------------------
; Handler do cronometro:
; Fazemos um JMP para uma subrotina porque o numero de instrucoes excede
; o numero permitido (16)

                ORIG    7FF0h
                JMP     TIMER              

;-------------------------------------------------------------------------
; Inicializacao de estruturas:
; E feita a escrita das paredes da simulacao 
; e sao incializadas estruturas como o cronometro, o stack pointer e 
; outras variaveis usadas no ciclo

                ORIG    0000h
                
                MVI     R5, IO_CTRL
                MVI     R2, 0100h     
                STOR    M[R5], R2     
                MVI     R5, IO_WRITE
                MVI     R2, ASTERISCO ; parte que escreve os asteriscos
                STOR    M[R5], R2     ; das extremidades da linha 1
                MVI     R5, IO_CTRL
                MVI     R2, 014Fh
                STOR    M[R5], R2
                MVI     R5, IO_WRITE
                MVI     R2, 002Ah
                STOR    M[R5], R2
                
                MVI     R5, IO_CTRL
                MVI     R2, 0000h     ; prepara o loop para escrever os
                STOR    M[R5], R2     ; asteriscos do "teto"
                MVI     R5, IO_WRITE
                MVI     R2, ASTERISCO
                MVI     R3, 80
                
CEILING:        STOR    M[R5], R2     ; escreve os asteriscos do "teto"
                DEC     R3
                CMP     R3, R0
                BR.NZ   CEILING
                
                MVI     R3, 80
                MVI     R5, IO_CTRL
                MVI     R2, 0200h     ; prepara o loop para escrever os 
                STOR    M[R5], R2     ; asteriscos do "chao"
                MVI     R5, IO_WRITE
                MVI     R2, ASTERISCO
                
FLOOR:          STOR    M[R5], R2     ; escreve os asteriscos do "chao"
                DEC     R3
                CMP     R3, R0
                BR.NZ   FLOOR
                
                MVI     R6, STACKBASE  ; inicializacao do Stack Pointer
               
                MVI     R1, INIT_MASK  ; inicializacao das interrupcoes
                MVI     R2, INIT_MASK_VALUE
                STOR    M[R1], R2
                ENI
               
                MVI     R1, INIT_TEMP       ; incializacao do
                MVI     R2, INIT_VALOR_TEMP ; cronometro
                STOR    M[R1], R2
               
                MVI     R1, PORTO_TEMPO  ; inicializa o valor da
                MVI     R2, VALOR_TEMPO  ; contagem
                STOR    M[R1], R2
               
                MVI     R1, POS_0 ; passamos para a POS_T o valor inicial
                LOAD    R1, M[R1] ; (POS_0) para podermos alterar
                MVI     R2, POS_T ; este valor durante os ciclos
                STOR    M[R2], R1
               
                MVI     R1, VEL_0 ; passamos para VEL_T o valor inicial
                LOAD    R1, M[R1] ; (VEL_0) para podermos alterar
                MVI     R2, VEL_T ; este valor durante os ciclos
                STOR    M[R2], R1
              
;-------------------------------------------------------------------------
; Controlo do ciclo e atualizacao da posicao:
; Se FLAG_CONTROLO estiver a 1, executa o ciclo e atualiza a posicao

VERIFICA_ATLZ:  MVI     R1, FLAG_CONTROLO
                LOAD    R1, M[R1]         ; verifica se vamos executar 
                CMP     R1, R0            ; o ciclo
                BR.Z    VERIFICA_ATLZ
               
                MVI     R2, POS_ATLZD
                LOAD    R2, M[R2]      ; verifica se devemos apagar
                MVI     R3, 0100h      ; a posicao da bola dado que 
                OR      R3, R3, R2     ; e posivel que esta se encontre
                CMP     R3, R2         ; nos extremos da janela e assim
                BR.NZ   DEL            ; evitamos apagar as paredes
                MVI     R1, 014Fh
                CMP     R3, R1
                BR.NZ   DEL
                BR      BYPASS
                
DEL:            MVI     R1, IO_CTRL
                STOR    M[R1], R3     ; vamos eliminar a bola que tinha
                MVI     R1, IO_WRITE  ; sido escrita no ciclo anterior
                MVI     R3, 0020h     ; para nao interferir com o novo
                STOR    M[R1], R3     ; ciclo (0020h = codigo ASCII do espaço)
                                    
BYPASS:         MVI     R1, ACELEROMETRO  
                LOAD    R1, M[R1]  ; ler o valor do acelerometro
                JAL     FC_ACELERACAO
                MOV     R1, R3

                JAL     FC_VELOCIDADE
                MVI     R1, VEL_T  ; guarda o valor na variavel para usar 
                STOR    M[R1], R3  ; num proximo ciclo
               
                MOV     R1, R3
                JAL     FC_POSICAO
                MVI     R1, POS_T  ; guarda o valor na variavel para usar 
                STOR    M[R1], R3  ; num proximo ciclo
                
               
                MOV     R1, R3
                JAL     VRF_POS  ; faz a verificacao do argumento
               
                MVI     R1, POS_ATLZD
                LOAD    R1, M[R1]
                JAL     PRINT  ; escreve a bola no terminal
               
                MVI     R2, FLAG_CONTROLO
                LOAD    R1, M[R2]  ; decrementamos a variavel de controlo
                DEC     R1         ; para usar na verificacao do 
                STOR    M[R2], R1  ; proximo ciclo
                
                BR      VERIFICA_ATLZ
                
; ---------------------------------------------------------------------
; Rotina que trata das atualizacoes do timer:
; Output: variavel para controlar a atualizacao da posica da bola

TIMER:          DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                
                MVI     R1, 1              ; atualiza flag para controlar
                MVI     R2, FLAG_CONTROLO  ; o ciclo
                STOR    M[R2], R1
               
                MVI     R1, INIT_TEMP       ; incializacao do
                MVI     R2, INIT_VALOR_TEMP ; cronometro
                STOR    M[R1], R2
               
                MVI     R1, PORTO_TEMPO  ; inicializa o valor da
                MVI     R2, VALOR_TEMPO  ; contagem
                STOR    M[R1], R2
                
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
               
                RTI
               
;--------------------------------------------------------------------------
; Funcao que calcula a aceleracao
; Input: R1 = valor do acelerometro
; Variaveis em memoria usadas: gravidade_255 Q11.5
; Outuput: R3 = aceleracao que vai estar em Q11.5

FC_ACELERACAO:  MVI     R2, GRAVIDADE_255

                DEC     R6  
                STOR    M[R6], R7

                JAL     Produto  ; faz a acel. * 10/255
               
                LOAD    R7,M[R6]  
                INC     R6
               
                JMP     R7  

;-------------------------------------------------------------------------
; Funcao que calcula a velocidade num dado instante
; Input: R1 = aceleracao Q11.5
; Variaveis em memoria usadas: vel_t (Q11.5) e delta_t (Q12.4)
; Outuput: R3 = velocidade em t (Q11.5)

FC_VELOCIDADE:  MVI     R2, DELTA_T
                LOAD    R2, M[R2] ; ler o valor do tempo
               
                DEC     R6 
                STOR    M[R6], R7
               
                JAL     Produto ; acel (Q11.5) * tempo (Q12.4) = Q7.9
               
                LOAD    R7, M[R6] 
                INC     R6
                
                SHRA    R3 
                SHRA    R3 ; serve para alinhar as virgulas para as
                SHRA    R3 ; futuras somas estarem todas em Q11.5
                SHRA    R3
               
                MVI     R2, VEL_T ; ler o valor anterior da velocidade
                LOAD    R2, M[R2]
               
                ADD     R3, R3, R2 ; velocidade em t
               
                JMP     R7 
               
;-------------------------------------------------------------------------
; Funcao que calcula a posicao em t
; Input: R1 = velocidade em t (Q11.5)
; Variaveis em memoria usadas: pos_t (Q11.5) e delta_t (Q12.4)
; Outuput: R3 = posicao em t (Q11.5)

FC_POSICAO:     MVI     R2, DELTA_T
                LOAD    R2, M[R2] ; ler o valor do tempo
               
                DEC     R6
                STOR    M[R6], R7 
               
                JAL     Produto ; vel (Q11.5) * tempo (Q12.4) = Q7.9
               
                LOAD    R7, M[R6] 
                INC     R6
                
                SHRA    R3 
                SHRA    R3 ; serve para alinhar as virgulas para as
                SHRA    R3 ; futuras somas estarem todas em Q11.5
                SHRA    R3
               
                MVI     R2, POS_T ; ler o valor de posicao anterior
                LOAD    R2, M[R2]
               
                ADD     R3, R3, R2 ; calcula nova posicao
               
                JMP     R7 
               
;-------------------------------------------------------------------------
; Funcao que prepara e verifica a posicao antes de ser
; representada no terminal
; Input: R1 = posicao em Q11.5
; Outuput: R3 = parte inteira da posicao

VRF_POS:        ; verifica se a posicao esta dentro do limite (1,78)
                MVI     R2, 2528   ; 2528 = 78 * 2^5
                CMP     R1, R2
                BR.P    .INVERTE
                MVI     R2, 32     ; 32 = 1 * 2^5
                CMP     R1, R2
                BR.NN   .RETORNA
               
.INVERTE:       MVI     R3, POS_T  ; vai retirar o excesso da posicao e
                ADD     R2, R2, R2 ; realizar um ressalto por ter 
                SUB     R2, R2, R1 ; embatido numa parede
                
                STOR    M[R3], R2
                
                MOV     R3, R2
                
                MVI     R1, VEL_T
                LOAD    R2, M[R1]  ; vai fazer o simetrico da velocidade
                NEG     R2
                STOR    M[R1], R2

.RETORNA:       SHRA    R3
                SHRA    R3  ; antes de retornar ao ciclo vamos 
                SHRA    R3  ; passar a parte inteira da posicao
                SHRA    R3  ; para uma variavel 
                SHRA    R3
                
                MVI     R2, POS_ATLZD
                STOR    M[R2], R3

                JMP     R7                
               
; ------------------------------------------------------------------------
; Rotina que calcula o produto
; Disponibilizada no fenix em lab.as

Produto:        MVI     R3, 0
                CMP     R2, R0
                BR.Z    .Fim
               
.Loop:          ADD     R3, R3, R1
                DEC     R2
                BR.NZ   .Loop
               
.Fim:           JMP     R7

;-------------------------------------------------------------------------
; Rotina que escreve a bola no terminal:
; Input: R1 = parte inteira da posicao
; Output: escrita no terminal

PRINT:          DEC     R6
                STOR    M[R6], R4
                
                MVI     R3, 0100h   ; fazemos um OR para colocar a bola na
                OR      R3, R3, R1  ; linha 1 e na coluna igual a parte
                MVI     R4, IO_CTRL ; inteira da posicao previamente
                STOR    M[R4], R3   ; calculada
                
                MVI     R4, IO_WRITE
                MVI     R3, BOLA
                STOR    M[R4], R3
               
                LOAD    R4, M[R6]
                INC     R6
               
                JMP     R7
