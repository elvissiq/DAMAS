#Include "protheus.ch"

/*-----------------------------------------------------------------------
  Fun��o: LJ7002

  Tipo: Ponto de entrada

  Localiza��o: Ponto de Entrada chamado depois da grava��o de todos os
               dados e da impress�o do cupom fiscal na Venda Assistida
               e ap�s o processamento do Job LjGrvBatch(FRONT LOJA)

  Uso: Venda Assistida

  Par�metros:
    ExpN1	 Num�rico	 Cont�m o tipo de opera��o de grava��o, sendo:
      1 - Or�amento
      2 - Venda
      3 - Pedido

    ExpA2	 Array of Record Array de 1 dimens�o contendo os dados da
                   devolu��o na seguinte ordem:
      1 - s�rie da NF de devolu��o
      2 - N�mero da NF de devolu��o
      3 - Cliente
      4 - Loja do cliente
      5 - Tipo de opera��o (1 - troca; 2 - devolu��o)

    ExpN3	Array of Record	Cont�m a origem da chamada da fun��o, sendo:
      1 - Gen�rica
      2 - GRVBatch
Retorno:
Nenhum
--------------------------------------------------------------------------*/
User Function LJ7002()
  Local aPEArea := FWGetArea()
  Local nOpcao  := ParamIxB[01]

  If nOpcao <> 2
     Return
  EndIf

  U_DSOAPF01(,,"MovMovimentoTBCData")
  
  FWRestArea(aPEArea)
Return
