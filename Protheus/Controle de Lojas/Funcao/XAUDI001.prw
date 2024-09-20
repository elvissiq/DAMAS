#Include "Protheus.ch"
#Include "FWMVCDEF.ch"
#Include "TOTVS.ch"

// ---------------------------------------------------------
/*/ Rotina XAUDI001

   Auditoria da integração PROTHEUS

  @Author Elvis Siqueira (TOTVS NE)
  Retorno
  @História 
    04/09/2024 - Desenvolvimento da Rotina.
/*/
// ---------------------------------------------------------
User Function XAUDI001()
  Local oBrowse
  
  oBrowse := FWMBrowse():New()
	
  oBrowse:SetAlias("SZ1")
  oBrowse:AddLegend("Z1_STATUS == 'S'", "GREEN", "Sucesso") 
  oBrowse:AddLegend("Z1_STATUS == 'E'", "RED"  , "Erro") 
  oBrowse:SetDescription("Log Integração")
  oBrowse:Activate()
Return

//--------------------------------------------------------
/*/ Função MenuDef
    Define as operações serão realizadas pela aplicação
/*/
//--------------------------------------------------------
Static Function MenuDef()
  Local aRotina := {}

  Add Option aRotina Title "Visualizar"       Action "VIEWDEF.XAUDI001" Operation 2 Access 0
  
Return aRotina

//-------------------------------------------
/*/ Função MenuDef
    Define a legenda da tela
/*/
//-------------------------------------------
User Function fn001LEG() 
  Local aLegenda := {}
   
  aAdd(aLegenda, {"BR_VERDE"   ,"Sucesso"}) 
  aAdd(aLegenda, {"BR_VERMELHO","Erro"}) 

  BrwLegenda(cCadastro,"Legenda",aLegenda) 
Return 

//-------------------------------------------
/*/ Função ModelDef
    Define as regras de negocio.
/*/
//-------------------------------------------
Static Function ModelDef() 
  Local oModel 
  Local oStruSZ1 := FWFormStruct(1,"SZ1") 
  
  oModel := MPFormModel():New("LOG",,{})  
 
  oModel:AddFields("MSTSZ1",,oStruSZ1)
  oModel:SetPrimaryKey({""})
Return oModel 

//-------------------------------------------
/*/ Função ViewDef
    Define toda a parte visual aplicação.
/*/
//-------------------------------------------
Static Function ViewDef() 
  Local oModel  := ModelDef() 
  Local oStrSZ1 := FWFormStruct(2, "SZ1")   
  Local oView 

  oView := FWFormView():New() 
   
  oView:SetModel(oModel)    
  oView:AddField("FCAB",oStrSZ1,"MSTSZ1")  

  oView:CreateHorizontalBox("BOXE",100)  
	 			
  oView:SetOwnerView("FCAB","BOXE")  
Return oView
