#INCLUDE "PROTHEUS.CH"
#INCLUDE "POSCSS.CH"
#INCLUDE "PARMTYPE.CH"
//------------------------------------------------------------------------------
/*{Protheus.doc} StValPro
Funcao para validar se um determinado item podera ser registrado no PDV
@param   	PARAMIXB
@author     Elvis Siqueira
@version    P12
@since      22/01/2025
@return     lRet
/*/
//------------------------------------------------------------------------------
User Function StValPro()
	Local aArea     := FWGetArea()
	Local aAreaSL2  := SL2->(FWGetArea())
	Local aAreaSB2  := SB2->(FWGetArea())
	Local lRet      := .T.
	Local lEstNeg   := IIF(SuperGetMV("MV_ESTNEG") == "S",.T.,.F.)
	Local cCodProd  := PARAMIXB[1]
	Local cLocPad   := SuperGetMV("MV_LOCPAD",.F.,"")
	Local nQtdReg   := PARAMIXB[2]
	Local nQtdTab   := 0
	Local nSaldoAx  := 0
	Local cQry      := ""
	Local _cAlias   := GetNextAlias()

	Private nSaldo   := 0
	Private lErIntRM := .F.

	IF IsInCallStack("STBIMPORTSALE") .Or. SB1->B1_VALEPRE == "1"
		Return lRet
	EndIF 

	U_DSOAPF01("wsTprdLoc",cCodProd,cLocPad) //Faz consulta de estoque no TOTVS Corpore RM

	SB2->(MSseek(xFilial("SB2")+cCodProd+cLocPad))

	If lErIntRM //Caso ocorra erro na integracao com o RM, consulta o estoque no PDV. 
		IF !Empty(SB2->B2_QATU) .And. Empty(nSaldo)
			nSaldo := SB2->B2_QATU
		EndIF
	Else
		nSaldoAx := nSaldo-nQtdReg 	
		If !Empty(nSaldoAx) .And. SB2->B2_QATU < nSaldoAx
			RecLock("SB2",.F.)
                SB2->B2_QATU := nSaldo
                SB2->B2_DMOV := dDataBase
                SB2->B2_HMOV := Time()
            SB2->(MSUnlock())
		EndIF 
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

	FWRestArea(aArea)
	FWRestArea(aAreaSL2)
	FWRestArea(aAreaSB2)

Return lRet
