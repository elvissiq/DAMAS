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
  Local aPEArea  := FWGetArea()
  Local aAreaSL1 := SL1->(FWGetArea())
  Local nOpcao   := ParamIxB[01]
  //Local nGrvBat := ParamIxB[03]

  Do Case
    Case nOpcao == 1
      Return
    Case nOpcao == 2
      IF !IsBlind()
        FWAlertInfo('Vai enviar o orcamento ' + SL1->L1_NUM + ', ao RM.', 'Integracao de Venda com o TOTVS Corpore RM')
      EndIF
      IF SL1->L1_SITUA == 'OK'
        u_DSOAPF01("MovMovimentoTBCData")
      ElseIF SL1->L1_SITUA == 'FR'
        u_DSOAPF01("MovMovimentoPedido")
      EndIF 
    Case nOpcao == 3
      IF SL1->(MsSeek(xFilial("SL1") +  SL1->L1_ORCRES))
        IF !IsBlind()
          FWAlertInfo('Vai enviar o orcamento ' + SL1->L1_NUM + ', ao RM.', 'Integracao de Pedido de Venda com o TOTVS Corpore RM')
        EndIF
        u_DSOAPF01("MovMovimentoPedido")
      EndIF
  End 
  
  FWRestArea(aAreaSL1)
  FWRestArea(aPEArea)
Return
