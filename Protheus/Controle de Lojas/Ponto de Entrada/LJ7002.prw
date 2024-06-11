#Include "protheus.ch"

/*-----------------------------------------------------------------------
  Função: LJ7002

  Tipo: Ponto de entrada

  Localização: Ponto de Entrada chamado depois da gravação de todos os
               dados e da impressão do cupom fiscal na Venda Assistida
               e após o processamento do Job LjGrvBatch(FRONT LOJA)

  Uso: Venda Assistida

  Parâmetros:
    ExpN1	 Numérico	 Contém o tipo de operação de gravação, sendo:
      1 - Orçamento
      2 - Venda
      3 - Pedido

    ExpA2	 Array of Record Array de 1 dimensão contendo os dados da
                   devolução na seguinte ordem:
      1 - série da NF de devolução
      2 - Número da NF de devolução
      3 - Cliente
      4 - Loja do cliente
      5 - Tipo de operação (1 - troca; 2 - devolução)

    ExpN3	Array of Record	Contém a origem da chamada da função, sendo:
      1 - Genérica
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
