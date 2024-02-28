#INCLUDE 'Protheus.ch'
#INCLUDE 'PRTOPDEF.CH'

//-----------------------------------------------------------------------------
/*/{Protheus.doc} ValidSL2
	Validação de Estoque no Venda Assistida
/*/
//-----------------------------------------------------------------------------

User Function ValidSL2(cCampo)

	Local lRet 	  := .F.
	Local nSaldo  := 0
	Local nQuant  := 0
	Local nPosPro := aScan(aHeader, {|x| Alltrim(x[2])=="LR_PRODUTO" })
	Local cLocPad := SB1->B1_LOCPAD
	Local nPosQtd := aScan(aHeader, {|x| Alltrim(x[2])=="LR_QUANT" })
	Local nY 

	For nY := 1 To Len(aCOLS)
		If aCOLS[nY][nPosPro] == aCOLS[N][nPosPro]
			nQuant += aCOLS[nY][nPosQtd]
		EndIF
	Next 

	nSaldo := U_DSOAPF01(aCOLS[N][nPosPro],cLocPad)

	IF ValType(nSaldo) == "N"
		If cCampo == "LR_QUANT"
			IF nSaldo >= nQuant
				lRet:= .T.
			Else
				FWAlertWarning("A quantidade informada não contém em estoque." + CRLF + "A quantidade em estoque é: " + cValTochar(nSaldo) + CRLF + ;
							"Produtos sem estoque não devem ser faturados." + CRLF + ; 
							"Fonte ValidSL2.prw", "Integração TOTVS Corpore RM")
				EndIF
		Else
			IF nSaldo >= nQuant
				lRet:= .T.
			Else
				FWAlertError("O Produto escolhido não contém estoque."+ CRLF +;
							"Produtos sem estoque não devem ser faturados."+ CRLF +;
							"Fonte ValidSL2.prw", "Integração TOTVS Corpore RM")
			EndIF
		EndIf
	EndIF
	
Return lRet
