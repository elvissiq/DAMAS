//Bibliotecas
#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'
#Include "TBICONN.CH"
#Include "TopConn.ch"

Static cAlias  := "SZ4"
Static cTitulo := "Forma de Pagamento x Cod. Cx"

//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} DLOJF03
FUNÇÃO DLOJF03 - Tela para cadastro da Forma de Pagamento x Cod. Caixa
@VERSION PROTHEUS 12
@SINCE 17/09/2024
/*/
//----------------------------------------------------------------------

User Function DLOJF03()
Local aArea   := GetArea()
Local oBrowse

oBrowse := FWMBrowse():New()
oBrowse:SetAlias(cAlias)
oBrowse:SetDescription(cTitulo)

oBrowse:SetMenuDef("DLOJF03")

oBrowse:Activate()

RestArea(aArea)
Return

/*---------------------------------------------------------------------*
 | Func:  MenuDef                                                      |
 | Desc:  Criação do Menu MVC                                          |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
Static Function MenuDef()
Local aRotFISF7 := FWMVCMenu("DLOJF03")

Return (aRotFISF7)

/*---------------------------------------------------------------------*
 | Func:  ModelDef                                                     |
 | Desc:  Criação do modelo de dados MVC                               |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ModelDef()
Local oModel
Local oStruct := FWFormStruct(1, cAlias)

    oModel := MPFormModel():New("DLOJF03M", /*bPre*/,/*bPost*/,/*bCommit*/,/*bCancel*/)
    oModel:AddFields(cAlias+"MASTER", /*cOwner*/, oStruct)
    oModel:SetPrimaryKey({})

Return oModel
 
/*---------------------------------------------------------------------*
 | Func:  ViewDef                                                      |
 | Desc:  Criação da visão MVC                                         |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ViewDef()
Local oModel := FWLoadModel("DLOJF03")
Local oStruct := FWFormStruct(2, cAlias)
Local oView

    oView := FWFormView():New()    
    oView:SetModel(oModel)
    oView:SetProgressBar(.T.)
    
    oView:AddField("VIEW_"+cAlias, oStruct, cAlias+"MASTER")

    oView:CreateHorizontalBox("TELA" , 100 )
    oView:SetOwnerView("VIEW_"+cAlias, "TELA")

    oView:SetCloseOnOk({||.T.})
     
Return oView
