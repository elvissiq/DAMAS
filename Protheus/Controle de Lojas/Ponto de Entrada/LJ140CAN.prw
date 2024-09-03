#Include "Protheus.ch"
 
/*-------------------------------------------------------------------------------------*
 | P.E.:  LJ140CAN                                                                     |
 | Desc:  Esse ponto de entrada efetua a validação da exclusão da Nota Fiscal.         |
 | Link:  https://tdn.totvs.com/pages/releaseview.action?pageId=6790823                |
 *-------------------------------------------------------------------------------------*/

User Function LJ140CAN()
        Local aArea     := FWGetArea()
        Local lRet      := .F.
        Local lTeveBX   := .F.
        Local lContinua := .F.
        Local aRet      := {}
        Local nY 
        
        Private cCodEmp   := ""
        Private cCodFil   := ""

        DBSelectArea("XXD")
        XXD->(DBSetOrder(3))
        If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
                
                cCodEmp := AllTrim(XXD->XXD_COMPA)
                cCodFil := AllTrim(XXD->XXD_BRANCH)
                
                IF AllTrim(SL1->L1_XINT_RM) == "S" .And. !Empty(SL1->L1_XIDMOV)
                        aRet := U_fnConsultBX(SL1->L1_XIDMOV)
                        IF Len(aRet) > 0
                                
                                For nY := 1 To Len(aRet)
                                      lTeveBX := .T.  
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
                EndIF 
        EndIF

        If lContinua
                lRet := u_fCanMovim(pIDMov,pNumMov)
        EndIF 

        FWRestArea(aArea)

Return lRet
