#INCLUDE "PROTHEUS.CH"
#INCLUDE "POSCSS.CH"
#INCLUDE "PARMTYPE.CH"
//------------------------------------------------------------------------------
/*{Protheus.doc} StValPro
Função para validar se um determinado item poderá ser registrado no PDV
@param   	PARAMIXB
@author     Elvis Siqueira
@version    P12
@since      10/06/2024
@return     lRet
/*/
//------------------------------------------------------------------------------
User Function StValPro()

	Local lRet     := .F.
	Local cCodProd := PARAMIXB[1]
	Local cLocPad  := SuperGetMV("MV_LOCPAD",.F.,"")
	Local nQtdReg  := PARAMIXB[2]
	Local nQtdTab  := 0
	Local cQry     := ""
	Local _cAlias  := GetNextAlias()

	Private nSaldo   := 0
	Private lErIntRM := .F.

	U_DSOAPF01(cCodProd,cLocPad,"RealizarConsultaSQL")

	If lErIntRM //Caso ocorra erro na integração com o RM, consulta o estoque local.
		DBSelectArea("SB2")
		SB2->(DBGoTop())
		If SB2->(MSseek(xFilial("SB2")+cCodProd+cLocPad))
			nSaldo := SaldoSB2()
		EndIF
	EndIF
	
	cQry := " SELECT SUM(L2_QUANT) AS QUANT FROM " + RetSQLName('SL2')
	cQry += " WHERE D_E_L_E_T_ <> '*' AND L2_NUM = '"+SL1->L1_NUM+"' AND L2_PRODUTO = '"+cCodProd+"' "
	cQry := ChangeQuery(cQry)
    IF Select(_cAlias) <> 0
    	(_cAlias)->(DbCloseArea())
    EndIf
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)

	If ! (_cAlias)->(EoF())
		nQtdTab := (_cAlias)->QUANT
	EndIF 
	(_cAlias)->(DbCloseArea()) 

	IF ValType(nSaldo) == "N"
		IF nSaldo >= (nQtdReg + nQtdTab)
			lRet:= .T.
		Else
			STFMessage("ItemRegistered","STOP","ITEM NAO REGISTRADO - SALDO EM ESTOQUE INSUFICIENTE PARA O PRODUTO")
		EndIF
	Else 
		IF nSaldo >= (nQtdReg + nQtdTab)
			lRet:= .T.
		Else
			STFMessage("ItemRegistered","STOP","ITEM NAO REGISTRADO - SALDO EM ESTOQUE INSUFICIENTE PARA O PRODUTO")
		EndIF
	EndIF  

Return lRet
