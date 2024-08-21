#Include "Protheus.ch"
#Include "TBICONN.CH"
#Include "TopConn.ch"

/*/{Protheus.doc} M460FIM
Gravação dos dados após gerar NF de Saída
@author TOTVS NORDESTE
@since 21/08/2024
@version 1.0
    @return Nil, Função não tem retorno
    @example
    M460FIM()
    @obs http://tdn.totvs.com/pages/releaseview.action?pageId=6784180
/*/

User Function M460FIM()
	Local aPEArea := FWGetArea()

  	U_DSOAPF01("MovMovimentoTBCData")
  
  	FWRestArea(aPEArea)
Return
