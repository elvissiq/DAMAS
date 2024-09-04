#Include "Protheus.ch"
 
/*-------------------------------------------------------------------------------------*
 | P.E.:  MS520VLD                                                                     |
 | Desc:  Esse ponto de entrada é chamado para validar ou não a exclusão da nota       |
 | Link:  https://tdn.totvs.com/display/public/PROT/MS520VLD                           |
 *-------------------------------------------------------------------------------------*/

User Function MS520VLD()
        Local aArea     := FWGetArea()
        Local aAreaSL1  := SL1->(FWGetArea())
        Local lTeveBX   := .F.
        Local lContinua := .F.
        Local aRet      := {}
        Local nY 
        
        Private lRet    := .F.
        Private cCodEmp := ""
        Private cCodFil := ""
        Private cUrl    := SuperGetMV("MV_XURLRM" ,.F.,"")
        Private cUser   := SuperGetMV("MV_XRMUSER",.F.,"")
        Private cPass   := SuperGetMV("MV_XRMPASS",.F.,"")

        DBSelectArea("SL1")
        SL1->(DBSetOrder(2))
        If SL1->(MsSeek(xFilial("SL1") + SF2->F2_SERIE + SF2->F2_DOC ))

                DBSelectArea("XXD")
                XXD->(DBSetOrder(3))
                If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
                        
                        cCodEmp := AllTrim(XXD->XXD_COMPA)
                        cCodFil := AllTrim(XXD->XXD_BRANCH)

                        IF AllTrim(SL1->L1_XINT_RM) == "S" .And. !Empty(SL1->L1_XIDMOV)
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
                                                                lContinua := FWMsgRun(,{|| u_fCanFinan(aRet[nY][2],aRet[nY][3]) }, "TOTVS Corpore RM", "Realizando cancelamento da Baixa...")
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
                        FWMsgRun(,{|| u_fCanMovim(aRet[1][1],aRet[1][4]) }, "TOTVS Corpore RM", "Realizando cancelamento do Movimento...")
                        If lRet
                                RecLock("SL1",.F.)
                                        SL1->L1_XIDMOV := ""
                                SL1->(MsUnlock())
                        EndIF
                EndIF 
        Else
                lRet := .T.
        EndIF 
        
        FWRestArea(aAreaSL1)
        FWRestArea(aArea)
        
Return lRet
