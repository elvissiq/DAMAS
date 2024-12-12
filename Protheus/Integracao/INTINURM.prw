#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"
#Include 'FWMVCDef.ch'

//-------------------------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} INTINURM
User Function: INTINURM - Função para Integração de inutilização via SOAP com o TOTVS Corpore RM
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 12/12/2024
@Permite
Programa Fonte
/*/
User Function INTINURM(pEndpoint)
    
    If ValType(pEndpoint) == "A" .And. IsInCallStack("WFLAUNCHER")
        RpcClearEnv()
        RpcSetType(3) 
        RpcSetEnv(pEndpoint[1], pEndpoint[2], "Administrador", , "LOJA")

        IF ExistBlock("DSOAPF01")
            ExecBlock("DSOAPF01",.F.,.F.,{"FisNFeInutilizarData"})
        ENDIF

        RPCClearEnv()
    EndIF

Return
