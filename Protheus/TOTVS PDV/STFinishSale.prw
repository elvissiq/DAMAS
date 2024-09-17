#INCLUDE "PROTHEUS.CH"
#INCLUDE "POSCSS.CH"
#INCLUDE "PARMTYPE.CH"
//------------------------------------------------------------------------------
/*{Protheus.doc} STFinishSale
Possibilitar a gravação de arquivos complementares. O ponto de entrada é 
executado após o fechamento do cupom e da venda.
@param   	PARAMIXB
@author     Elvis Siqueira
@version    P12
@since      17/09/2024
@return     lRet
/*/
//------------------------------------------------------------------------------
User Function STFinishSale()
	Local aArea    := FWGetArea()
	Local aAreaSL2 := SL2->(FWGetArea())
	Local aAreaSB2 := SB2->(FWGetArea())
	Local cNumOrc  := PARAMIXB[2]
	Local cQry     := ""
	Local _cAlias  := GetNextAlias()
	
	IF IsInCallStack("STBIMPORTSALE")
		Return
	EndIF 

	DBSelectArea("SB2")
	
	cQry := " SELECT L2_PRODUTO, L2_LOCAL, L2_QUANT FROM " + RetSQLName('SL2')
	cQry += " WHERE D_E_L_E_T_ <> '*' AND L2_NUM = '" + cNumOrc + "' "
	cQry := ChangeQuery(cQry)
    IF Select(_cAlias) <> 0
    	(_cAlias)->(DbCloseArea())
    EndIf
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)

	While (_cAlias)->(!EoF())
		If SB2->(MSseek(xFilial("SB2") + (_cAlias)->L2_PRODUTO + (_cAlias)->L2_LOCAL ))
			
			RecLock("SB2",.F.)
				SB2->B2_QATU := SB2->B2_QATU - (_cAlias)->L2_QUANT
			SB2->(MSUnlock())
		
		EndIF
	(_cAlias)->(DBSkip())
	EndDo  
	(_cAlias)->(DbCloseArea()) 

	FWRestArea(aArea)
	FWRestArea(aAreaSL2)
	FWRestArea(aAreaSB2)

Return
