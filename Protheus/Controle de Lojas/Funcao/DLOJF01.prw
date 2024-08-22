//Bibliotecas
#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'
#Include "TBICONN.CH"
#Include "TopConn.ch"

Static cAlias  := "SZ2"
Static cTitulo := "Produto x Centro de Custo"

//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} DLOJF01
FUNÇÃO DLOJF01 - Tela para cadastro do Produto x Centro de Custo
@OWNER VAZAO  
@VERSION PROTHEUS 12
@SINCE 22/08/2022
/*/
//----------------------------------------------------------------------

User Function DLOJF01()
Local aArea   := GetArea()
Local oBrowse

oBrowse := FWMBrowse():New()
oBrowse:SetAlias(cAlias)
oBrowse:SetDescription(cTitulo)

oBrowse:SetMenuDef("DLOJF01")

oBrowse:Activate()

RestArea(aArea)
Return

/*---------------------------------------------------------------------*
 | Func:  MenuDef                                                      |
 | Desc:  Criação do Menu MVC                                          |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
Static Function MenuDef()
Local aRotFISF7 := FWMVCMenu("DLOJF01")

Return (aRotFISF7)

/*---------------------------------------------------------------------*
 | Func:  ModelDef                                                     |
 | Desc:  Criação do modelo de dados MVC                               |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ModelDef()
Local oModel
Local oStruct := FWFormStruct(1, cAlias)

    oModel := MPFormModel():New("DLOJF01M", /*bPre*/,/*bPost*/,/*bCommit*/,/*bCancel*/)
    oModel:AddFields(cAlias+"MASTER", /*cOwner*/, oStruct)
    oModel:SetPrimaryKey({})

Return oModel
 
/*---------------------------------------------------------------------*
 | Func:  ViewDef                                                      |
 | Desc:  Criação da visão MVC                                         |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ViewDef()
Local oModel := FWLoadModel("DLOJF01")
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
