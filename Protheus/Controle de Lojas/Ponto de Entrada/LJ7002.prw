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
  Local aAreaSL2 := SL2->(FWGetArea())
  Local aAreaSB1 := SB1->(FWGetArea())
  Local nOpcao   := ParamIxB[01]
  Local lVlCred  := .F.
  //Local nGrvBat := ParamIxB[03]

  DBSelectArea("SL2")
  IF SL2->(MsSeek(xFilial("SL2") + SL1->L1_NUM ))
    DBSelectArea("SB1")
    IF SB1->(MsSeek(xFilial("SB1") + SL2->L2_PRODUTO ))
      If SB1->B1_VALEPRE == "1"
        lVlCred := .T.
      EndIF
    EndIF
  EndIF

  Do Case
    Case nOpcao == 1
      Return
    Case nOpcao == 2
      IF SL1->L1_SITUA == 'OK'
        If lVlCred
          u_DSOAPF01("MovMovimentoPedido")  
        Else
          u_DSOAPF01("MovMovimentoTBCData")
        EndIF 
      ElseIF SL1->L1_SITUA == 'FR'
        u_DSOAPF01("MovMovimentoPedido")
      EndIF 
    Case nOpcao == 3
      IF SL1->(MsSeek(xFilial("SL1") +  SL1->L1_ORCRES))
        u_DSOAPF01("MovMovimentoPedido")
      EndIF
  End 
  
  FWRestArea(aAreaSB1)
  FWRestArea(aAreaSL2)
  FWRestArea(aAreaSL1)
  FWRestArea(aPEArea)
Return
