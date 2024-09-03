#Include "Protheus.ch"
 
/*-------------------------------------------------------------------------------------*
 | P.E.:  MT103EXC                                                                     |
 | Desc:  Ponto de entrada para validação da exclusão do documento de entrada.         |
 | Link:  https://tdn.totvs.com/pages/releaseview.action?pageId=184781713              |
 *-------------------------------------------------------------------------------------*/

User Function MT103EXC()
        Local aArea     := FWGetArea()
        Local lRet      := .F.
        Local lTeveBX   := .F.
        Local lContinua := .F.
        Local aRet      := {}
        Local nY 
        
        Private cCodEmp := ""
        Private cCodFil := ""
        Private cUrl    := SuperGetMV("MV_XURLRM" ,.F.,"")
        Private cUser   := SuperGetMV("MV_XRMUSER",.F.,"")
        Private cPass   := SuperGetMV("MV_XRMPASS",.F.,"")

        DBSelectArea("XXD")
        XXD->(DBSetOrder(3))
        If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
                
                cCodEmp := AllTrim(XXD->XXD_COMPA)
                cCodFil := AllTrim(XXD->XXD_BRANCH)
                
                IF AllTrim(SF1->F1_XINT_RM) == "S" .And. !Empty(SF1->F1_XIDMOV)
                        aRet := U_fnConsultBX(AllTrim(SF1->F1_XIDMOV))
                        IF Len(aRet) > 0
                                
                                For nY := 1 To Len(aRet)
                                      IF aRet[nY][3] <> '0'
                                        lTeveBX := .T.  
                                      EndIF 
                                Next 

                                If lTeveBX
                                        For nY := 1 To Len(aRet)
                                                IF !Empty(aRet[nY][3])
                                                        lContinua := u_fCanFinan(aRet[nY][2],aRet[nY][3])
                                                EndIF 
                                        Next
                                Else
                                      lContinua := .T.  
                                EndIF 
                        EndIF 
                Else
                     lRet := .T.  
                EndIF 
        EndIF

        If lContinua
                lRet := u_fCanMovim(aRet[1][1],aRet[1][4])
        EndIF 

        FWRestArea(aArea)
        
Return lRet
