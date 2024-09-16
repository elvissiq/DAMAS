#INCLUDE "PROTHEUS.CH"
#INCLUDE "POSCSS.CH"
#INCLUDE "PARMTYPE.CH"
//------------------------------------------------------------------------------
/*{Protheus.doc} StValPro
Funcao para validar se um determinado item poder� ser registrado no PDV
@param   	PARAMIXB
@author     Elvis Siqueira
@version    P12
@since      18/06/2024
@return     lRet
/*/
//------------------------------------------------------------------------------
User Function StValPro()
	Local oRest, oJson
	Local lRet      := .T.
	Local lEstNeg   := IIF(SuperGetMV("MV_ESTNEG") == "S",.T.,.F.)
	Local cCodProd  := PARAMIXB[1]
	Local cLocPad   := SuperGetMV("MV_LOCPAD",.F.,"")
	Local nQtdReg   := PARAMIXB[2]
	Local nQtdTab   := 0
	Local cQry      := ""
	Local _cAlias   := GetNextAlias()
	Local cUrlOff  	:= SuperGetMV("MV_XURLOFF",.F.,"http://localhost:83/rest")
	Local cResource := "/api/retail/v1/retailStockLevel"
	Local cUsrPDVOf := SuperGetMV("MV_XUSROFF",.F.,"admin")
	Local cPasPDVOf := SuperGetMV("MV_XPASOFF",.F.,"admin") 	
	Local aHeader   := {}
	Local cTextJson := ""

	Private nSaldo   := 0
	Private lErIntRM := .F.

	U_DSOAPF01("wsTprdLoc",cCodProd,cLocPad)

	If lErIntRM //Caso ocorra erro na integracao com o RM, consulta o estoque local.
		
		oRest := FwRest():New(cUrlOff)                           
		oJson := JsonObject():New()
		
		aAdd(aHeader, "Authorization: Basic " + Encode64(cUsrPDVOf+":"+cPasPDVOf))
		aAdd(aHeader, "Content-Type: application/json")
		
		oRest:SetPath(cResource + '?iteminternalId=' + AllTrim(cCodProd))
		
		If (oRest:Get(aHeader))
			cTextJson := oRest:GetResult()
			cTextJson := oJson:FromJson(cTextJson)
			BBGJson(oJson)
			u_fnGrvLog("retailStockLevel",cResource + '?iteminternalId=' + AllTrim(cCodProd),cTextJson,'','Produto: ' + AllTrim(cCodProd),'2','Consulta de estoque no PDV Centralizador')
		Else
			ConOut("POST: " + oRest:GetLastError())
			u_fnGrvLog("retailStockLevel",cResource + '?iteminternalId=' + AllTrim(cCodProd),'',oRest:GetLastError(),'Produto: ' + AllTrim(cCodProd),'2','Consulta de estoque no PDV Centralizador')
			
			DBSelectArea("SB2")
			SB2->(DBGoTop())
			If SB2->(MSseek(xFilial("SB2")+cCodProd+cLocPad))
				nSaldo := SaldoSB2()
			EndIF
		EndIF 

		FreeObj(oJson)
	EndIF
	
	cQry := " SELECT SUM(L2_QUANT) AS QUANT FROM " + RetSQLName('SL2')
	cQry += " WHERE D_E_L_E_T_ <> '*' AND L2_NUM = '" + SL1->L1_NUM + "' AND L2_PRODUTO = '" + cCodProd + "' "
	cQry := ChangeQuery(cQry)
    IF Select(_cAlias) <> 0
    	(_cAlias)->(DbCloseArea())
    EndIf
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)

	If ! (_cAlias)->(EoF())
		IF ValType((_cAlias)->QUANT) == "N"
			nQtdTab := (_cAlias)->QUANT
		EndIF
	EndIF 
	(_cAlias)->(DbCloseArea()) 

	Do Case
		Case ValType(nSaldo) == "N"
			IF nSaldo < (nQtdReg + nQtdTab) .And. !(lEstNeg)
				STFMessage("ItemRegistered","STOP","ITEM NAO REGISTRADO - SALDO EM ESTOQUE INSUFICIENTE PARA O PRODUTO")
				lRet := .F.
			EndIF
	EndCase

Return lRet
