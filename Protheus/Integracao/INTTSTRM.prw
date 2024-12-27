#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"
#Include 'FWMVCDef.ch'

//-----------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} DSOAPF01
User Function: DSOAPF01 - Função para Integração Via SOAP com o TOTVS Corpore RM
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 02/09/2024
@Permite
Programa Fonte
/*/
User Function INTTSTRM()
    Local aPerg := {}
    Local aRet  := {}
    Local aEndPoint := {"wsCliForResumo",;
                        "wsProdutos",;
                        "wsNatClFiscal",;
                        "wsTabPreco",;
                        "wsTabPrcUni",;
                        "wsPontoVenda",;
                        "wsPrdCodBarras",;
                        "wsPrdFilCCusto",;
                        "wsFormaPagamento",;
                        "wsFpagtoCaixa",;
                        "MovMovimentoTBCData",;
                        "MovMovimentoPedido",;
                        "MovMovCopiaReferenciaData",;
                        "FisNFeInutilizarData"}
    Local cSelec := ""

    aAdd( aPerg ,{9,"Selecione o EndPoint",200     , 40 ,.T.})
    aAdd( aPerg ,{2,"Endpoint: "          , cSelec ,aEndPoint , 80 ,"" ,.T.})

    If ParamBox(aPerg ,"Informe os dados",@aRet)
        IF ExistBlock("DSOAPF01")
            ExecBlock("DSOAPF01",.F.,.F.,{aRet[2]})
        ENDIF
    EndIF

Return
