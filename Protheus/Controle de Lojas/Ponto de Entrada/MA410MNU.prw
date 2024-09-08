#Include "TOTVS.CH"

/*/{Protheus.doc} MA410MNU

Rotina Principal do Acelerador do Relatório do Pedido de Venda

@type function
@author TOTVS NORDESTE
@since 06/09/2024

@history 
/*/
User Function MA410MNU()
	
     If !IsBlind() 
          aAdd(aRotina,{"Envia RM","u_fIntRM",0,3,0,NIL})
     EndIf 

Return Nil 
