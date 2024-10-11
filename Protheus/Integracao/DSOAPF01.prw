#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"
#Include 'FWMVCDef.ch'
#INCLUDE "FWEVENTVIEWCONSTS.CH"

//------------------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} DSOAPF01
User Function: DSOAPF01 - Função para Integração via Webservice SOAP com o TOTVS Corpore RM 
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 19/09/2024
@Permite
Programa Fonte
/*/
User Function DSOAPF01(pEndpoint,pCodProd,pLocPad)
    Local cEndPoint := ""
    
    Default PARAMIXB  := {}
    Default pEndpoint := ""
    Default pCodProd  := ""
    Default pLocPad   := ""

    If ValType(pEndpoint) == "A" .And. IsInCallStack("WFLAUNCHER")
        RpcClearEnv()
        RpcSetType(3) 
        RpcSetEnv(pEndpoint[1], pEndpoint[2], "Administrador", , "LOJA")
    ElseIF !Empty(pEndpoint)
        cEndPoint := pEndpoint
    ElseIF Len(PARAMIXB) > 0
        cEndPoint := PARAMIXB[1] 
    EndIf

    FwLogMsg("INFO", , "REST", 'DSOAPF01', "", "01", '=== Inicio da Integracao com o Corpore RM ===')

    If Empty(cEndPoint)
        u_fIntRM('wsCliForResumo',.F.)

        u_fIntRM('wsProdutos',.F.)
        
        u_fIntRM('wsNatClFiscal',.F.)

        u_fIntRM('wsTabPreco',.F.)

        u_fIntRM('wsPontoVenda',.F.)

        u_fIntRM('wsPrdCodBarras',.F.)
        
        u_fIntRM('wsFormaPagamento',.F.)

        u_fIntRM('wsPrdFilCCusto',.F.)
        
        u_fIntRM('wsFpagtoCaixa',.F.)

        u_fIntRM('MovMovCopiaReferenciaData',.F.)

        u_fIntRM('MovMovimentoTBCData',.F.)

        u_fIntRM('MovMovimentoPedido',.F.)
    Else
        Processa({|| u_fIntRM(cEndPoint,.T.,pCodProd,pLocPad)}, "Integrando Endpoint " + cEndPoint + "...")
    EndIf

    If Len(PARAMIXB) > 0 .And. IsInCallStack("WFLAUNCHER")
        RPCClearEnv()
    EndIF 

    FwLogMsg("INFO", , "REST", 'DSOAPF01', "", "01", '===  Finalizou a Integracao com o Corpore RM === ')

Return 

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fIntRM
Prepara o ambiente para iniciar a integracao dos Endpoints
/*/
//------------------------------------------------------------------------------------------
User Function fIntRM(pEndpoint,pMsg,pCodProd,pLocPad)

    Local aArea := FWGetArea()
    Local aSM0Data  := FWLoadSM0()
    Local cEmpBkp   := ""
    Local cFilBkp   := ""
    Local cEmpAux   := ""
    Local cFilAux   := ""
    Local cQry      := ""
    Local _cAlias   := GetNextAlias()
    Local nY 

    Default pEndpoint := ""
    Default pMsg      := .F.
    Default pCodProd  := ""
    Default pLocPad   := ""

    Private cUrl      := SuperGetMV("MV_XURLRM" ,.F.,"https://associacaodas145873.rm.cloudtotvs.com.br:1801")
    Private cUser     := SuperGetMV("MV_XRMUSER",.F.,"rimeson")
    Private cPass     := SuperGetMV("MV_XRMPASS",.F.,"123456")
    Private cDiasInc  := SuperGetMV("MV_XDINCRM",.F.,"0")
    Private cDiasAlt  := SuperGetMV("MV_XDALTRM",.F.,"-365")
    Private cCodEmp   := ""
    Private cCodFil   := ""
    Private cPicVal   := PesqPict( "SL1", "L1_VALBRUT")
    Private cEndPoint := pEndpoint 
    Private lMsg      := pMsg
    
    Do Case
        Case (IsInCallStack("LOJA701"))
            IF SL1->L1_SITUA == 'OK' .And. ( Empty(SL1->L1_XINT_RM) .Or. AllTrim(SL1->L1_XINT_RM) == "C" )
                cEndPoint := "MovMovimentoTBCData"
            ElseIF SL1->L1_SITUA == 'FR' .And. ( Empty(SL1->L1_XINT_RM) .Or. AllTrim(SL1->L1_XINT_RM) == "C" )
                cEndPoint := "MovMovimentoPedido"
            Else
                IF !IsBlind()
                    FWAlertHelp('O orçamento '+ SL1->L1_NUM +', não será enviado!',;
                                'Apenas orçamentos com o campo L1_SITUA igual a OK ou FR e os campos (L1_XIDMOV e L1_XINT_RM) em branco são enviados ao RM.')
                EndIF
                Return
            EndIF 
            lMsg := .T.
        Case (IsInCallStack("MATA103"))
            If Empty(SF1->F1_XIDMOV) .And. ( Empty(SF1->F1_XINT_RM) .Or. AllTrim(SF1->F1_XINT_RM) == "C" )
                cEndPoint := "MovMovCopiaReferenciaData"
            Else
                IF !IsBlind()
                    FWAlertHelp('A Nota Fiscal: '+ AllTrim(SF1->F1_DOC) + " / Série: " + AllTrim(SF1->F1_SERIE) +', não será enviada!',;
                                'Apenas Notas Fiscais com os campos (F1_XIDMOV e F1_XINT_RM) em branco são enviadas ao RM.')
                EndIF
                Return
            EndIF 
            lMsg := .T. 
    End Case

    DBSelectArea("XXD")
    XXD->(DBSetOrder(3))
    If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
        cCodEmp := AllTrim(XXD->XXD_COMPA)
        cCodFil := AllTrim(XXD->XXD_BRANCH)
        cEmpAux := cCodEmp
        cFilAux := cCodFil
        cEmpBkp := cEmpAnt
        cFilBkp := cFilAnt
    Else 
        ApMsgStop("Coligada + Filial não encontrada no De/Para." + CRLF + CRLF +;
                  "Por favor acessar a rotina De/Para de Empresas Mensagem Unica (APCFG050), no SIGACFG e cadastrar o De/Para." + CRLF + ;
                  "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
        lErIntRM := .T.
        Return
    EndIF 

    Do Case 
        Case cEndPoint == 'wsCliForResumo'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsCliForR()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsProdutos'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsProdutos()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsNatClFiscal'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            For nY := 1 TO Len(aSM0Data)
                If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                    cCodEmp := AllTrim(XXD->XXD_COMPA)
                    cCodFil := AllTrim(XXD->XXD_BRANCH)
                    cEmpAnt := AllTrim(aSM0Data[nY][01])
                    cFilAnt := AllTrim(aSM0Data[nY][02])
                    fwsNatClFiscal()
                EndIF 
            Next 
            cCodEmp := cEmpAux
            cCodFil := cFilAux
            cEmpAnt := cEmpBkp
            cFilAnt := cFilBkp
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')

        Case cEndPoint == 'wsTabPreco'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            For nY := 1 TO Len(aSM0Data)
                If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                    cCodEmp := AllTrim(XXD->XXD_COMPA)
                    cCodFil := AllTrim(XXD->XXD_BRANCH)
                    cEmpAnt := AllTrim(aSM0Data[nY][01])
                    cFilAnt := AllTrim(aSM0Data[nY][02])
                    fwsTabPreco()
                EndIF 
            Next 
            cCodEmp := cEmpAux
            cCodFil := cFilAux
            cEmpAnt := cEmpBkp
            cFilAnt := cFilBkp
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsTabPrcUni'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            cEndPoint := "wsTabPreco"
            fwsTabPreco()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsPontoVenda'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsPontoVenda()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsPrdCodBarras'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsPrdCodBarras()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsPrdFilCCusto'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            For nY := 1 TO Len(aSM0Data)
                If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                    cCodEmp := AllTrim(XXD->XXD_COMPA)
                    cCodFil := AllTrim(XXD->XXD_BRANCH)
                    cEmpAnt := AllTrim(aSM0Data[nY][01])
                    cFilAnt := AllTrim(aSM0Data[nY][02])
                    fwsPrdFilCCusto()
                EndIF 
            Next 
            cCodEmp := cEmpAux
            cCodFil := cFilAux
            cEmpAnt := cEmpBkp
            cFilAnt := cFilBkp
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'wsFormaPagamento'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsFormaPagamento()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')

        Case cEndPoint == 'wsFpagtoCaixa'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            For nY := 1 TO Len(aSM0Data)
                If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                    cCodEmp := AllTrim(XXD->XXD_COMPA)
                    cCodFil := AllTrim(XXD->XXD_BRANCH)
                    cEmpAnt := AllTrim(aSM0Data[nY][01])
                    cFilAnt := AllTrim(aSM0Data[nY][02])
                    fwsFpagtoCaixa()
                EndIF 
            Next 
            cCodEmp := cEmpAux
            cCodFil := cFilAux
            cEmpAnt := cEmpBkp
            cFilAnt := cFilBkp
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')

        Case cEndPoint == 'wsTprdLoc'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fwsTprdLoc(pCodProd,pLocPad)
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'MovMovCopiaReferenciaData'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            IF IsInCallStack("U_INTTSTRM") .And. IsInCallStack("WFLAUNCHER")
                
                For nY := 1 TO Len(aSM0Data)
                    If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                        cCodEmp := AllTrim(XXD->XXD_COMPA)
                        cCodFil := AllTrim(XXD->XXD_BRANCH)
                        cEmpAnt := AllTrim(aSM0Data[nY][01])
                        cFilAnt := AllTrim(aSM0Data[nY][02])
                        
                        cQry := " SELECT * FROM " + RetSQLName('SF1')
                        cQry += " WHERE D_E_L_E_T_ <> '*' "
                        cQry += " AND F1_FILIAL = '" + xFilial("SF1") + "' "
                        cQry += " AND F1_DOC <> '' "
                        cQry += " AND F1_SERIE <> '' "
                        cQry += " AND F1_XINT_RM = '' "
                        cQry := ChangeQuery(cQry)
                        IF Select(_cAlias) <> 0
                            (_cAlias)->(DbCloseArea())
                        EndIf
                        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)
                        DBSelectArea("SF1")
                        While !(_cAlias)->(EoF())
                            SF1->(MSSeek(xFilial("SF1")+(_cAlias)->F1_DOC+(_cAlias)->F1_SERIE+(_cAlias)->F1_FORNECE+(_cAlias)->F1_LOJA+(_cAlias)->F1_TIPO))
                            fEnvNFeDev()
                        (_cAlias)->(DBSkip())
                        EndDo
                        (_cAlias)->(DbCloseArea()) 
                    EndIF 
                Next 

            Else    
                fEnvNFeDev()
            EndIF 
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'MovMovimentoTBCData'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            IF IsInCallStack("U_INTTSTRM") .And. IsInCallStack("WFLAUNCHER")
                
                For nY := 1 TO Len(aSM0Data)
                    If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                        cCodEmp := AllTrim(XXD->XXD_COMPA)
                        cCodFil := AllTrim(XXD->XXD_BRANCH)
                        cEmpAnt := AllTrim(aSM0Data[nY][01])
                        cFilAnt := AllTrim(aSM0Data[nY][02])
                
                        cQry := " SELECT * FROM " + RetSQLName('SL1')
                        cQry += " WHERE D_E_L_E_T_ <> '*' "
                        cQry += " AND L1_FILIAL = '" + xFilial("SL1") + "' "
                        cQry += " AND L1_DOC <> '' "
                        cQry += " AND L1_SERIE <> '' "
                        cQry += " AND L1_SITUA = 'OK' "
                        cQry += " AND L1_XINT_RM = '' "
                        cQry := ChangeQuery(cQry)
                        IF Select(_cAlias) <> 0
                            (_cAlias)->(DbCloseArea())
                        EndIf
                        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)
                        DBSelectArea("SL1")
                        While !(_cAlias)->(EoF())
                            SL1->(MSSeek(xFilial("SL1")+(_cAlias)->L1_NUM))
                            fEnvNFeVend()
                        (_cAlias)->(DBSkip())
                        EndDo
                        (_cAlias)->(DbCloseArea()) 
                    EndIF 
                Next

            Else    
                fEnvNFeVend()
            EndIF  
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'MovMovimentoPedido'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            IF IsInCallStack("U_INTTSTRM") .And. IsInCallStack("WFLAUNCHER")
                
                For nY := 1 TO Len(aSM0Data)
                    If XXD->(MSSeek(Pad("RM",15)+aSM0Data[nY][01]+aSM0Data[nY][02]))
                        cCodEmp := AllTrim(XXD->XXD_COMPA)
                        cCodFil := AllTrim(XXD->XXD_BRANCH)
                        cEmpAnt := AllTrim(aSM0Data[nY][01])
                        cFilAnt := AllTrim(aSM0Data[nY][02])
                
                        cQry := " SELECT * FROM " + RetSQLName('SL1')
                        cQry += " WHERE D_E_L_E_T_ <> '*' "
                        cQry += " AND L1_FILIAL = '" + xFilial("SL1") + "' "
                        cQry += " AND L1_DOC <> '' "
                        cQry += " AND L1_SERIE <> '' "
                        cQry += " AND L1_SITUA = 'FR' "
                        cQry += " AND L1_STATUS = 'F' "
                        cQry += " AND L1_NUMORIG <> '' "
                        cQry += " AND L1_DOCPED <> '' "
                        cQry += " AND L1_SERPED <> '' "
                        cQry += " AND L1_XINT_RM = '' "
                        cQry := ChangeQuery(cQry)
                        IF Select(_cAlias) <> 0
                            (_cAlias)->(DbCloseArea())
                        EndIf
                        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)
                        DBSelectArea("SL1")
                        While !(_cAlias)->(EoF())
                            SL1->(MSSeek(xFilial("SL1")+(_cAlias)->L1_NUM))
                            fEnvPedVend()
                        (_cAlias)->(DBSkip())
                        EndDo
                        (_cAlias)->(DbCloseArea()) 
                    EndIF 
                Next

            Else    
                fEnvPedVend()
            EndIF  
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'FinLanBaixaCancelamentoData'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fCanFinan()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
        
        Case cEndPoint == 'MovCancelMovProc'
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Integrando Endpoint: '+ cEndPoint +' ===')
            fCanMovim()
            FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Finalizou a integracao do Endpoint: '+ cEndPoint +' ===')
    End Case 
    
    FWRestArea(aArea)

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsCliForR
Realiza a consulta de clientes atraves da API padrao RealizarConsultaSQL no RM (Resumido)
/*/
//------------------------------------------------------------------------------------------

Static Function fwsCliForR()

    Local oWsdl as Object
    Local oXml as Object 
    Local oModel as Object 
    Local oSA1Mod as Object
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cErro     := ""
    Local aRegXML   := {}
    Local aErro     := {}
    Local nY, lOk, nOpc

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N=0;ATIVO_N=1;CODCFO_S=TODOS;CGCCFO_S=TODOS;NOMEFANTASIA_S=TODOS;PAGREC_N=1;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SA1")
                DBSelectArea("SYA")
                SYA->(DBSetOrder(2))
                DBSelectArea("CCH")
                CCH->(DBSetOrder(2))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']') 

                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF 

                    If !Empty(aRegXML)

                        oModel := FWLoadModel("CRMA980")
                        IF SA1->(MsSeek(xFilial("SA1")+aRegXML[2,3]))
                            nOpc := 4
                            oModel:SetOperation(nOpc)
                        Else
                            nOpc := 3
                            oModel:SetOperation(nOpc)
                        EndIF 
                        oModel:Activate()
                        oSA1Mod:= oModel:getModel("SA1MASTER")

                        aRegXML[05][03] := StrTran(aRegXML[05][03],".","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"-","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"/","")

                        aRegXML[14][03] := StrTran(aRegXML[14][03],"-","")

                        aRegXML[15][03] := StrTran(aRegXML[15][03],"-","")
                        aRegXML[15][03] := StrTran(aRegXML[15][03],"(","")
                        aRegXML[15][03] := StrTran(aRegXML[15][03],")","")
                        aRegXML[15][03] := Pad(Alltrim(aRegXML[15][03]),FWTamSX3("A1_TEL")[1])

                        aRegXML[16][03] := StrTran(aRegXML[16][03],"-","")
                        aRegXML[16][03] := StrTran(aRegXML[16][03],"(","")
                        aRegXML[16][03] := StrTran(aRegXML[16][03],")","")
                        aRegXML[16][03] := Pad(Alltrim(aRegXML[16][03]),FWTamSX3("A1_FAX")[1])

                        aRegXML[17][03] := StrTran(aRegXML[17][03],"-","")
                        aRegXML[17][03] := StrTran(aRegXML[17][03],"(","")
                        aRegXML[17][03] := StrTran(aRegXML[17][03],")","")
                        aRegXML[17][03] := Pad(Alltrim(aRegXML[17][03]),FWTamSX3("A1_TELEX")[1])

                        If nOpc == 3
                        oSA1Mod:setValue("A1_COD"    ,aRegXML[02][03]                                                               ) // Codigo
                        oSA1Mod:setValue("A1_LOJA"   ,"01"                                                                          ) // Loja
                        EndIF 
                        oSA1Mod:setValue("A1_PESSOA" ,aRegXML[24][03]                                                               ) // Pessoa Fisica/Juridica
                        oSA1Mod:setValue("A1_TIPO"   ,"F"                                                                           ) // Tipo do Cliente (F=Cons.Final;L=Produtor Rural;R=Revendedor;S=Solidario;X=Exportacao)
                        oSA1Mod:setValue("A1_CGC"    ,aRegXML[05][03]                                                               ) // CNPJ/CPF
                        oSA1Mod:setValue("A1_INSCR"  ,aRegXML[06][03]                                                               ) // Inscricao Estadual
                        oSA1Mod:setValue("A1_NOME"   ,Upper(Pad(aRegXML[04][03],FWTamSX3("A1_NOME")[1]))                            ) // Nome
                        oSA1Mod:setValue("A1_NREDUZ" ,Upper(Pad(aRegXML[03][03],FWTamSX3("A1_NREDUZ")[1]))                          ) // Nome Fantasia
                        oSA1Mod:setValue("A1_END"    ,Upper(Pad(aRegXML[08][03] + ", " + aRegXML[09][03] ,FWTamSX3("A1_END")[1]))   ) // Endereco + Número
                        oSA1Mod:setValue("A1_COMPENT",Upper(Pad(aRegXML[10][03],FWTamSX3("A1_COMPENT")[1]))                         ) // Complemento
                        oSA1Mod:setValue("A1_BAIRRO" ,Upper(Pad(aRegXML[11][03],FWTamSX3("A1_BAIRRO")[1]))                          ) // Bairro
                        oSA1Mod:setValue("A1_CEP"    ,aRegXML[14][03]                                                               ) // CEP
                        oSA1Mod:setValue("A1_EST"    ,aRegXML[13][03]                                                               ) // Estado
                        oSA1Mod:setValue("A1_COD_MUN",aRegXML[25][03]                                                               ) // Municipio
                        oSA1Mod:setValue("A1_MUN"    ,aRegXML[12][03]                                                               ) // Municipio
                        oSA1Mod:setValue("A1_TEL"    ,aRegXML[15][03]                                                               ) // Telefone
                        oSA1Mod:setValue("A1_FAX"    ,aRegXML[16][03]                                                               ) // Numero do FAX
                        oSA1Mod:setValue("A1_TELEX"  ,aRegXML[17][03]                                                               ) // Telex
                        oSA1Mod:setValue("A1_EMAIL"  ,Pad(Alltrim(aRegXML[18][03]),FWTamSX3("A1_EMAIL")[1])                         ) // E-mail
                        oSA1Mod:setValue("A1_CONTATO",Pad(Alltrim(aRegXML[19][03]),FWTamSX3("A1_CONTATO")[1])                       ) // Contato
                        oSA1Mod:setValue("A1_LC"     ,Val(aRegXML[20][03])                                                          ) // Limite de Credito
                        oSA1Mod:setValue("A1_MSBLQL" ,IIF(aRegXML[19][03]=="1","2","1")                                             ) // Status (Ativo ou Inativo)
                        If !Empty(Upper(aRegXML[23][03])) .And. SYA->(MSSeek(xFilial("SYA")+Upper(aRegXML[23][03]))                 )
                            oSA1Mod:LoadValue("A1_PAIS"   ,SYA->YA_CODGI                                                            ) // Codigo do Pais
                        EndIF
                        If !Empty(Upper(aRegXML[23][03])) .And. CCH->(MSSeek(xFilial("CCH")+Upper(aRegXML[23][03])))
                            oSA1Mod:LoadValue("A1_CODPAIS",Alltrim(CCH->CCH_CODIGO)                                                 ) // Codigo do Pais Bacen.
                        EndIF

                        If oModel:VldData()
                            If oModel:CommitData()
                                lOk := .T.
                            Else
                                lOk := .F.
                            EndIf
                        Else
                            lOk := .F.
                        EndIf

                        If ! lOk
                            aErro := oModel:GetErrorMessage()
                            AutoGrLog("Id do formulário de origem:"  + ' [' + AllToChar(aErro[01]) + ']')
                            AutoGrLog("Id do campo de origem: "      + ' [' + AllToChar(aErro[02]) + ']')
                            AutoGrLog("Id do formulário de erro: "   + ' [' + AllToChar(aErro[03]) + ']')
                            AutoGrLog("Id do campo de erro: "        + ' [' + AllToChar(aErro[04]) + ']')
                            AutoGrLog("Id do erro: "                 + ' [' + AllToChar(aErro[05]) + ']')
                            AutoGrLog("Mensagem do erro: "           + ' [' + AllToChar(aErro[06]) + ']')
                            AutoGrLog("Mensagem da solução: "        + ' [' + AllToChar(aErro[07]) + ']')
                            AutoGrLog("Valor atribuído: "            + ' [' + AllToChar(aErro[08]) + ']')
                            AutoGrLog("Valor anterior: "             + ' [' + AllToChar(aErro[09]) + ']')
                            
                            cErro := aErro[06]
                            u_fnGrvLog(cEndPoint,cBody,'Erro',cErro,"Erro Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
                        Else
                            u_fnGrvLog(cEndPoint,cBody,'Sucesso',,"Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
                        EndIf

                        oModel:DeActivate()
                    EndIF 
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsProdutos
Realiza a consulta de Produtos atraves da API padrao RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsProdutos()

    Local oWsdl as Object
    Local oXml as Object 
    Local oModel as Object 
    Local oSB1Mod as Object
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cErro     := ""
    Local cTESSai   := ""
    Local cQryF4    := ""
    Local _cAliasF4 := GetNextAlias()
    Local aRegXML   := {}
    Local aErro     := {}
    Local nY, lOk, nOpc

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>VINCULADO_S=SIM;CODCOLIGADA_N='+cCodEmp+';INATIVO_N=2;ULTIMONIVEL_N=1;TIPO_S=P;IDPRD_N=0;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SB1")
                DBSelectArea("SYA")
                SYA->(DBSetOrder(2))
                DBSelectArea("CCH")
                CCH->(DBSetOrder(2))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')

                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF 

                    If !Empty(aRegXML)

                        cTESSai := ""
                        
                        cQryF4 := " SELECT F4_CODIGO FROM " + RetSQLName('SF4')
                        cQryF4 += " WHERE D_E_L_E_T_ <> '*' "
                        cQryF4 += " AND F4_FILIAL = '" + xFilial("SF4") + "' "
                        cQryF4 += " AND F4_XCLAFIS = '" + aRegXML[57][03] + "' "
                        cQryF4 := ChangeQuery(cQryF4)
                        IF Select(_cAliasF4) <> 0
                            (_cAliasF4)->(DbCloseArea())
                        EndIf
                        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQryF4),_cAliasF4,.T.,.T.)
                        IF (_cAliasF4)->(!EoF())
                            cTESSai := (_cAliasF4)->F4_CODIGO
                        EndIF
                        (_cAliasF4)->(DbCloseArea())

                        oModel := FWLoadModel("MATA010")
                        IF ! SB1->(MsSeek(xFilial("SB1")+aRegXML[04][03]))
                            nOpc := 3
                            oModel:SetOperation(nOpc)
                        Else
                            nOpc := 4
                            oModel:SetOperation(nOpc)
                        EndIF 
                        oModel:Activate()
                        oSB1Mod:= oModel:getModel("SB1MASTER")

                        IF nOpc == 3
                        oSB1Mod:setValue("B1_COD"    ,aRegXML[04][03]           ) // Codigo
                        EndIF
                        oSB1Mod:setValue("B1_DESC"   ,Alltrim(aRegXML[09][03])  ) // Descricao do Produto
                        oSB1Mod:setValue("B1_TIPO"   ,"ME"                      ) // Tipo de Produto (MP,PA,.)
                        oSB1Mod:setValue("B1_UM"     ,"UN"                      ) // Unidade de Medida
                        oSB1Mod:setValue("B1_LOCPAD" ,"01.02"                   ) // Armazem Padrao p/Requis.
                        oSB1Mod:setValue("B1_TS"     ,cTESSai                   ) // TES de Saída
                        oSB1Mod:setValue("B1_POSIPI" ,aRegXML[13][03]           ) // Nomenclatura Ext.Mercosul
                        oSB1Mod:setValue("B1_ORIGEM" ,"0"                       ) // Origem do Produto
                        oSB1Mod:setValue("B1_PESO"   ,Val(aRegXML[16][03])      ) // Peso Liquido
                        oSB1Mod:setValue("B1_PESBRU" ,Val(aRegXML[17][03])      ) // Peso Bruto
                        oSB1Mod:setValue("B1_PESBRU" ,Val(aRegXML[17][03])      ) // Peso Bruto
                        oSB1Mod:setValue("B1_XIDRM"  ,aRegXML[03][03]           ) // ID RM
                        oSB1Mod:setValue("B1_XCLAFIS",aRegXML[57][03]           ) // Classificação Fiscal RM

                        If oModel:VldData()
                            If oModel:CommitData()
                                lOk := .T.
                            Else
                                lOk := .F.
                            EndIf
                        Else
                            lOk := .F.
                        EndIf

                        If ! lOk
                            aErro := oModel:GetErrorMessage()
                            AutoGrLog("Id do formulario de origem:"  + ' [' + AllToChar(aErro[01]) + ']')
                            AutoGrLog("Id do campo de origem: "      + ' [' + AllToChar(aErro[02]) + ']')
                            AutoGrLog("Id do formulario de erro: "   + ' [' + AllToChar(aErro[03]) + ']')
                            AutoGrLog("Id do campo de erro: "        + ' [' + AllToChar(aErro[04]) + ']')
                            AutoGrLog("Id do erro: "                 + ' [' + AllToChar(aErro[05]) + ']')
                            AutoGrLog("Mensagem do erro: "           + ' [' + AllToChar(aErro[06]) + ']')
                            AutoGrLog("Mensagem da solucao: "        + ' [' + AllToChar(aErro[07]) + ']')
                            AutoGrLog("Valor atribuido: "            + ' [' + AllToChar(aErro[08]) + ']')
                            AutoGrLog("Valor anterior: "             + ' [' + AllToChar(aErro[09]) + ']')
                            
                            cErro := aErro[06]
                            u_fnGrvLog(cEndPoint,cBody,cResult,cErro,"Erro Produto: " + aRegXML[04][03] + " - " +aRegXML[09][03],cValToChar(nOpc),"Integracao Produto")
                        Else
                            u_fnGrvLog(cEndPoint,cBody,cResult,,"Produto: " + aRegXML[04][03] + " - " +aRegXML[09][03],cValToChar(nOpc),"Integracao Produto")
                        EndIf

                        oModel:DeActivate()
                    EndIF 
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsTabPreco
Realiza a consulta da Tabela de Preco atraves da API padrao RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsTabPreco()

    Local oWsdl as Object
    Local oXml as Object  
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cErro     := ""
    Local cQuery    := ""
    Local cSeq      := ""
    Local cAlias    := ""
    Local aRegXML   := {}
    Local aErro     := {}
    Local aRegDA0   := {}
    Local aRegDA1   := {}
    Local aLinha    := {}
    Local nY, nOpc, nAux

    Private lMSHelpAuto     := .T.
    Private lAutoErrNoFile  := .T.
    Private lMsErroAuto     := .F.

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+';IDPRD_N=0;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("DA0")
                DBSelectArea("DA1")
                
                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF DA0->(MsSeek(xFilial("DA0") + StrZero(Val(aRegXML[02][03]), FWTamSX3("DA0_CODTAB")[1])))
                            nOpc := 4
                        Else
                            nOpc := 3
                        EndIF 
                        
                        aRegDA0 := {}
                        aLinha  := {}
                        aRegDA1 := {}

                        aAdd(aRegDA0,{"DA0_CODTAB" , StrZero(Val(aRegXML[02][03]), FWTamSX3("DA0_CODTAB")[1]), Nil} ) // Codigo
                        aAdd(aRegDA0,{"DA0_DESCRI" , aRegXML[03][03]                                         , Nil} ) // Descricao
                        aAdd(aRegDA0,{"DA0_DATDE"  , FwDateTimeToLocal(aRegXML[12][03])[1]                   , Nil} ) // Data Inicial
                        aAdd(aRegDA0,{"DA0_HORADE" , SubStr(FwDateTimeToLocal(aRegXML[12][03])[2],1,5)       , Nil} ) // Hora Inicial
                        aAdd(aRegDA0,{"DA0_DATATE" , FwDateTimeToLocal(aRegXML[13][03])[1]                   , Nil} ) // Data Final  
                        aAdd(aRegDA0,{"DA0_HORATE" , SubStr(FwDateTimeToLocal(aRegXML[13][03])[2],1,5)       , Nil} ) // Hora Final

                        DA1->(DBGoTop())

                        If nOpc == 4
                            IF DA1->(MsSeek(xFilial("DA1") + StrZero(Val(aRegXML[02][03]), FWTamSX3("DA0_CODTAB")[1]) + Alltrim(aRegXML[07][03]) ))
                                aLinha := {}
                                aAdd(aLinha,{"LINPOS", "DA1_ITEM", DA1->DA1_ITEM})
                                aAdd(aLinha,{"AUTDELETA", "N", Nil})
                            Else
                                DA1->(DBGoTop())
                                IF DA1->(MsSeek(xFilial("DA1") + DA0->DA0_CODTAB))
                                    While DA1->(!Eof()) .And. DA1->DA1_CODTAB == DA0->DA0_CODTAB
                                        aLinha := {}
                                        aAdd(aLinha,{"LINPOS", "DA1_ITEM", DA1->DA1_ITEM})
                                        aAdd(aRegDA1,aLinha)
                                        DA1->(DBSkip())
                                    End
                                EndIF 
                                //Pega o ultimo item da DA1 e soma +1
                                cAlias := Alias()
                                cQuery := GetNextAlias()
                                BeginSQL alias cQuery
                                    SELECT MAX(DA1_ITEM) SEQ_MAX
                                    FROM %table:DA1%
                                    WHERE DA1_FILIAL = %xfilial:DA1%
                                    AND DA1_CODTAB = %exp:DA0->DA0_CODTAB%
                                    AND %notDel%
                                EndSQL
                                IF !(cQuery)->(Eof())
                                    cSeq := Soma1((cQuery)->SEQ_MAX)
                                EndIF
                                (cQuery)->(DBCloseArea())
                                IF !Empty(cAlias)
                                    DBSelectArea(cAlias)
                                EndIF
                                //-------------------------------------
                                aLinha  := {}
                                aAdd(aLinha,{"DA1_ITEM", cSeq , Nil})
                            EndIF
                        ElseIF nOpc == 3
                            aAdd(aLinha,{"DA1_ITEM", '0001', Nil})
                        EndIF 

                        aAdd(aLinha,{"DA1_CODPRO", aRegXML[07][03]                       , Nil} ) // Codigo do Produto
                        aAdd(aLinha,{"DA1_PRCVEN", Round(Val(aRegXML[11][03]),2)         , Nil} ) // Preco de venda
                        aAdd(aLinha,{"DA1_ATIVO" , IIF(aRegXML[14][03] == "1","1","2")   , Nil} ) // Item Ativo (1=Sim;2=Nao)
                        aAdd(aRegDA1,aLinha)

                        lMsErroAuto := .F.

                        MSExecAuto({|x,y,z| Omsa010(x,y,z)},aRegDA0,aRegDA1,nOpc)

                        If lMsErroAuto
                            aErro := GetAutoGRLog()
                            cErro := ""
                            
                            For nAux := 1 To Len(aErro)
                                cErro += aErro[nAux] + CRLF
                            Next
                            
                            u_fnGrvLog(cEndPoint,cBody,'',cErro,"Erro Tabela de Preco: " + StrZero(Val(aRegXML[02][03]), FWTamSX3("DA0_CODTAB")[1]) + " - " +aRegXML[07][03],cValToChar(nOpc),"Integracao Tabela de Preco")
                        Else
                            u_fnGrvLog(cEndPoint,cBody,'',,"Tabela de Preco: " + StrZero(Val(aRegXML[02][03]), FWTamSX3("DA0_CODTAB")[1]) + " - " +aRegXML[07][03],cValToChar(nOpc),"Integracao Tabela de Preco")
                        EndIf

                    EndIF 
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fwsTprdLoc
Realiza a consulta de estoque atraves da API employeeDataContent no RM
/*/
//-----------------------------------------------------------------------------

Static Function fwsTprdLoc(pCodProd,pLocPad)

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cCodProd  := pCodProd
    Local cLocEstoq := pLocPad
    Local cIDProd   := Alltrim(Posicione("SB1",1,xFilial("SB1")+cCodProd,"B1_XIDRM"))

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>wsTprdLoc</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>VINCULADO_S=SIM;CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+';CODLOC_S='+cLocEstoq+';IDPRD_N='+cIDProd+';CRIACAO_N=0;ALTERACAO_N=-9999</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","ERRO")
        lErIntRM := .T.
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","ERRO")
            lErIntRM := .T.
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                nSaldo  := Val(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:SALDOFISICO'))
                If !Empty(nSaldo)
                    DBSelectArea("SB2")
                    If SB2->(MSSeek(xFilial("SB2") + cCodProd + cLocEstoq))
                        If SB2->B2_QATU > nSaldo
                            RecLock("SB2",.F.)
                                SB2->B2_QATU := nSaldo
                                SB2->B2_DMOV := dDataBase
                                SB2->B2_HMOV := Time()
                            SB2->(MSUnlock())
                        EndIF 
                    Else
                        RecLock("SB2",.T.)
                            SB2->B2_FILIAL := xFilial("SB2")
                            SB2->B2_COD    := cCodProd
                            SB2->B2_LOCAL  := cLocEstoq
                            SB2->B2_QATU   := nSaldo
                            SB2->B2_DMOV   := dDataBase
                            SB2->B2_HMOV   := Time()
                        SB2->(MSUnlock())
                    EndIF
                EndIF
                u_fnGrvLog(cEndPoint,cBody,cResult,"","Armazem: "+cLocEstoq+", Produto: "+cCodProd,"1","CONSULTA")
            Endif

        EndIf
    EndIF 
    
Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsPontoVenda
Realiza a consulta de Ponto de Venda atraves da API padrao RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsPontoVenda()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRegXML   := {}
    Local nY

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+';PONTOVENDA_S=0;INATIVO_N=2;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SLG")

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF ! SA1->(MsSeek(xFilial("SA1")+aRegXML[2,3]))
                            RecLock("SLG",.T.)
                                SLG->LG_FILIAL  := xFilial("SLG")
                                SLG->LG_CODIGO  := StrZero(Val(aRegXML[02][03]), FWTamSX3("LG_CODIGO")[1])
                                SLG->LG_NOME    := aRegXML[03][03]
                                SLG->LG_NFCE    := .T.
                                SLG->LG_PDV     := aRegXML[06][03]
                                SLG->LG_SERPDV  := aRegXML[06][03]
                                SLG->LG_SERNFIS := '999'
                                SLG->LG_COO     := '999999'
                                SLG->LG_PORTIF  := 'COM1'
                                FwPutSX5(cFilAnt, "01", aRegXML[06][03], '000000001', /*cTextoEng*/, /*cTextoEsp*/, /*cTextoAlt*/)
                            SLG->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","Estacao: "+StrZero(aRegXML[02][03], FWTamSX3("LG_CODIGO")[1]),"3","Integracao Ponto de Venda")
                        EndIF 
                        
                    EndIF 
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsPrdCodBarras
Realiza a consulta do Codigo de Barras atraves da API padrao RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsPrdCodBarras()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRegXML   := {}
    Local nY

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>VINCULADO_S=SIM;CODCOLIGADA_N='+cCodEmp+';INATIVO_N=2;ULTIMONIVEL_N=1;TIPO_S=P;IDPRD_N=0;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SLK")
                SLK->(DBSetOrder(2))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF ! SLK->(MsSeek(xFilial("SLK") + Pad(aRegXML[05][03],FWTamSX3("LK_CODIGO")[1]) + aRegXML[03][03] ))
                            RecLock("SLK",.T.)
                                SLK->LK_FILIAL  := xFilial("SLK")
                                SLK->LK_CODBAR  := aRegXML[03][03]
                                SLK->LK_CODIGO  := aRegXML[05][03]
                                SLK->LK_QUANT   := 1
                            SLK->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","Codigo de Barras: "+aRegXML[05][03]+" - "+aRegXML[03][03],"3","Integracao Codigo de Barras")
                        Else
                            RecLock("SLK",.F.)
                                SLK->LK_CODBAR  := aRegXML[03][03]
                            SLK->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","Codigo de Barras: "+aRegXML[05][03]+" - "+aRegXML[03][03],"4","Integracao Codigo de Barras")
                        EndIF 
                        
                    EndIF  
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsFormaPagamento
Realiza a consulta da Forma de Pagamento atraves da API padrao RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsFormaPagamento()

    Local oWsdl as Object
    Local oXml as Object
    Local oMOdel as Object
    Local oSAEMod as Object
    Local cPath      := "/wsConsultaSQL/MEX?wsdl"
    Local cBody      := ""
    Local cResult    := ""
    Local aRegXML    := {}
    Local aAutoCab   := {}
    Local aAutoItens := {}
    Local cTipoAdm   := ""
    Local nParcAte   := 0
    Local nViraEm    := 0
    Local nY

    Private lLj070Auto := .T.
    Private aRotina := {}

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N=0;IDFORMAPAGTO_N=0;INATIVO_N=2;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFormaPagamento","2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFormaPagamento","2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFormaPagamento","2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SAE")
                SAE->(DBSetOrder(1))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')

                    oModel := FWLoadModel("LOJA070")

                    IF ! SAE->(MsSeek(xFilial("SAE") + aRegXML[03][03]))
                        nOpc := 3
                        oModel:SetOperation(nOpc)
                    Else
                        nOpc := 4
                        oModel:SetOperation(nOpc)
                    EndIF 
                    oModel:Activate()
                    
                    cTipoAdm := ""
                    nParcAte := 1
                    nViraEm  := 0

                    Do Case
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"Especie") .Or.  fContemStr(FwNoAccent(aRegXML[04][03]),"Desconto") ;
                             .Or. fContemStr(FwNoAccent(aRegXML[04][03]),"Bolsa") .Or. fContemStr(FwNoAccent(aRegXML[04][03]),"Devolucao")
                            cTipoAdm := "R$"
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"Cheque")
                            cTipoAdm := "CH"
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"Debito")
                            cTipoAdm := "CD"
                            nViraEm  := 1
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"Credito") .Or.  fContemStr(FwNoAccent(aRegXML[04][03]),"America")
                            cTipoAdm := "CC"
                            nViraEm  := 30
                            nParcAte := 12
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"PIX")
                            cTipoAdm := "PX"
                        Case fContemStr(FwNoAccent(aRegXML[04][03]),"Troca")
                            cTipoAdm := "CR"
                    End Case
                
                    oSAEMod:= oModel:getModel("SAEMASTER")
                    
                    aAutoCab := {}
                    aAutoItens := {}

                    IF nOpc == 3
                        aAdd(aAutoCab, {"AE_COD", aRegXML[03][03], Nil})                 // Codigo
                        aAdd(aAutoCab, {"AE_DESC"   , Alltrim(aRegXML[04][03]), Nil  })  // Descricao da Adm Financeira
                        aAdd(aAutoCab, {"AE_DIAS"   , nViraEm, Nil                   })  // Dia de a virar o cartao
                        aAdd(aAutoCab, {"AE_TAXA"   , Val(aRegXML[08][03]), Nil      })  // Taxa Cobranca
                        aAdd(aAutoCab, {"AE_TIPO"   , cTipoAdm, Nil                  })  // Tipo da Administradora
                        aAdd(aAutoCab, {"AE_FINPRO" , "N", Nil                       })  // Financiamento próprio
                        aAdd(aAutoCab, {"AE_PARCDE" , 1, Nil                         })  // Qtd. minima parcelas
                        aAdd(aAutoCab, {"AE_PARCATE", nParcAte, Nil                  })  // Qtd. máxima parcelas
                        aAdd(aAutoCab, {"AE_XTPFORM", Alltrim(aRegXML[06][03]), Nil  })  // Tipo da Forma de Pagamento
                        aAdd(aAutoCab, {"AE_XCODCX" , Alltrim(aRegXML[14][03]), Nil  })  // Codigo Caixa RM 
                        aAdd(aAutoCab, {"AE_XIDFORM", Alltrim(aRegXML[02][03]), Nil  })  // ID da Forma de Pag. RM

                        IF FWMVCRotAuto(oModel, "SAE", nOpc , {{"SAEMASTER", aAutoCab}, {"MENDETAIL", aAutoItens}},,.T.)
                            lOk := .T.
                        Else
                            lOk := .F.
                        EndIF
                    ElseIF nOpc == 4
                        RecLock("SAE",.F.)
                            SAE->AE_DESC    := Alltrim(aRegXML[04][03])  // Descricao da Adm Financeira
                            SAE->AE_DIAS    := nViraEm                   // Dia de a virar o cartao
                            SAE->AE_TAXA    := Val(aRegXML[08][03])      // Taxa Cobranca
                            SAE->AE_TIPO    := cTipoAdm                  // Tipo da Administradora
                            SAE->AE_FINPRO  := "N"                       // Financiamento próprio
                            SAE->AE_PARCDE  := 1                         // Qtd. minima parcelas
                            SAE->AE_PARCATE := nParcAte                  // Qtd. máxima parcelas
                            SAE->AE_XTPFORM := Alltrim(aRegXML[06][03])  // Tipo da Forma de Pagamento
                            SAE->AE_XCODCX  := Alltrim(aRegXML[14][03])  // Codigo Caixa RM 
                            SAE->AE_XIDFORM := Alltrim(aRegXML[02][03])  // ID da Forma de Pag. RM
                        SAE->(MsUnlock())
                        lOk := .T.
                    EndIF

                    If ! lOk
                        aErro := oModel:GetErrorMessage()
                        AutoGrLog("Id do formulario de origem:"  + ' [' + AllToChar(aErro[01]) + ']')
                        AutoGrLog("Id do campo de origem: "      + ' [' + AllToChar(aErro[02]) + ']')
                        AutoGrLog("Id do formulario de erro: "   + ' [' + AllToChar(aErro[03]) + ']')
                        AutoGrLog("Id do campo de erro: "        + ' [' + AllToChar(aErro[04]) + ']')
                        AutoGrLog("Id do erro: "                 + ' [' + AllToChar(aErro[05]) + ']')
                        AutoGrLog("Mensagem do erro: "           + ' [' + AllToChar(aErro[06]) + ']')
                        AutoGrLog("Mensagem da solucao: "        + ' [' + AllToChar(aErro[07]) + ']')
                        AutoGrLog("Valor atribuido: "            + ' [' + AllToChar(aErro[08]) + ']')
                        AutoGrLog("Valor anterior: "             + ' [' + AllToChar(aErro[09]) + ']')
                        
                        cErro := aErro[06]
                        u_fnGrvLog(cEndPoint,cBody,cResult,cErro,"Erro Adm Financeira: " + aRegXML[03][03] + " - " +aRegXML[09][03],cValToChar(nOpc),IIF(nOpc == 3, "INCLUSAO", "ALTERACAO"))
                    Else
                        u_fnGrvLog(cEndPoint,cBody,cResult,,"Adm Financeira: " + aRegXML[03][03] + " - " +aRegXML[04][03],cValToChar(nOpc),IIF(nOpc == 3, "INCLUSAO", "ALTERACAO"))
                    EndIf
                    oModel:DeActivate()  
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsPrdFilCCusto
Realiza a consulta da amarração de Produto x Centro de Custo atraves da API padrao 
RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsPrdFilCCusto()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRegXML   := {}
    Local nY

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>'+cEndPoint+'</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+';IDPRD_N=0;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsPrdFilCCusto","2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsPrdFilCCusto","2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsPrdFilCCusto","2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SZ2")
                SZ2->(DBSetOrder(1))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF ! SZ2->(MsSeek(xFilial("SZ2") + Pad(aRegXML[05][03],FWTamSX3("Z2_PRODUTO")[1]) ))
                            RecLock("SZ2",.T.)
                                SZ2->Z2_FILIAL  := xFilial("SZ2")
                                SZ2->Z2_PRODUTO := aRegXML[05][03]
                                SZ2->Z2_DESCRIC := aRegXML[06][03]
                                SZ2->Z2_CCUSTO  := aRegXML[03][03]
                                SZ2->Z2_DESCCC  := aRegXML[07][03]
                            SZ2->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsPrdFilCCusto: "+aRegXML[05][03]+" - "+aRegXML[03][03],"3","INCLUSAO")
                        Else
                            RecLock("SZ2",.F.)
                                SZ2->Z2_CCUSTO  := aRegXML[03][03]
                                SZ2->Z2_DESCCC  := aRegXML[07][03]
                            SZ2->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsPrdFilCCusto: "+aRegXML[05][03]+" - "+aRegXML[03][03],"4","ALTERACAO")
                        EndIF 
                        
                    EndIF  
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsNatClFiscal
Realiza a consulta da amarração de Classificação Fiscal x Natureza atraves da API padrao 
RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsNatClFiscal()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRegXML   := {}
    Local nY

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += ' 	<soapenv:Header/> '
    cBody += ' 	<soapenv:Body> '
    cBody += ' 		<tot:RealizarConsultaSQL> '
    cBody += ' 			<tot:codSentenca>wsNatClFiscal</tot:codSentenca> '
    cBody += ' 			<tot:codColigada>0</tot:codColigada> '
    cBody += ' 			<tot:codSistema>T</tot:codSistema> '
    cBody += ' 			<tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+'</tot:parameters> '
    cBody += ' 		</tot:RealizarConsultaSQL> '
    cBody += ' 	</soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsNatClFiscal","2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsNatClFiscal","2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsNatClFiscal","2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SZ3")
                SZ3->(DBSetOrder(1))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF ! SZ3->(MsSeek(xFilial("SZ3") + Pad(aRegXML[04][03],FWTamSX3("Z3_CLASFIS")[1]) ))
                            RecLock("SZ3",.T.)
                                SZ3->Z3_FILIAL  := xFilial("SZ3")
                                SZ3->Z3_CODNATU := aRegXML[07][03]
                                SZ3->Z3_CLASFIS := aRegXML[04][03]
                                SZ3->Z3_DESCFIS := aRegXML[05][03]
                                SZ3->Z3_IDSINVE := aRegXML[06][03]
                                SZ3->Z3_DESSINV := aRegXML[08][03]
                                SZ3->Z3_IDANAVE := aRegXML[09][03]
                                SZ3->Z3_DESANAV := aRegXML[10][03]
                                SZ3->Z3_IDSINDE := aRegXML[11][03]
                                SZ3->Z3_DESSIND := aRegXML[12][03]
                                SZ3->Z3_IDANADE := aRegXML[13][03]
                                SZ3->Z3_DESANAD := aRegXML[14][03]
                            SZ3->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsNatClFiscal: "+aRegXML[03][03]+" - "+aRegXML[04][03],"3","INCLUSAO")
                        Else
                            RecLock("SZ3",.F.)
                                SZ3->Z3_CODNATU := aRegXML[07][03]
                                SZ3->Z3_DESCFIS := aRegXML[05][03]
                                SZ3->Z3_IDSINVE := aRegXML[06][03]
                                SZ3->Z3_DESSINV := aRegXML[08][03]
                                SZ3->Z3_IDANAVE := aRegXML[09][03]
                                SZ3->Z3_DESANAV := aRegXML[10][03]
                                SZ3->Z3_IDSINDE := aRegXML[11][03]
                                SZ3->Z3_DESSIND := aRegXML[12][03]
                                SZ3->Z3_IDANADE := aRegXML[13][03]
                                SZ3->Z3_DESANAD := aRegXML[14][03]
                            SZ3->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsNatClFiscal: "+aRegXML[03][03]+" - "+aRegXML[04][03],"4","ALTERACAO")
                        EndIF 
                        
                    EndIF  
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsFpagtoCaixa
Realiza a consulta da amarração de Forma de Pagamento x Cod. Caixa atraves da API padrao 
RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsFpagtoCaixa()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRegXML   := {}
    Local nY

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += ' 	<soapenv:Header/> '
    cBody += ' 	<soapenv:Body> '
    cBody += ' 		<tot:RealizarConsultaSQL> '
    cBody += ' 			<tot:codSentenca>wsFpagtoCaixa</tot:codSentenca> '
    cBody += ' 			<tot:codColigada>0</tot:codColigada> '
    cBody += ' 			<tot:codSistema>T</tot:codSistema> '
    cBody += ' 			<tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+'</tot:parameters> '
    cBody += ' 		</tot:RealizarConsultaSQL> '
    cBody += ' 	</soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFpagtoCaixa","2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFpagtoCaixa","2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de wsFpagtoCaixa","2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SZ4")
                SZ4->(DBSetOrder(1))

                If lMsg
                    ProcRegua(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet'))
                EndIF

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If lMsg
                        IncProc("Registro " + cValToChar(nY) + " de " + cValToChar(oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')) + "...")
                    EndIF

                    If !Empty(aRegXML)

                        IF ! SZ4->(MsSeek(xFilial("SZ4") + Pad(aRegXML[03][03],FWTamSX3("Z4_CODFORM")[1]) ))
                            RecLock("SZ4",.T.)
                                SZ4->Z4_FILIAL  := xFilial("SZ4")
                                SZ4->Z4_CODFORM := aRegXML[03][03]
                                SZ4->Z4_DESCFOR := aRegXML[04][03]
                                SZ4->Z4_IDFORMA := aRegXML[02][03]
                                SZ4->Z4_CODCOL  := aRegXML[07][03]
                                SZ4->Z4_CODCXA  := aRegXML[08][03]
                                SZ4->Z4_NOMECX  := aRegXML[09][03]
                            SZ4->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsFpagtoCaixa: "+aRegXML[03][03]+" - "+aRegXML[04][03],"3","INCLUSAO")
                        Else
                            RecLock("SZ4",.F.)
                                SZ4->Z4_DESCFOR := aRegXML[04][03]
                                SZ4->Z4_IDFORMA := aRegXML[02][03]
                                SZ4->Z4_CODCOL  := aRegXML[07][03]
                                SZ4->Z4_CODCXA  := aRegXML[08][03]
                                SZ4->Z4_NOMECX  := aRegXML[09][03]
                            SZ4->(MSUnlock())

                            u_fnGrvLog(cEndPoint,cBody,cResult,"","wsFpagtoCaixa: "+aRegXML[03][03]+" - "+aRegXML[04][03],"4","ALTERACAO")
                        EndIF 
                        
                    EndIF  
                Next 
                
            Endif

            FreeObj(oXML)
            oXML := Nil
        EndIf
    EndIF 
    
    FreeObj(oWsdl)
    oWsdl := Nil

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvNFeVend
Realiza o envio da Nota Fiscal de Saida para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvNFeVend()

    Local aArea    := FWGetArea()
    Local aAreaSL1 := SL1->(FWGetArea())
    Local aAreaSL2 := SL2->(FWGetArea())
    Local aAreaSL4 := SL4->(FWGetArea())
    Local aAreaSAE := SAE->(FWGetArea())
    Local aAreaSB1 := SB1->(FWGetArea())
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsDataServer/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cLocEstoq := SuperGetMV("MV_LOCPAD")
    Local cIDMovRet := ""
    Local cCodAdm   := ""
    Local cIDNat    := ""
    Local cCodColCX := ""
    Local cCodCaixa := ""
    Local cTitulo   := "Erro de Integração de Venda, Orçamento: " + SL1->L1_NUM + ", NFC-e: " + AllTrim(SL1->L1_DOC) + ", Série: " + AllTrim(SL1->L1_SERIE) + " com o TOTVS Corpore RM"

    DBSelectArea("SL2")
    IF !SL2->(MsSeek(SL1->L1_FILIAL + SL1->L1_NUM ))
        Return
    EndIF 

    DBSelectArea("SZ3")
    SZ3->(MsSeek(xFilial("SZ3") + Posicione("SB1",1,xFilial("SB1")+SL2->L2_PRODUTO,"B1_XCLAFIS")))
    cIDNat := AllTrim(SZ3->Z3_IDSINVE)

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:SaveRecord> '
    cBody += '          <tot:DataServerName>MovMovimentoTBCData</tot:DataServerName> '
    cBody += '          <tot:XML> '
    cBody += '                    <![CDATA[ '
    cBody += '                          <MovMovimento> '
    cBody += '                              <TMOV> '
    cBody += '                                  <CODCOLIGADA>'+ cCodEmp +'</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
    cBody += '                                  <CODLOC>' + cLocEstoq + '</CODLOC> ' //Codigo do Local de Destino
    cBody += '                                  <CODCFO>' + SL1->L1_CLIENTE + '</CODCFO> ' //Codigo do Cliente / Fornecedor
    cBody += '                                  <NUMEROMOV>' + Alltrim(SL1->L1_DOC) + '</NUMEROMOV> '
    cBody += '                                  <SERIE>' + Alltrim(SL1->L1_SERIE) + '</SERIE> '
    cBody += '                                  <CODTMV>2.2.25</CODTMV> '
    cBody += '                                  <TIPO>P</TIPO> '
    cBody += '                                  <STATUS>Q</STATUS> '
    cBody += '                                  <MOVIMPRESSO>0</MOVIMPRESSO> '
    cBody += '                                  <DOCIMPRESSO>0</DOCIMPRESSO> '
    cBody += '                                  <FATIMPRESSA>0</FATIMPRESSA> '
    cBody += '                                  <DATAEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATAEMISSAO> '
    cBody += '                                  <DATASAIDA>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATASAIDA> '
    cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
    cBody += '                                  <VALORBRUTO>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORLIQUIDO> '
    cBody += '                                  <VALOROUTROS>0,0000</VALOROUTROS> '
    cBody += '                                  <PERCENTUALFRETE>0,0000</PERCENTUALFRETE> '
    cBody += '                                  <VALORFRETE>'+ Alltrim(AlltoChar(SL1->L1_FRETE, cPicVal)) +'</VALORFRETE> '
    cBody += '                                  <PERCENTUALDESC>'+ Alltrim(AlltoChar(SL1->L1_DESCNF, cPicVal)) +'</PERCENTUALDESC> '
    cBody += '                                  <VALORDESC>'+ Alltrim(AlltoChar(SL1->L1_DESCONT, cPicVal)) +'</VALORDESC> '
    cBody += '                                  <PERCENTUALDESP>0,0000</PERCENTUALDESP> '
    cBody += '                                  <VALORDESP>'+ Alltrim(AlltoChar(SL1->L1_DESPESA, cPicVal)) +'</VALORDESP> '
    cBody += '                                  <PERCCOMISSAO>'+ Alltrim(AlltoChar(SL1->L1_COMIS, cPicVal)) +'</PERCCOMISSAO> '
    cBody += '                                  <PESOLIQUIDO>0,0000</PESOLIQUIDO> '
    cBody += '                                  <PESOBRUTO>0,0000</PESOBRUTO> '
    cBody += '                                  <CODTB1FLX/> '
    cBody += '                                  <CODTB4FLX/> '
    cBody += '                                  <IDMOVLCTFLUXUS>-1</IDMOVLCTFLUXUS> '
    cBody += '                                  <CODMOEVALORLIQUIDO>R$</CODMOEVALORLIQUIDO> '
    cBody += '                                  <DATAMOVIMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATAMOVIMENTO> '
    cBody += '                                  <NUMEROLCTGERADO>1</NUMEROLCTGERADO> '
    cBody += '                                  <GEROUFATURA>0</GEROUFATURA> '
    cBody += '                                  <NUMEROLCTABERTO>1</NUMEROLCTABERTO> '
    cBody += '                                  <FRETECIFOUFOB>9</FRETECIFOUFOB> '
    cBody += '                                  <CODCFOAUX>CXXXXXXXXXX</CODCFOAUX> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Nao tera Centro de Custo no cabecalho
    cBody += '                                  <PERCCOMISSAOVEN2>0,0000</PERCCOMISSAOVEN2> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += '                                  <CODFILIALDESTINO>' + cCodFil + '</CODFILIALDESTINO> '
    cBody += '                                  <GERADOPORLOTE>0</GERADOPORLOTE> '
    cBody += '                                  <CODEVENTO>12</CODEVENTO> '
    cBody += '                                  <STATUSEXPORTCONT>1</STATUSEXPORTCONT> '
    //cBody += '                                  <CODLOTE>41213</CODLOTE> '
    //cBody += '                                  <IDNAT>19</IDNAT> ' //Verificar esse ID NAT 
    cBody += '                                  <IDNAT>' + cIDNat + '</IDNAT> ' //Verificar esse ID NAT 
    cBody += '                                  <GEROUCONTATRABALHO>0</GEROUCONTATRABALHO> '
    cBody += '                                  <GERADOPORCONTATRABALHO>0</GERADOPORCONTATRABALHO> '
    cBody += '                                  <HORULTIMAALTERACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</HORULTIMAALTERACAO> '
    cBody += '                                  <INDUSOOBJ>0.00</INDUSOOBJ> '
    cBody += '                                  <INTEGRADOBONUM>0</INTEGRADOBONUM> '
    cBody += '                                  <FLAGPROCESSADO>0</FLAGPROCESSADO> '
    cBody += '                                  <ABATIMENTOICMS>0,0000</ABATIMENTOICMS> '
    cBody += '                                  <HORARIOEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</HORARIOEMISSAO> '
    cBody += '                                  <USUARIOCRIACAO>' + cUser + '</USUARIOCRIACAO> '
    cBody += '                                  <DATACRIACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</DATACRIACAO> '
    cBody += '                                  <STSEMAIL>0</STSEMAIL> '
    cBody += '                                  <VALORBRUTOINTERNO>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTOINTERNO> '
    cBody += '                                  <VINCULADOESTOQUEFL>0</VINCULADOESTOQUEFL> '
    cBody += '                                  <HORASAIDA>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</HORASAIDA> '
    cBody += '                                  <VRBASEINSSOUTRAEMPRESA>0,0000</VRBASEINSSOUTRAEMPRESA> '
    cBody += '                                  <CODTDO>65</CODTDO> '
    cBody += '                                  <VALORDESCCONDICIONAL>0,0000</VALORDESCCONDICIONAL> '
    cBody += '                                  <VALORDESPCONDICIONAL>0,0000</VALORDESPCONDICIONAL> '
    cBody += '                                  <DATACONTABILIZACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</DATACONTABILIZACAO> '
    cBody += '                                  <INTEGRADOAUTOMACAO>0</INTEGRADOAUTOMACAO> '
    cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
    cBody += '                                  <DATALANCAMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</DATALANCAMENTO> '
    cBody += '                                  <RECIBONFESTATUS>0</RECIBONFESTATUS> '
    cBody += '                                  <VALORMERCADORIAS>' + Alltrim(AlltoChar(SL1->L1_VALMERC, cPicVal)) + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>1</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORRATEIOLAN> '
    cBody += '                                  <CHAVEACESSONFE>'+ Alltrim(SL1->L1_KEYNFCE) +'</CHAVEACESSONFE> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORLIQUIDOORIG> '
    cBody += '                                  <VALOROUTROSORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALOROUTROSORIG> '
    cBody += '                                  <VALORRATEIOLANORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORRATEIOLANORIG> '
    cBody += '                                  <FLAGCONCLUSAO>0</FLAGCONCLUSAO> '
    cBody += '                                  <STATUSPARADIGMA>N</STATUSPARADIGMA> '
    cBody += '                                  <STATUSINTEGRACAO>N</STATUSINTEGRACAO> '
    cBody += '                                  <PERCCOMISSAOVEN3>0.0000</PERCCOMISSAOVEN3> '
    cBody += '                                  <PERCCOMISSAOVEN4>0.0000</PERCCOMISSAOVEN4> '
    cBody += '                                  <STATUSMOVINCLUSAOCOLAB>0</STATUSMOVINCLUSAOCOLAB> '
    cBody += '                              </TMOV> '
    cBody += '                              <TNFE> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                              </TNFE> '
    cBody += '                              <TMOVFISCAL> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CONTRIBUINTECREDENCIADO>0</CONTRIBUINTECREDENCIADO> '
    cBody += '                                  <OPERACAOCONSUMIDORFINAL>1</OPERACAOCONSUMIDORFINAL> '
    cBody += '                                  <DATAINICIOCREDITO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) + '</DATAINICIOCREDITO> '
    cBody += '                                  <OPERACAOPRESENCIAL>0</OPERACAOPRESENCIAL> '
    cBody += '                                  <NROSAT>'+Alltrim(SL1->L1_SERSAT)+'</NROSAT> '
    cBody += '                              </TMOVFISCAL> '
    cBody += '                              <TMOVRATCCU> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> '
    cBody += '                                  <NOME>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_DESCCC")) + '</NOME> '
    cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALOR> '
    cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
    cBody += '                              </TMOVRATCCU> '
    cBody += '                              <TMOVHISTORICO> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <HISTORICOLONGO>Integracao Webservice TOTVS Protheus</HISTORICOLONGO> '
    cBody += '                                  <HISTORICOCURTO>Integracao Webservice TOTVS Protheus</HISTORICOCURTO> '
    cBody += '                              </TMOVHISTORICO> '
    //Formas de Pagamento do Cupom Fiscal
    DBSelectArea("SL4")
    DBSelectArea("SAE")

    //Credito de Devolução 
    IF !Empty(SL1->L1_CREDITO)
        
        SAE->(MSSeek(xFilial("SAE") + '21' ))

        DBSelectArea("SZ4")
        SZ4->(MsSeek(xFilial("SZ4") + SAE->AE_COD ))
        cCodCaixa := SZ4->Z4_CODCXA
        cCodColCX := SZ4->Z4_CODCOL

        cBody += '                              <TMOVPAGTO> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <CODCOLCFODEFAULT>0</CODCOLCFODEFAULT> '
        cBody += '                                  <CODCFODEFAULT>023133</CODCFODEFAULT> '
        cBody += '                                  <TIPOFORMAPAGTO>'+ Alltrim(SAE->AE_XTPFORM) +'</TIPOFORMAPAGTO> '
        cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
        cBody += '                                  <TAXAADM>'+ Alltrim(AlltoChar(SAE->AE_TAXA, cPicVal)) +'</TAXAADM> '
        cBody += '                                  <CODCXA>'+ Alltrim(cCodCaixa) +'</CODCXA> '
        cBody += '                                  <CODCOLCXA>' + Alltrim(cCodColCX) + '</CODCOLCXA> '
        cBody += '                                  <IDLAN>-1</IDLAN> '
        cBody += '                                  <NOMEREDE/> '
        cBody += '                                  <NSU/> '
        cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
        cBody += '                                  <IDFORMAPAGTO>'+ Alltrim(SAE->AE_XIDFORM) +'</IDFORMAPAGTO> '
        cBody += '                                  <DATAVENCIMENTO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAVENCIMENTO> '
        cBody += '                                  <TIPOPAGAMENTO>1</TIPOPAGAMENTO> '
        cBody += '                                  <VALOR>'+ Alltrim(AlltoChar(SL1->L1_CREDITO, cPicVal)) +'</VALOR> '
        cBody += '                                  <DEBITOCREDITO>C</DEBITOCREDITO> '
        cBody += '                              </TMOVPAGTO> '
    EndIF 
    
    //Formas de Pagamento na SL4 
    IF SL4->(MSSeek(SL1->L1_FILIAL + SL1->L1_NUM))
        While SL4->(!Eof()) .AND. ( SL4->L4_FILIAL  == SL1->L1_FILIAL );
                            .AND. ( SL4->L4_NUM     == SL1->L1_NUM )
            
            cCodAdm := SubStr(Alltrim(SL4->L4_ADMINIS),1,3)
            If Empty(cCodAdm)
                Do Case
                    Case Alltrim(SL4->L4_FORMA) == "R$"
                        cCodAdm := "01"
                    Case Alltrim(SL4->L4_FORMA) == "CH"
                        cCodAdm := "02"
                End Do 
            EndIF 

            SAE->(MSSeek(xFilial("SAE") + cCodAdm ))

            DBSelectArea("SZ4")
            SZ4->(MsSeek(xFilial("SZ4") + SAE->AE_COD ))
            cCodCaixa := SZ4->Z4_CODCXA
            cCodColCX := SZ4->Z4_CODCOL

            cBody += '                              <TMOVPAGTO> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <CODCOLCFODEFAULT>0</CODCOLCFODEFAULT> '
            cBody += '                                  <CODCFODEFAULT>023133</CODCFODEFAULT> '
            cBody += '                                  <TIPOFORMAPAGTO>'+ Alltrim(SAE->AE_XTPFORM) +'</TIPOFORMAPAGTO> '
            cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
            cBody += '                                  <TAXAADM>'+ Alltrim(AlltoChar(SAE->AE_TAXA, cPicVal)) +'</TAXAADM> '
            cBody += '                                  <CODCXA>'+ Alltrim(cCodCaixa) +'</CODCXA> '
            cBody += '                                  <CODCOLCXA>' + Alltrim(cCodColCX) + '</CODCOLCXA> '
            cBody += '                                  <IDLAN>-1</IDLAN> '
            cBody += '                                  <NOMEREDE/> '
            cBody += '                                  <NSU>'+ AllTrim(SL4->L4_NSUTEF) +'</NSU> '
            cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
            cBody += '                                  <IDFORMAPAGTO>'+ Alltrim(SAE->AE_XIDFORM) +'</IDFORMAPAGTO> '
            cBody += '                                  <DATAVENCIMENTO>'+ ( FWTimeStamp(3, SL4->L4_DATA , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAVENCIMENTO> '
            cBody += '                                  <TIPOPAGAMENTO>1</TIPOPAGAMENTO> '
            cBody += '                                  <VALOR>'+ Alltrim(AlltoChar(SL4->L4_VALOR, cPicVal)) +'</VALOR> '
            cBody += '                                  <DEBITOCREDITO>C</DEBITOCREDITO> '
            cBody += '                              </TMOVPAGTO> '
        SL4->(DBSkip())
        End
    EndIF 
    //Itens do Cupom Fiscal
    While !SL2->(Eof()) .AND. ( SL2->L2_FILIAL  == SL1->L1_FILIAL ); 
                        .AND. ( SL2->L2_NUM     == SL1->L1_NUM )

        DBSelectArea("SZ3")
        SZ3->(MsSeek(xFilial("SZ3") + Posicione("SB1",1,xFilial("SB1")+SL2->L2_PRODUTO,"B1_XCLAFIS")))
        cIDNat := AllTrim(SZ3->Z3_IDANAVE)

        cBody += '                              <TITMMOV> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV>  '
        cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +  '</NSEQITMMOV> '
        cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
        cBody += '                                  <NUMEROSEQUENCIAL>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +  '</NUMEROSEQUENCIAL> '
        cBody += '                                  <IDPRD>' + Alltrim(Posicione('SB1',1,xFilial('SB1')+SL2->L2_PRODUTO,"B1_XIDRM")) + '</IDPRD> '
        cBody += '                                  <NUMNOFABRIC/> '
        cBody += '                                  <QUANTIDADE>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADE> '
        cBody += '                                  <PRECOUNITARIO>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</PRECOUNITARIO> '
        cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
        cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
        cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
        cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAEMISSAO> '
        cBody += '                                  <CODUND>' + Alltrim(SL2->L2_UM) + '</CODUND> '
        cBody += '                                  <QUANTIDADEARECEBER>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADEARECEBER> '
        cBody += '                                  <FLAGEFEITOSALDO>1</FLAGEFEITOSALDO> '
        cBody += '                                  <VALORUNITARIO>' + Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) + '</VALORUNITARIO> '
        cBody += '                                  <VALORFINANCEIRO>' + Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) + '</VALORFINANCEIRO> '
        cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> '
        cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
        cBody += '                                  <QUANTIDADEORIGINAL>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADEORIGINAL> '
        //cBody += '                                  <IDNAT>430</IDNAT> ' //Verificar esse ID NAT 
        cBody += '                                  <IDNAT>' + cIDNat + '</IDNAT> ' //Verificar esse ID NAT 
        cBody += '                                  <FLAG>0</FLAG> '
        cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
        cBody += '                                  <VALORBRUTOITEM>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORBRUTOITEM> '
        cBody += '                                  <VALORTOTALITEM>'+ Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) +'</VALORTOTALITEM> '
        cBody += '                                  <QUANTIDADESEPARADA>0,0000</QUANTIDADESEPARADA> '
        cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
        cBody += '                                  <VALORESCRITURACAO>0,0000</VALORESCRITURACAO> '
        cBody += '                                  <VALORFINPEDIDO>0,0000</VALORFINPEDIDO> '
        cBody += '                                  <VALOROPFRM1>0,0000</VALOROPFRM1> '
        cBody += '                                  <VALOROPFRM2>0,0000</VALOROPFRM2> '
        cBody += '                                  <PRECOEDITADO>0</PRECOEDITADO> '
        cBody += '                                  <QTDEVOLUMEUNITARIO>1</QTDEVOLUMEUNITARIO> '
        cBody += '                                  <CST>000</CST> '
        cBody += '                                  <VALORDESCCONDICONALITM>0,0000</VALORDESCCONDICONALITM> '
        cBody += '                                  <VALORDESPCONDICIONALITM>0,0000</VALORDESPCONDICIONALITM> '
        cBody += '                                  <CODTBORCAMENTO/> '
        cBody += '                                  <CODCOLTBORCAMENTO/> '
        cBody += '                                  <RATEIOFRETE>0,0000</RATEIOFRETE> '
        cBody += '                                  <RATEIODESC>0,0000</RATEIODESC> '
        cBody += '                                  <RATEIODESP>0,0000</RATEIODESP> '
        cBody += '                                  <VALORUNTORCAMENTO>0,0000</VALORUNTORCAMENTO> '
        cBody += '                                  <VALSERVICONFE>0,0000</VALSERVICONFE> '
        cBody += '                                  <CODLOC>' + Alltrim(SL2->L2_LOCAL) + '</CODLOC> '
        cBody += '                                  <VALORBEM>0,0000</VALORBEM> '
        cBody += '                                  <VALORLIQUIDO>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORLIQUIDO> '
        cBody += '                                  <RATEIOCCUSTODEPTO/> '
        cBody += '                                  <VALORBRUTOITEMORIG>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORBRUTOITEMORIG> '
        cBody += '                                  <CODNATUREZAITEM/> '
        cBody += '                                  <QUANTIDADETOTAL>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADETOTAL> '
        cBody += '                                  <PRODUTOSUBSTITUTO>0</PRODUTOSUBSTITUTO> '
        cBody += '                                  <PRECOUNITARIOSELEC>0</PRECOUNITARIOSELEC> '
        cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
        cBody += '                                  <VALORBASEDEPRECIACAOBEM>0,0000</VALORBASEDEPRECIACAOBEM> '
        cBody += '                                  <IDMOVSOLICITACAOMNT>0</IDMOVSOLICITACAOMNT> ' 
        cBody += '                              </TITMMOV> '
        cBody += '                              <TITMMOVHISTORICO> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) + '</NSEQITMMOV> '
        cBody += '                                  <HISTORICOLONGO>Integracao Webservice TOTVS Protheus</HISTORICOLONGO> '
        cBody += '                                  <HISTORICOCURTO>Integracao Webservice TOTVS Protheus</HISTORICOCURTO> '
        cBody += '                              </TITMMOVHISTORICO> '
        cBody += '                              <TITMMOVCOMPL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                              </TITMMOVCOMPL> '
        cBody += '                              <TITMMOVRATCCU> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) + '</NSEQITMMOV> '
        cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Rateio de Centro de Custo do Item Nao tera
        cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALOR> '
        cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
        cBody += '                              </TITMMOVRATCCU> '        
        cBody += '                              <TTRBITMMOV> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                                  <CODTRB>ICMS</CODTRB> '
        cBody += '                                  <BASEDECALCULO>' + Alltrim(AlltoChar(SL2->L2_BASEICM, cPicVal)) + '</BASEDECALCULO> '
        cBody += '                                  <ALIQUOTA>' + Alltrim(AlltoChar(SL2->L2_SITTRIB, cPicVal)) + '</ALIQUOTA> '
        cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL2->L2_VALICM, cPicVal)) + '</VALOR> '
        cBody += '                                  <FATORREDUCAO>0,0000</FATORREDUCAO> '
        cBody += '                                  <FATORSUBSTTRIB>0,0000</FATORSUBSTTRIB> '
        cBody += '                                  <BASEDECALCULOCALCULADA>' + Alltrim(AlltoChar(SL2->L2_BASEICM, cPicVal)) + '</BASEDECALCULOCALCULADA> '
        cBody += '                                  <EDITADO>0</EDITADO> '
        cBody += '                                  <TIPORECOLHIMENTO>1</TIPORECOLHIMENTO> '
        cBody += '                                  <PERCDIFERIMENTOPARCIALICMS>0,0000</PERCDIFERIMENTOPARCIALICMS> '
        cBody += '                                  <BASECHEIA>0,0000</BASECHEIA> '
        cBody += '                              </TTRBITMMOV> '
        cBody += '                              <TTRBITMMOV> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                                  <CODTRB>PIS</CODTRB> '
        cBody += '                                  <BASEDECALCULO>' + Alltrim(AlltoChar(SL2->L2_BASEPIS, cPicVal)) + '</BASEDECALCULO> '
        cBody += '                                  <ALIQUOTA>' + Alltrim(AlltoChar(SL2->L2_ALIQPIS, cPicVal)) + '</ALIQUOTA> '
        cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL2->L2_VALPIS, cPicVal)) + '</VALOR> '
        cBody += '                                  <FATORREDUCAO>0,0000</FATORREDUCAO> '
        cBody += '                                  <FATORSUBSTTRIB>0,0000</FATORSUBSTTRIB> '
        cBody += '                                  <BASEDECALCULOCALCULADA>' + Alltrim(AlltoChar(SL2->L2_BASEPIS, cPicVal)) + '</BASEDECALCULOCALCULADA> '
        cBody += '                                  <EDITADO>0</EDITADO> '
        cBody += '                                  <TIPORECOLHIMENTO>1</TIPORECOLHIMENTO> '
        cBody += '                                  <CODTRBBASE>PIS</CODTRBBASE> '
        cBody += '                                  <PERCDIFERIMENTOPARCIALICMS>0,0000</PERCDIFERIMENTOPARCIALICMS> '
        cBody += '                                  <BASECHEIA>0,0000</BASECHEIA> '
        cBody += '                              </TTRBITMMOV> '
        cBody += '                              <TTRBITMMOV> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                                  <CODTRB>COFINS</CODTRB> '
        cBody += '                                  <BASEDECALCULO>' + Alltrim(AlltoChar(SL2->L2_BASECOF, cPicVal)) + '</BASEDECALCULO> '
        cBody += '                                  <ALIQUOTA>' + Alltrim(AlltoChar(SL2->L2_ALIQCOF, cPicVal)) + '</ALIQUOTA> '
        cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL2->L2_VALCOFI, cPicVal)) + '</VALOR> '
        cBody += '                                  <FATORREDUCAO>0,0000</FATORREDUCAO> '
        cBody += '                                  <FATORSUBSTTRIB>0,0000</FATORSUBSTTRIB> '
        cBody += '                                  <BASEDECALCULOCALCULADA>' + Alltrim(AlltoChar(SL2->L2_BASECOF, cPicVal)) + '</BASEDECALCULOCALCULADA> '
        cBody += '                                  <EDITADO>0</EDITADO> '
        cBody += '                                  <TIPORECOLHIMENTO>1</TIPORECOLHIMENTO> '
        cBody += '                                  <CODTRBBASE>COFINS</CODTRBBASE> '
        cBody += '                                  <PERCDIFERIMENTOPARCIALICMS>0,0000</PERCDIFERIMENTOPARCIALICMS> '
        cBody += '                                  <BASECHEIA>0,0000</BASECHEIA> '
        cBody += '                              </TTRBITMMOV> '
        cBody += '                              <TITMMOVFISCAL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                                  <VLRTOTTRIB/> '
        cBody += '                                  <VALORIBPTFEDERAL>'+ Alltrim(AlltoChar(SL2->L2_TOTFED, cPicVal)) +'</VALORIBPTFEDERAL> '
        cBody += '                                  <VALORIBPTESTADUAL>'+ Alltrim(AlltoChar(SL2->L2_TOTEST, cPicVal)) +'</VALORIBPTESTADUAL> '
        cBody += '                                  <VALORIBPTMUNICIPAL>'+ Alltrim(AlltoChar(SL2->L2_TOTMUN, cPicVal)) +'</VALORIBPTMUNICIPAL> '
        cBody += '                                  <AQUISICAOPAA>0</AQUISICAOPAA> '
        cBody += '                              </TITMMOVFISCAL> '
    SL2->(DBSkip())
    EndDo 
    cBody += '                              <TMOVTRANSP> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <LOTACAO>1</LOTACAO> '
    cBody += '                              </TMOVTRANSP> '
    cBody += '                          </MovMovimento>]]> '
    cBody += '          </tot:XML> '
    cBody += '          <tot:Contexto>CODCOLIGADA=' + cCodEmp + ';CODSISTEMA=T</tot:Contexto> '
    cBody += '     </tot:SaveRecord> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("SaveRecord")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"SL1 - "+SL1->L1_NUM,"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"SL1 - "+SL1->L1_NUM,"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",oXML:Error(),"SL1 - "+SL1->L1_NUM,"2","ERRO")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                IF Len(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')) < 15 
                    cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                         At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')
                EndIF
                
                If !Empty(cIDMovRet) .And. Len(cIDMovRet) < 10
                    RecLock("SL1",.F.)
                        SL1->L1_XIDMOV  := cIDMovRet
                        SL1->L1_XINT_RM := "S"
                    SL1->(MSUnlock())
                    u_fBaixaFin(cIDMovRet)
                    u_fnGrvLog(cEndPoint,cBody,cResult,"","SL1 - "+SL1->L1_NUM,"6","ENVIO")
                Else

                    cIDMovRet := wsNumeroMOV() //Realiza consulta do Movimento atraves do Numero,Serie e Cliente do NFC-e
                    
                    If !Empty(cIDMovRet)
                        RecLock("SL1",.F.)
                            SL1->L1_XIDMOV  := cIDMovRet
                            SL1->L1_XINT_RM := "S"
                        SL1->(MSUnlock())
                        u_fBaixaFin(cIDMovRet)
                        u_fEnvMail("RM1",cTitulo,cResult)
                    EndIF 
                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog(cEndPoint,cBody,"",cResult,"SL1 - "+SL1->L1_NUM,"2","ERRO")
                EndIF 
            Endif

        EndIf
    EndIF 

    FWRestArea(aAreaSB1)
    FWRestArea(aAreaSAE)
    FWRestArea(aAreaSL4)
    FWRestArea(aAreaSL2)
    FWRestArea(aAreaSL1)    
    FWRestArea(aArea)  
    
Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvPedVend
Realiza o envio do Pedido de Venda para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvPedVend()

    Local aArea    := FWGetArea()
    Local aAreaSL1 := SL1->(FWGetArea())
    Local aAreaSL2 := SL2->(FWGetArea())
    Local aAreaSB1 := SB1->(FWGetArea())
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsDataServer/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cLocEstoq := SuperGetMV("MV_LOCPAD")
    Local cIDMovRet := ""
    Local cTitulo   := "Erro de Integração de Pedido de Venda com o TOTVS Corpore RM - Orçamento: " + SL1->L1_NUM

    DBSelectArea("SL2")
    IF !SL2->(MsSeek(SL1->L1_FILIAL + SL1->L1_NUM ))
        Return
    EndIF 

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:SaveRecord> '
    cBody += '          <tot:DataServerName>MovMovimentoTBCData</tot:DataServerName> '
    cBody += '          <tot:XML> '
    cBody += '                    <![CDATA[ '
    cBody += '                          <MovMovimento> '
    cBody += '                              <TMOV> '
    cBody += '                                  <CODCOLIGADA>'+ cCodEmp +'</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
    cBody += '                                  <CODLOC>' + cLocEstoq + '</CODLOC> ' //Codigo do Local de Destino
    cBody += '                                  <CODCFO>' + SL1->L1_CLIENTE + '</CODCFO> ' //Codigo do Cliente / Fornecedor
    cBody += '                                  <NUMEROMOV>-1</NUMEROMOV> '
    cBody += '                                  <SERIE>PVF</SERIE> '
    cBody += '                                  <CODTMV>2.1.10</CODTMV> '
    cBody += '                                  <TIPO>P</TIPO> '
    cBody += '                                  <STATUS>A</STATUS> '
    cBody += '                                  <MOVIMPRESSO>0</MOVIMPRESSO> '
    cBody += '                                  <DOCIMPRESSO>0</DOCIMPRESSO> '
    cBody += '                                  <FATIMPRESSA>0</FATIMPRESSA> '
    cBody += '                                  <DATAEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATAEMISSAO> '
    cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
    cBody += '                                  <CODCPG>114</CODCPG> ' //Aqui
    cBody += '                                  <VALORBRUTO>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORLIQUIDO> '
    cBody += '                                  <VALOROUTROS>0,0000</VALOROUTROS> '
    cBody += '                                  <PERCENTUALDESC>'+ Alltrim(AlltoChar(SL1->L1_DESCNF, cPicVal)) +'</PERCENTUALDESC> '
    cBody += '                                  <VALORDESC>'+ Alltrim(AlltoChar(SL1->L1_DESCONT, cPicVal)) +'</VALORDESC> '
    cBody += '                                  <PERCENTUALDESP>0,0000</PERCENTUALDESP> '
    cBody += '                                  <VALORDESP>'+ Alltrim(AlltoChar(SL1->L1_DESPESA, cPicVal)) +'</VALORDESP> '
    cBody += '                                  <PERCCOMISSAO>'+ Alltrim(AlltoChar(SL1->L1_COMIS, cPicVal)) +'</PERCCOMISSAO> '
    cBody += '                                  <PESOLIQUIDO>0,0000</PESOLIQUIDO> '
    cBody += '                                  <PESOBRUTO>0,0000</PESOBRUTO> '
    cBody += '                                  <CODTB1FLX>001</CODTB1FLX> ' //aQUI
    cBody += '                                  <CODTB4FLX>1.01</CODTB4FLX> ' //aQUI
    cBody += '                                  <IDMOVLCTFLUXUS>-1</IDMOVLCTFLUXUS> '
    cBody += '                                  <CODMOEVALORLIQUIDO>R$</CODMOEVALORLIQUIDO> '
    cBody += '                                  <DATABASEMOV>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATABASEMOV> '
    cBody += '                                  <DATAMOVIMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</DATAMOVIMENTO> '
    cBody += '                                  <NUMEROLCTGERADO>1</NUMEROLCTGERADO> '
    cBody += '                                  <GEROUFATURA>0</GEROUFATURA> '
    cBody += '                                  <NUMEROLCTABERTO>1</NUMEROLCTABERTO> '
    cBody += '                                  <CODCFOAUX>CXXXXXXXXXX</CODCFOAUX> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Nao tera Centro de Custo no cabecalho
    cBody += '                                  <PERCCOMISSAOVEN2>0,0000</PERCCOMISSAOVEN2> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += '                                  <GERADOPORLOTE>0</GERADOPORLOTE> '
    cBody += '                                  <STATUSEXPORTCONT>0</STATUSEXPORTCONT> '
    cBody += '                                  <CAMPOLIVRE1>' + AllTrim(SL1->L1_XMSGI) + '</CAMPOLIVRE1> '
    cBody += '                                  <CAMPOLIVRE2/> '
    cBody += '                                  <CAMPOLIVRE3/> ' 
    cBody += '                                  <GEROUCONTATRABALHO>0</GEROUCONTATRABALHO> '
    cBody += '                                  <GERADOPORCONTATRABALHO>0</GERADOPORCONTATRABALHO> '
    cBody += '                                  <HORULTIMAALTERACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time()) )  )+ '</HORULTIMAALTERACAO> '
    cBody += '                                  <INDUSOOBJ>0,00</INDUSOOBJ> '
    cBody += '                                  <INTEGRADOBONUM>0</INTEGRADOBONUM> '
    cBody += '                                  <FLAGPROCESSADO>0</FLAGPROCESSADO> '
    cBody += '                                  <ABATIMENTOICMS>0,0000</ABATIMENTOICMS> '
    cBody += '                                  <HORARIOEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</HORARIOEMISSAO> '
    cBody += '                                  <USUARIOCRIACAO>' + cUser + '</USUARIOCRIACAO> '
    cBody += '                                  <DATACRIACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</DATACRIACAO> '
    cBody += '                                  <STSEMAIL>0</STSEMAIL> '
    cBody += '                                  <VALORBRUTOINTERNO>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTOINTERNO> '
    cBody += '                                  <VINCULADOESTOQUEFL>0</VINCULADOESTOQUEFL> '
    cBody += '                                  <VRBASEINSSOUTRAEMPRESA>0,0000</VRBASEINSSOUTRAEMPRESA> '
    cBody += '                                  <VALORDESCCONDICIONAL>0,0000</VALORDESCCONDICIONAL> '
    cBody += '                                  <VALORDESPCONDICIONAL>0,0000</VALORDESPCONDICIONAL> '
    cBody += '                                  <INTEGRADOAUTOMACAO>0</INTEGRADOAUTOMACAO> '
    cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
    cBody += '                                  <DATALANCAMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) )+ '</DATALANCAMENTO> '
    cBody += '                                  <RECIBONFESTATUS>0</RECIBONFESTATUS> '
    cBody += '                                  <IDMOVCFO/> '
    cBody += '                                  <VALORMERCADORIAS>' + Alltrim(AlltoChar(SL1->L1_VALMERC, cPicVal)) + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>0</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORRATEIOLAN> '
    cBody += '                                  <HISTORICOLONGO/> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + Alltrim(AlltoChar(SL1->L1_VALBRUT, cPicVal)) + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORLIQUIDOORIG> '
    cBody += '                                  <VALOROUTROSORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALOROUTROSORIG> '
    cBody += '                                  <VALORRATEIOLANORIG>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORRATEIOLANORIG> '
    cBody += '                                  <FLAGCONCLUSAO>0</FLAGCONCLUSAO> '
    cBody += '                                  <STATUSPARADIGMA>N</STATUSPARADIGMA> '
    cBody += '                                  <STATUSINTEGRACAO>N</STATUSINTEGRACAO> '
    cBody += '                                  <PERCCOMISSAOVEN3>0,0000</PERCCOMISSAOVEN3> '
    cBody += '                                  <PERCCOMISSAOVEN4>0,0000</PERCCOMISSAOVEN4> '
    cBody += '                                  <STATUSMOVINCLUSAOCOLAB>0</STATUSMOVINCLUSAOCOLAB> '
    cBody += '                                  <CODCOLIGADA1>' + cCodEmp + '</CODCOLIGADA1> '
    cBody += '                                  <IDMOVHST>-1</IDMOVHST> '
    cBody += '                              </TMOV> '
    cBody += '                              <TNFE> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <VALORSERVICO>0,0000</VALORSERVICO> '
    cBody += '                                  <DEDUCAOSERVICO>0,0000</DEDUCAOSERVICO> '
    cBody += '                                  <ALIQUOTAISS>0,0000</ALIQUOTAISS>'
    cBody += '                                  <ISSRETIDO>0</ISSRETIDO> '
    cBody += '                                  <VALORISS>0,0000</VALORISS> '
    cBody += '                                  <VALORCREDITOIPTU>0,0000</VALORCREDITOIPTU> '
    cBody += '                                  <BASEDECALCULO>0,0000</BASEDECALCULO> '
    cBody += '                                  <EDITADO>0</EDITADO> '
    cBody += '                              </TNFE> '
    cBody += '                              <TMOVFISCAL> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CONTRIBUINTECREDENCIADO>0</CONTRIBUINTECREDENCIADO> '
    cBody += '                                  <OPERACAOCONSUMIDORFINAL>0</OPERACAOCONSUMIDORFINAL> '
    cBody += '                                  <OPERACAOPRESENCIAL>0</OPERACAOPRESENCIAL> '
    cBody += '                              </TMOVFISCAL> '
    cBody += '                              <TMOVRATCCU> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> '
    cBody += '                                  <NOME>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_DESCCC")) + '</NOME> '
    cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALOR> '
    cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
    cBody += '                              </TMOVRATCCU> '
    
    //Formas de Pagamento do Cupom Fiscal
    DBSelectArea("SL4")
    DBSelectArea("SAE")

    //Credito de Devolução 
    IF !Empty(SL1->L1_CREDITO)
        
        SAE->(MSSeek(xFilial("SAE") + '21' ))

        DBSelectArea("SZ4")
        SZ4->(MsSeek(xFilial("SZ4") + SAE->AE_COD ))
        cCodCaixa := SZ4->Z4_CODCXA
        cCodColCX := SZ4->Z4_CODCOL

        cBody += '                              <TMOVPAGTO> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <CODCOLCFODEFAULT>0</CODCOLCFODEFAULT> '
        cBody += '                                  <CODCFODEFAULT>023133</CODCFODEFAULT> '
        cBody += '                                  <TIPOFORMAPAGTO>'+ Alltrim(SAE->AE_XTPFORM) +'</TIPOFORMAPAGTO> '
        cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
        cBody += '                                  <TAXAADM>'+ Alltrim(AlltoChar(SAE->AE_TAXA, cPicVal)) +'</TAXAADM> '
        cBody += '                                  <CODCXA>'+ Alltrim(cCodCaixa) +'</CODCXA> '
        cBody += '                                  <CODCOLCXA>' + Alltrim(cCodColCX) + '</CODCOLCXA> '
        cBody += '                                  <IDLAN>-1</IDLAN> '
        cBody += '                                  <NOMEREDE/> '
        cBody += '                                  <NSU/> '
        cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
        cBody += '                                  <IDFORMAPAGTO>'+ Alltrim(SAE->AE_XIDFORM) +'</IDFORMAPAGTO> '
        cBody += '                                  <DATAVENCIMENTO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAVENCIMENTO> '
        cBody += '                                  <TIPOPAGAMENTO>1</TIPOPAGAMENTO> '
        cBody += '                                  <VALOR>'+ Alltrim(AlltoChar(SL1->L1_CREDITO, cPicVal)) +'</VALOR> '
        cBody += '                                  <DEBITOCREDITO>C</DEBITOCREDITO> '
        cBody += '                              </TMOVPAGTO> '
    EndIF 
    
    //Formas de Pagamento na SL4 
    IF SL4->(MSSeek(SL1->L1_FILIAL + SL1->L1_NUM))
        While SL4->(!Eof()) .AND. ( SL4->L4_FILIAL  == SL1->L1_FILIAL );
                            .AND. ( SL4->L4_NUM     == SL1->L1_NUM )
            
            cCodAdm := SubStr(Alltrim(SL4->L4_ADMINIS),1,3)
            If Empty(cCodAdm)
                Do Case
                    Case Alltrim(SL4->L4_FORMA) == "R$"
                        cCodAdm := "01"
                    Case Alltrim(SL4->L4_FORMA) == "CH"
                        cCodAdm := "02"
                End Do 
            EndIF 

            SAE->(MSSeek(xFilial("SAE") + cCodAdm ))

            DBSelectArea("SZ4")
            SZ4->(MsSeek(xFilial("SZ4") + SAE->AE_COD ))
            cCodCaixa := SZ4->Z4_CODCXA
            cCodColCX := SZ4->Z4_CODCOL

            cBody += '                              <TMOVPAGTO> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <CODCOLCFODEFAULT>0</CODCOLCFODEFAULT> '
            cBody += '                                  <CODCFODEFAULT>023133</CODCFODEFAULT> '
            cBody += '                                  <TIPOFORMAPAGTO>'+ Alltrim(SAE->AE_XTPFORM) +'</TIPOFORMAPAGTO> '
            cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
            cBody += '                                  <TAXAADM>'+ Alltrim(AlltoChar(SAE->AE_TAXA, cPicVal)) +'</TAXAADM> '
            cBody += '                                  <CODCXA>'+ Alltrim(cCodCaixa) +'</CODCXA> '
            cBody += '                                  <CODCOLCXA>' + Alltrim(cCodColCX) + '</CODCOLCXA> '
            cBody += '                                  <IDLAN>-1</IDLAN> '
            cBody += '                                  <NOMEREDE/> '
            cBody += '                                  <NSU>'+ AllTrim(SL4->L4_NSUTEF) +'</NSU> '
            cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
            cBody += '                                  <IDFORMAPAGTO>'+ Alltrim(SAE->AE_XIDFORM) +'</IDFORMAPAGTO> '
            cBody += '                                  <DATAVENCIMENTO>'+ ( FWTimeStamp(3, SL4->L4_DATA , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAVENCIMENTO> '
            cBody += '                                  <TIPOPAGAMENTO>1</TIPOPAGAMENTO> '
            cBody += '                                  <VALOR>'+ Alltrim(AlltoChar(SL4->L4_VALOR, cPicVal)) +'</VALOR> '
            cBody += '                                  <DEBITOCREDITO>C</DEBITOCREDITO> '
            cBody += '                              </TMOVPAGTO> '
        SL4->(DBSkip())
        End
    EndIF 
    
    //Itens do Cupom Fiscal
    While !SL2->(Eof()) .AND. ( SL2->L2_FILIAL  == SL1->L1_FILIAL ); 
                        .AND. ( SL2->L2_NUM     == SL1->L1_NUM )

        cBody += '                              <TITMMOV> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV>  '
        cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +  '</NSEQITMMOV> '
        cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
        cBody += '                                  <NUMEROSEQUENCIAL>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +  '</NUMEROSEQUENCIAL> '
        cBody += '                                  <IDPRD>' + Alltrim(Posicione('SB1',1,xFilial('SB1')+SL2->L2_PRODUTO,"B1_XIDRM")) + '</IDPRD> '
        cBody += '                                  <CODIGOPRD>' + Alltrim(SL2->L2_PRODUTO) + '</CODIGOPRD> '
        cBody += '                                  <NOMEFANTASIA>' + Alltrim(SL2->L2_DESCRI) + '</NOMEFANTASIA> '
        cBody += '                                  <CODIGOREDUZIDO/> '
        cBody += '                                  <NUMNOFABRIC/> '
        cBody += '                                  <QUANTIDADE>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADE> '
        cBody += '                                  <PRECOUNITARIO>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</PRECOUNITARIO> '
        cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
        cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
        cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , IIF(!Empty(SL1->L1_HORA),SL1->L1_HORA,Time())) ) +'</DATAEMISSAO> '
        cBody += '                                  <CODTB1FAT>002</CODTB1FAT> ' //aQUI
        cBody += '                                  <CODUND>' + Alltrim(SL2->L2_UM) + '</CODUND> '
        cBody += '                                  <QUANTIDADEARECEBER>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADEARECEBER> '
        cBody += '                                  <VALORUNITARIO>' + Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) + '</VALORUNITARIO> '
        cBody += '                                  <VALORFINANCEIRO>' + Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) + '</VALORFINANCEIRO> '
        cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> '
        cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
        cBody += '                                  <QUANTIDADEORIGINAL>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADEORIGINAL> '
        cBody += '                                  <FLAG>0</FLAG> '
        cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
        cBody += '                                  <VALORBRUTOITEM>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORBRUTOITEM> '
        cBody += '                                  <VALORTOTALITEM>'+ Alltrim(AlltoChar(SL2->L2_VLRITEM, cPicVal)) +'</VALORTOTALITEM> '
        cBody += '                                  <QUANTIDADESEPARADA>0,0000</QUANTIDADESEPARADA> '
        cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
        cBody += '                                  <VALORESCRITURACAO>0,0000</VALORESCRITURACAO> '
        cBody += '                                  <VALORFINPEDIDO>0,0000</VALORFINPEDIDO> '
        cBody += '                                  <VALOROPFRM1>0,0000</VALOROPFRM1> '
        cBody += '                                  <VALOROPFRM2>0,0000</VALOROPFRM2> '
        cBody += '                                  <PRECOEDITADO>0</PRECOEDITADO> '
        cBody += '                                  <QTDEVOLUMEUNITARIO>1</QTDEVOLUMEUNITARIO> '
        cBody += '                                  <VALORDESCCONDICONALITM>0,0000</VALORDESCCONDICONALITM> '
        cBody += '                                  <VALORDESPCONDICIONALITM>0,0000</VALORDESPCONDICIONALITM> '
        cBody += '                                  <CODTBORCAMENTO>1.01.02</CODTBORCAMENTO> '
        cBody += '                                  <CODCOLTBORCAMENTO>' + cCodEmp + '</CODCOLTBORCAMENTO> '
        cBody += '                                  <VALORUNTORCAMENTO>0,0000</VALORUNTORCAMENTO> '
        cBody += '                                  <VALSERVICONFE>0,0000</VALSERVICONFE> '
        cBody += '                                  <CODLOC>' + cLocEstoq + '</CODLOC> '
        cBody += '                                  <VALORBEM>0,0000</VALORBEM> '
        cBody += '                                  <VALORLIQUIDO>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORLIQUIDO> '
        cBody += '                                  <RATEIOCCUSTODEPTO>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</RATEIOCCUSTODEPTO> '
        cBody += '                                  <VALORBRUTOITEMORIG>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALORBRUTOITEMORIG> '
        cBody += '                                  <IDTABPRECO>1</IDTABPRECO> '
        cBody += '                                  <QUANTIDADETOTAL>' + Alltrim(AlltoChar(SL2->L2_QUANT, cPicVal)) + '</QUANTIDADETOTAL> '
        cBody += '                                  <PRODUTOSUBSTITUTO>0</PRODUTOSUBSTITUTO> '
        cBody += '                                  <PRECOUNITARIOSELEC>0</PRECOUNITARIOSELEC> '
        cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
        cBody += '                                  <VALORBASEDEPRECIACAOBEM>0,0000</VALORBASEDEPRECIACAOBEM> '
        cBody += '                                  <IDMOVSOLICITACAOMNT>0</IDMOVSOLICITACAOMNT> ' 
        cBody += '                                  <CODCOLIGADA1>' + cCodEmp + '</CODCOLIGADA1> '
        cBody += '                                  <IDMOVHST>-1</IDMOVHST> '
        cBody += '                                  <NSEQITMMOV1>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) + '</NSEQITMMOV1> '
        cBody += '                              </TITMMOV> '
        cBody += '                              <TITMMOVRATCCU> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SL2->L2_ITEM))) + '</NSEQITMMOV> '
        cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Rateio de Centro de Custo do Item Nao tera
        cBody += '                                  <NOME>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SL2->L2_PRODUTO,"Z2_DESCCC")) + '</NOME> '
        cBody += '                                  <VALOR>' + Alltrim(AlltoChar(SL2->L2_VRUNIT, cPicVal)) + '</VALOR> '
        cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
        cBody += '                              </TITMMOVRATCCU> '
        cBody += '                              <TITMMOVCOMPL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                              </TITMMOVCOMPL> '     
        cBody += '                              <TITMMOVFISCAL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ Alltrim(AlltoChar(Val(SL2->L2_ITEM))) +'</NSEQITMMOV> '
        cBody += '                                  <QTDECONTRATADA>0,0000</QTDECONTRATADA> '
        cBody += '                                  <VLRTOTTRIB>0,0000</VLRTOTTRIB> '
        cBody += '                                  <AQUISICAOPAA>0</AQUISICAOPAA> '
        cBody += '                                  <POEBTRIBUTAVEL>1</POEBTRIBUTAVEL> '
        cBody += '                              </TITMMOVFISCAL> '
    SL2->(DBSkip())
    EndDo

    cBody += '                              <TMOVCOMPL> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <IDPERLET/> '
    cBody += '                                  <RA/> '
    cBody += '                                  <MATRIZAPLICADA/> '
    cBody += '                              </TMOVCOMPL> '
    cBody += '                              <TMOVTRANSP> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <RETIRAMERCADORIA>0</RETIRAMERCADORIA> '
    cBody += '                                  <TIPOCTE>0</TIPOCTE> '
    cBody += '                                  <TOMADORTIPO>0</TOMADORTIPO> '
    cBody += '                                  <TIPOEMITENTEMDFE>0</TIPOEMITENTEMDFE> '
    cBody += '                                  <LOTACAO>1</LOTACAO> '
    cBody += '                                  <TIPOTRANSPORTADORMDFE>0</TIPOTRANSPORTADORMDFE> '
    cBody += '                                  <TIPOBPE>0</TIPOBPE> '
    cBody += '                              </TMOVTRANSP> '
    cBody += '                              <TCTRCMOV> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <VALORNOTAS>0,0000</VALORNOTAS> '
    cBody += '                                  <VALORRATEADO>0,0000</VALORRATEADO> '
    cBody += '                                  <QUANTIDADENOTAS>0</QUANTIDADENOTAS> '
    cBody += '                                  <QUANTIDADERATEADAS>0</QUANTIDADERATEADAS> '
    cBody += '                              </TCTRCMOV> '
    cBody += '                          </MovMovimento>]]> '
    cBody += '          </tot:XML> '
    cBody += '          <tot:Contexto>CODCOLIGADA=' + cCodEmp + ';CODSISTEMA=T</tot:Contexto> '
    cBody += '     </tot:SaveRecord> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("SaveRecord")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Venda Futura / Orçamento - "+SL1->L1_NUM,"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Venda Futura / Orçamento - "+SL1->L1_NUM,"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,"",oXML:Error(),"Venda Futura / Orçamento - "+SL1->L1_NUM,"2","ERRO")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                IF Len(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')) < 15 
                    cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                         At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')
                EndIF
                
                If !Empty(cIDMovRet) .And. Len(cIDMovRet) < 10
                    RecLock("SL1",.F.)
                        SL1->L1_XIDMOV  := cIDMovRet
                        SL1->L1_XINT_RM := "S"
                    SL1->(MSUnlock())
                    u_fnGrvLog(cEndPoint,cBody,cResult,"","Venda Futura / Orçamento - "+SL1->L1_NUM,"6","ENVIO")
                Else
                    
                    If !Empty(cIDMovRet)
                        RecLock("SL1",.F.)
                            SL1->L1_XIDMOV  := cIDMovRet
                            SL1->L1_XINT_RM := "S"
                        SL1->(MSUnlock())
                        u_fEnvMail("RM1",cTitulo,cResult)
                    EndIF 
                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog(cEndPoint,cBody,"",cResult,"Venda Futura / Orçamento - "+SL1->L1_NUM,"2","ERRO")
                EndIF 
            Endif

        EndIf
    EndIF 

    FWRestArea(aAreaSB1)
    FWRestArea(aAreaSL2)
    FWRestArea(aAreaSL1)    
    FWRestArea(aArea)  
    
Return
//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvNFeDev
Realiza o envio da Nota Fiscal de Entrada para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvNFeDev()
    Local aArea    := FWGetArea()
    Local aAreaSF1 := SF1->(FWGetArea())
    Local aAreaSD1 := SD1->(FWGetArea())
    Local aAreaSL1 := SL1->(FWGetArea())
    Local aAreaSZ3 := SZ3->(FWGetArea())
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsDataServer/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cLocEstoq := SuperGetMV("MV_LOCPAD")
    Local cIDMovRet := ""
    Local cIDNat    := ""
    Local cCodColCX := ""
    Local cCodCaixa := ""
    Local cTitulo   := "Erro de Integração NF Devolução "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE) + " com o TOTVS Corpore RM"

    DBSelectArea("SD1")
    SD1->(MsSeek(xFilial("SD1") + SF1->F1_DOC + SF1->F1_SERIE + SF1->F1_FORNECE + SF1->F1_LOJA))

    DBSelectArea("SZ3")
    SZ3->(MsSeek(xFilial("SZ3") + Posicione("SB1",1,xFilial("SB1")+SD1->D1_COD,"B1_XCLAFIS")))
    cIDNat := AllTrim(SZ3->Z3_IDSINDE)

    DBSelectArea("SL1")
    SL1->(DBSetOrder(2))
    SL1->(MsSeek(xFilial("SL1") + SD1->D1_SERIORI + SD1->D1_NFORI))

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:SaveRecord> '
    cBody += '          <tot:DataServerName>MovMovCopiaReferenciaData</tot:DataServerName> '
    cBody += '          <tot:XML> '
    cBody += '                    <![CDATA[ '
    cBody += '                          <MovMovimento> '
    cBody += '                              <TMOV> '
    cBody += '                                  <CODCOLIGADA>'+ cCodEmp +'</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
    cBody += '                                  <CODLOC>' + AllTrim(cLocEstoq) + '</CODLOC> '
    cBody += '                                  <CODLOCDESTINO>' + AllTrim(cLocEstoq) + '</CODLOCDESTINO> '
    cBody += '                                  <CODCFO>' + AllTrim(SF1->F1_FORNECE) + '</CODCFO> '
    cBody += '                                  <NUMEROMOV>-1</NUMEROMOV> ' //Numero do Movimento igual a -1 para que utilize a numeracao do RM
    cBody += '                                  <SERIE>2</SERIE> ' //Serie chumbada devido informado pelos usuarios durante prototipo
    cBody += '                                  <CODTMV>1.2.22</CODTMV> '
    cBody += '                                  <TIPO>P</TIPO> '
    cBody += '                                  <STATUS>F</STATUS> '
    cBody += '                                  <MOVIMPRESSO>0</MOVIMPRESSO> '
    cBody += '                                  <DOCIMPRESSO>0</DOCIMPRESSO> '
    cBody += '                                  <FATIMPRESSA>0</FATIMPRESSA> '
    cBody += '                                  <DATAEMISSAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATAEMISSAO> '
    cBody += '                                  <DATASAIDA>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATASAIDA> '
    cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
    cBody += '                                  <VALORBRUTO>' + AllTrim(AlltoChar(SF1->F1_VALBRUT, cPicVal)) + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALORLIQUIDO> '
    cBody += '                                  <VALOROUTROS>0,0000</VALOROUTROS> '
    cBody += '                                  <PERCENTUALFRETE>0,0000</PERCENTUALFRETE> '
    cBody += '                                  <VALORFRETE>0,0000</VALORFRETE> '
    cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
    cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
    cBody += '                                  <PERCENTUALDESP>0,0000</PERCENTUALDESP> '
    cBody += '                                  <VALORDESP>0,0000</VALORDESP> '
    cBody += '                                  <PERCCOMISSAO>0,0000</PERCCOMISSAO> '
    cBody += '                                  <PESOLIQUIDO>0,0000</PESOLIQUIDO> '
    cBody += '                                  <PESOBRUTO>0,0000</PESOBRUTO> '
    cBody += '                                  <CODTB1FLX/> ' //Aqui
    cBody += '                                  <CODTB3FLX/> ' //Aqui
    cBody += '                                  <CODTB4FLX/> ' //Aqui
    cBody += '                                  <IDMOVLCTFLUXUS>-1</IDMOVLCTFLUXUS> '
    cBody += '                                  <CODMOEVALORLIQUIDO>R$</CODMOEVALORLIQUIDO> '
    cBody += '                                  <DATAMOVIMENTO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATAMOVIMENTO> '
    cBody += '                                  <NUMEROLCTGERADO>1</NUMEROLCTGERADO> '
    cBody += '                                  <GEROUFATURA>0</GEROUFATURA> '
    cBody += '                                  <NUMEROLCTABERTO>1</NUMEROLCTABERTO> '
    cBody += '                                  <FRETECIFOUFOB>9</FRETECIFOUFOB> '
    cBody += '                                  <SEGUNDONUMERO>' + AllTrim(SF1->F1_DOC) + '</SEGUNDONUMERO> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SD1->D1_COD,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Nao tera Centro de Custo no cabecalho
    cBody += '                                  <PERCCOMISSAOVEN2>0,0000</PERCCOMISSAOVEN2> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += '                                  <CODFILIALDESTINO>' + cCodFil + '</CODFILIALDESTINO> '
    cBody += '                                  <GERADOPORLOTE>0</GERADOPORLOTE> '
    cBody += '                                  <CODEVENTO>32</CODEVENTO> '
    cBody += '                                  <STATUSEXPORTCONT>1</STATUSEXPORTCONT> '
    //cBody += '                                  <CODLOTE>41222</CODLOTE> '
    //cBody += '                                  <IDNAT>431</IDNAT> '
    cBody += '                                  <IDNAT>' + cIDNat + '</IDNAT> '
    cBody += '                                  <GEROUCONTATRABALHO>0</GEROUCONTATRABALHO> '
    cBody += '                                  <GERADOPORCONTATRABALHO>0</GERADOPORCONTATRABALHO> '
    cBody += '                                  <HORULTIMAALTERACAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</HORULTIMAALTERACAO> '
    cBody += '                                  <INDUSOOBJ>0.00</INDUSOOBJ> '
    cBody += '                                  <INTEGRADOBONUM>0</INTEGRADOBONUM> '
    cBody += '                                  <FLAGPROCESSADO>0</FLAGPROCESSADO> '
    cBody += '                                  <ABATIMENTOICMS>0,0000</ABATIMENTOICMS> '
    cBody += '                                  <HORARIOEMISSAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</HORARIOEMISSAO> '
    cBody += '                                  <USUARIOCRIACAO>' + cUser + '</USUARIOCRIACAO> '
    cBody += '                                  <DATACRIACAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATACRIACAO> '
    cBody += '                                  <STSEMAIL>0</STSEMAIL> '
    cBody += '                                  <VALORBRUTOINTERNO>' + AllTrim(AlltoChar(SF1->F1_VALBRUT, cPicVal)) + '</VALORBRUTOINTERNO> '
    cBody += '                                  <VINCULADOESTOQUEFL>0</VINCULADOESTOQUEFL> '
    cBody += '                                  <HORASAIDA>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</HORASAIDA> '
    cBody += '                                  <VRBASEINSSOUTRAEMPRESA>0,0000</VRBASEINSSOUTRAEMPRESA> '
    cBody += '                                  <CODTDO>55</CODTDO> '
    cBody += '                                  <VALORDESCCONDICIONAL>0,0000</VALORDESCCONDICIONAL> '
    cBody += '                                  <VALORDESPCONDICIONAL>0,0000</VALORDESPCONDICIONAL> '
    cBody += '                                  <DATACONTABILIZACAO>' + ( FWTimeStamp(3, SF1->F1_DTDIGIT , SF1->F1_HORA )  )+ '</DATACONTABILIZACAO> '
    cBody += '                                  <INTEGRADOAUTOMACAO>0</INTEGRADOAUTOMACAO> '
    cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
    cBody += '                                  <DATALANCAMENTO>' + ( FWTimeStamp(3, SF1->F1_DTDIGIT , SF1->F1_HORA )  )+ '</DATALANCAMENTO> '
    cBody += '                                  <RECIBONFESTATUS>0</RECIBONFESTATUS> '
    cBody += '                                  <VALORMERCADORIAS>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>1</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALORRATEIOLAN> '
    cBody += '                                  <HISTORICOCURTO>Nota fiscal de saida referenciada Nº: ' + AllTrim(SD1->D1_NFORI) + ' Serie: ' + AllTrim(SD1->D1_SERIORI) + '</HISTORICOCURTO> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + AllTrim(AlltoChar(SF1->F1_VALBRUT, cPicVal)) + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALORLIQUIDOORIG> '
    cBody += '                                  <VALOROUTROSORIG>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALOROUTROSORIG> '
    cBody += '                                  <VALORRATEIOLANORIG>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALORRATEIOLANORIG> '
    cBody += '                                  <FLAGCONCLUSAO>0</FLAGCONCLUSAO> '
    cBody += '                                  <STATUSPARADIGMA>N</STATUSPARADIGMA> '
    cBody += '                                  <STATUSINTEGRACAO>N</STATUSINTEGRACAO> '
    cBody += '                                  <PERCCOMISSAOVEN3>0,0000</PERCCOMISSAOVEN3> '
    cBody += '                                  <PERCCOMISSAOVEN4>0,0000</PERCCOMISSAOVEN4> '
    cBody += '                                  <STATUSMOVINCLUSAOCOLAB>0</STATUSMOVINCLUSAOCOLAB> '
    cBody += '                                  <IDMOVRELAC>' + AllTrim(SL1->L1_XIDMOV) + '</IDMOVRELAC> ' //Verificar o ID Relacionado da NF de Saida
    cBody += '                              </TMOV> '
    cBody += '                              <TNFE> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <VALORSERVICO>0,0000</VALORSERVICO> '
    cBody += '                                  <DEDUCAOSERVICO>0,0000</DEDUCAOSERVICO> '
    cBody += '                                  <ALIQUOTAISS>0,0000</ALIQUOTAISS> '
    cBody += '                                  <ISSRETIDO>0</ISSRETIDO> '
    cBody += '                                  <VALORISS>0,0000</VALORISS> '
    cBody += '                                  <VALORCREDITOIPTU>0,0000</VALORCREDITOIPTU> '
    cBody += '                                  <BASEDECALCULO>0,0000</BASEDECALCULO> '
    cBody += '                                  <EDITADO>0</EDITADO> '
    cBody += '                              </TNFE> '
    cBody += '                              <TMOVFISCAL> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CONTRIBUINTECREDENCIADO>0</CONTRIBUINTECREDENCIADO> '
    cBody += '                                  <OPERACAOCONSUMIDORFINAL>1</OPERACAOCONSUMIDORFINAL> '
    cBody += '                                  <DATAINICIOCREDITO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  ) + '</DATAINICIOCREDITO> '
    cBody += '                                  <OPERACAOPRESENCIAL>0</OPERACAOPRESENCIAL> '
    cBody += '                              </TMOVFISCAL> '
    cBody += '                              <TMOVRATCCU> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SD1->D1_COD,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Nao tera Centro de Custo no cabecalho
    cBody += '                                  <NOME>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SD1->D1_COD,"Z2_DESCCC")) + '</NOME> '
    cBody += '                                  <VALOR>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALOR> '
    cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
    cBody += '                              </TMOVRATCCU> '
    cBody += '                              <TMOVHISTORICO> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <HISTORICOLONGO>Nota fiscal de saida referenciada Nº: ' + AllTrim(SD1->D1_NFORI) + ' Serie: ' + AllTrim(SD1->D1_SERIORI) + '</HISTORICOLONGO> '
    cBody += '                                  <HISTORICOCURTO>Nota fiscal de saida referenciada Nº: ' + AllTrim(SD1->D1_NFORI) + ' Serie: ' + AllTrim(SD1->D1_SERIORI) + '</HISTORICOCURTO> '
    cBody += '                              </TMOVHISTORICO> '
    
    DBSelectArea("SAE")

    //Credito de Devolução     
    SAE->(MSSeek(xFilial("SAE") + '21' ))

    DBSelectArea("SZ4")
    SZ4->(MsSeek(xFilial("SZ4") + SAE->AE_COD ))
    cCodCaixa := SZ4->Z4_CODCXA
    cCodColCX := SZ4->Z4_CODCOL

    cBody += '                              <TMOVPAGTO> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <TIPOFORMAPAGTO>'+ Alltrim(SAE->AE_XTPFORM) +'</TIPOFORMAPAGTO> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <TAXAADM>'+ Alltrim(AlltoChar(SAE->AE_TAXA, cPicVal)) +'</TAXAADM> '
    cBody += '                                  <CODCXA>' + AllTrim(cCodCaixa) + '</CODCXA> '
    cBody += '                                  <CODCOLCXA>' + AllTrim(cCodColCX) + '</CODCOLCXA> '
    cBody += '                                  <IDLAN>-1</IDLAN> '
    cBody += '                                  <NOMEREDE/> '
    cBody += '                                  <NSU/> '
    cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
    cBody += '                                  <IDFORMAPAGTO>'+ Alltrim(SAE->AE_XIDFORM) +'</IDFORMAPAGTO> '
    cBody += '                                  <DATAVENCIMENTO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATAVENCIMENTO> '
    cBody += '                                  <TIPOPAGAMENTO>1</TIPOPAGAMENTO> '
    cBody += '                                  <VALOR>' + AllTrim(AlltoChar(SF1->F1_VALMERC, cPicVal)) + '</VALOR> '
    cBody += '                                  <DEBITOCREDITO>C</DEBITOCREDITO> '
    cBody += '                              </TMOVPAGTO> '
    
    //Itens da Nota Fiscal de Entrada (Devolucao)
    While !SD1->(Eof()) .AND. ( SD1->D1_FILIAL  == SF1->F1_FILIAL ); 
                        .AND. ( SD1->D1_DOC     == SF1->F1_DOC ); 
                        .AND. ( SF1->F1_SERIE   == SF1->F1_SERIE ); 
                        .AND. ( SD1->D1_FORNECE == SF1->F1_FORNECE ); 
                        .AND. ( SD1->D1_LOJA    == SF1->F1_LOJA )

            SZ3->(MsSeek(xFilial("SZ3") + Posicione("SB1",1,xFilial("SB1")+SD1->D1_COD,"B1_XCLAFIS")))
            cIDNat := AllTrim(SZ3->Z3_IDANADE)

            cBody += '                              <TITMMOV> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV>  '
            cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NSEQITMMOV> '
            cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
            cBody += '                                  <NUMEROSEQUENCIAL>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NUMEROSEQUENCIAL> '
            cBody += '                                  <IDPRD>' + Alltrim(Posicione('SB1',1,xFilial('SB1')+SD1->D1_COD,"B1_XIDRM")) + '</IDPRD> '
            cBody += '                                  <NUMNOFABRIC/> '
            cBody += '                                  <QUANTIDADE>' + AllTrim(AlltoChar(SD1->D1_QUANT, cPicVal)) + '</QUANTIDADE> '
            cBody += '                                  <PRECOUNITARIO>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</PRECOUNITARIO> '
            cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
            cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
            cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
            cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA) ) +'</DATAEMISSAO> '
            cBody += '                                  <CODUND>' + AllTrim(SD1->D1_UM) + '</CODUND> '
            cBody += '                                  <QUANTIDADEARECEBER>' + AllTrim(AlltoChar(SD1->D1_QUANT, cPicVal)) + '</QUANTIDADEARECEBER> '
            cBody += '                                  <FLAGEFEITOSALDO>1</FLAGEFEITOSALDO> '
            cBody += '                                  <VALORUNITARIO>' + AllTrim(AlltoChar(SD1->D1_TOTAL, cPicVal)) + '</VALORUNITARIO> '
            cBody += '                                  <VALORFINANCEIRO>' + AllTrim(AlltoChar(SD1->D1_TOTAL, cPicVal)) + '</VALORFINANCEIRO> '
            cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SD1->D1_COD,"Z2_CCUSTO")) + '</CODCCUSTO> '
            cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
            cBody += '                                  <QUANTIDADEORIGINAL>' + AllTrim(AlltoChar(SD1->D1_QUANT, cPicVal)) + '</QUANTIDADEORIGINAL> '
            //cBody += '                                  <IDNAT>431</IDNAT> '
            cBody += '                                  <IDNAT>' + cIDNat + '</IDNAT> '
            cBody += '                                  <FLAG>0</FLAG> '
            cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
            cBody += '                                  <VALORBRUTOITEM>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</VALORBRUTOITEM> '
            cBody += '                                  <VALORTOTALITEM>' + AllTrim(AlltoChar(SD1->D1_TOTAL, cPicVal)) + '</VALORTOTALITEM> '
            cBody += '                                  <QUANTIDADESEPARADA>0,0000</QUANTIDADESEPARADA> '
            cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
            cBody += '                                  <VALORESCRITURACAO>0,0000</VALORESCRITURACAO> '
            cBody += '                                  <VALORFINPEDIDO>0,0000</VALORFINPEDIDO> '
            cBody += '                                  <VALOROPFRM1>0,0000</VALOROPFRM1> '
            cBody += '                                  <VALOROPFRM2>0,0000</VALOROPFRM2> '
            cBody += '                                  <PRECOEDITADO>0</PRECOEDITADO> '
            cBody += '                                  <QTDEVOLUMEUNITARIO>1</QTDEVOLUMEUNITARIO> '
            cBody += '                                  <CST>000</CST> '
            cBody += '                                  <VALORDESCCONDICONALITM>0,0000</VALORDESCCONDICONALITM> '
            cBody += '                                  <VALORDESPCONDICIONALITM>0,0000</VALORDESPCONDICIONALITM> '
            cBody += '                                  <CODTBORCAMENTO/> '
            cBody += '                                  <CODCOLTBORCAMENTO>' + cCodEmp + '</CODCOLTBORCAMENTO> '
            cBody += '                                  <RATEIOFRETE>0,0000</RATEIOFRETE> '
            cBody += '                                  <RATEIODESC>0,0000</RATEIODESC> '
            cBody += '                                  <RATEIODESP>0,0000</RATEIODESP> '
            cBody += '                                  <VALORUNTORCAMENTO>0,0000</VALORUNTORCAMENTO> '
            cBody += '                                  <VALSERVICONFE>0,0000</VALSERVICONFE> '
            cBody += '                                  <CODLOC>' + AllTrim(SD1->D1_LOCAL) + '</CODLOC> '
            cBody += '                                  <VALORBEM>0,0000</VALORBEM> '
            cBody += '                                  <VALORLIQUIDO>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</VALORLIQUIDO> '
            cBody += '                                  <RATEIOCCUSTODEPTO>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</RATEIOCCUSTODEPTO> '
            cBody += '                                  <VALORBRUTOITEMORIG>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</VALORBRUTOITEMORIG> '
            cBody += '                                  <CODNATUREZAITEM>1.202.01</CODNATUREZAITEM> ' //Aqui ??????
            cBody += '                                  <QUANTIDADETOTAL>' + AllTrim(AlltoChar(SD1->D1_QUANT, cPicVal)) + '</QUANTIDADETOTAL> '
            cBody += '                                  <PRODUTOSUBSTITUTO>0</PRODUTOSUBSTITUTO> '
            cBody += '                                  <PRECOUNITARIOSELEC>0</PRECOUNITARIOSELEC> '
            cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
            cBody += '                                  <VALORBASEDEPRECIACAOBEM>0,0000</VALORBASEDEPRECIACAOBEM> '
            cBody += '                                  <IDMOVSOLICITACAOMNT>0</IDMOVSOLICITACAOMNT> ' 
            cBody += '                              </TITMMOV> '
            cBody += '                              <TITMMOVRATCCU> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NSEQITMMOV> '
            cBody += '                                  <CODCCUSTO>' + Alltrim(Posicione("SZ2",1, xFilial("SZ2") + SD1->D1_COD,"Z2_CCUSTO")) + '</CODCCUSTO> ' //Nao tera Rateio de Centro de Custo no Item
            cBody += '                                  <VALOR>' + AllTrim(AlltoChar(SD1->D1_VUNIT, cPicVal)) + '</VALOR> '
            cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
            cBody += '                              </TITMMOVRATCCU> '
            cBody += '                              <TITMMOVCOMPL> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NSEQITMMOV> '
            cBody += '                              </TITMMOVCOMPL> '
            cBody += '                              <TITMMOVRELAC> '
            cBody += '                                  <CODCOLORIGEM>' + cCodEmp + '</CODCOLORIGEM> '
            cBody += '                                  <IDMOVORIGEM>-1</IDMOVORIGEM> '
            cBody += '                                  <NSEQITMMOVORIGEM>' + Alltrim(AlltoChar(Val(SD1->D1_ITEMORI))) + '</NSEQITMMOVORIGEM> '
            cBody += '                                  <CODCOLDESTINO>' + cCodEmp + '</CODCOLDESTINO> '
            cBody += '                                  <IDMOVDESTINO>' + AllTrim(SL1->L1_XIDMOV) + '</IDMOVDESTINO> ' //Identificador de Referencia
            cBody += '                                  <NSEQITMMOVDESTINO>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NSEQITMMOVDESTINO> '
            cBody += '                                  <QUANTIDADE>' + AllTrim(AlltoChar(SD1->D1_QUANT, cPicVal)) + '</QUANTIDADE> '
            cBody += '                                  <VALORRECEBIDO>' + AllTrim(AlltoChar(SD1->D1_TOTAL, cPicVal)) + '</VALORRECEBIDO> '
            cBody += '                              </TITMMOVRELAC> '
            cBody += '                              <TITMMOVFISCAL> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <NSEQITMMOV>' + Alltrim(AlltoChar(Val(SD1->D1_ITEM))) + '</NSEQITMMOV> '
            cBody += '                                  <VLRTOTTRIB>0,0000</VLRTOTTRIB> '
            cBody += '                                  <VALORIBPTFEDERAL>0,0000</VALORIBPTFEDERAL> '
            cBody += '                                  <VALORIBPTESTADUAL>0,0000</VALORIBPTESTADUAL> '
            cBody += '                                  <VALORIBPTMUNICIPAL>0,0000</VALORIBPTMUNICIPAL> '
            cBody += '                                  <AQUISICAOPAA>0</AQUISICAOPAA> '
            cBody += '                              </TITMMOVFISCAL> '
        SD1->(DBSkip())
    EndDo 
    
    SD1->(MsSeek(SF1->F1_FILIAL + SF1->F1_DOC + SF1->F1_SERIE + SF1->F1_FORNECE + SF1->F1_LOJA))
    
    cBody += '                              <TMOVCOMPL> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                              </TMOVCOMPL> '        
    cBody += '                              <TMOVTRANSP> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <RETIRAMERCADORIA>0</RETIRAMERCADORIA> '
    cBody += '                                  <TIPOCTE>0</TIPOCTE> '
    cBody += '                                  <TOMADORTIPO>0</TOMADORTIPO> '
    cBody += '                                  <TIPOEMITENTEMDFE>0</TIPOEMITENTEMDFE> '
    cBody += '                                  <LOTACAO>1</LOTACAO> '
    cBody += '                                  <TIPOTRANSPORTADORMDFE>0</TIPOTRANSPORTADORMDFE> '
    cBody += '                                  <TIPOBPE>0</TIPOBPE> '
    cBody += '                              </TMOVTRANSP> '
    cBody += '                              <TCTRCMOV> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <VALORNOTAS>0,0000</VALORNOTAS> '
    cBody += '                                  <VALORRATEADO>0,0000</VALORRATEADO> '
    cBody += '                                  <QUANTIDADENOTAS>0</QUANTIDADENOTAS> '
    cBody += '                                  <QUANTIDADERATEADAS>0</QUANTIDADERATEADAS> '
    cBody += '                              </TCTRCMOV> '
    cBody += '                              <TCHAVEACESSOREF> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <IDREF>0</IDREF> '
    cBody += '                                  <CODCOLIGADAREF>' + cCodEmp + '</CODCOLIGADAREF> '
    cBody += '                                  <IDMOVREF>' + AllTrim(SL1->L1_XIDMOV) + '</IDMOVREF> ' //Identificador de Referencia
    cBody += '                                  <CHAVEACESSO>' + AllTrim(SL1->L1_KEYNFCE) + '</CHAVEACESSO> '
    cBody += '                                  <CODTMV>2.2.25</CODTMV> '
    cBody += '                                  <NUMEROMOV>' + AllTrim(SL1->L1_DOC) + '</NUMEROMOV> '
    cBody += '                                  <SERIE>' + AllTrim(SL1->L1_SERIE) + '</SERIE> '
    cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) ) +'</DATAEMISSAO> '
    cBody += '                                  <VALORLIQUIDO>' + AllTrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORLIQUIDO> '
    cBody += '                              </TCHAVEACESSOREF> '
    cBody += '                              <TMOVRELAC> '
    cBody += '                                  <CODCOLORIGEM>' + cCodEmp + '</CODCOLORIGEM> '
    cBody += '                                  <IDMOVORIGEM>-1</IDMOVORIGEM> '
    cBody += '                                  <CODCOLDESTINO>' + cCodEmp + '</CODCOLDESTINO> '
    cBody += '                                  <IDMOVDESTINO>' + AllTrim(SL1->L1_XIDMOV) + '</IDMOVDESTINO> ' //Identificador de Referencia
    cBody += '                                  <TIPORELAC>V</TIPORELAC> '
    cBody += '                                  <IDPROCESSO>-1</IDPROCESSO> '
    cBody += '                                  <VALORRECEBIDO>' + AllTrim(AlltoChar(SL1->L1_VLRLIQ, cPicVal)) + '</VALORRECEBIDO> '
    cBody += '                              </TMOVRELAC> '
    cBody += '                          </MovMovimento>]]> '
    cBody += '          </tot:XML> '
    cBody += '          <tot:Contexto>CODCOLIGADA=' + cCodEmp + ';CODSISTEMA=T</tot:Contexto> '
    cBody += '     </tot:SaveRecord> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("SaveRecord")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"NF: "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE),"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"NF: "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE),"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"NF: "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE),"2","ERRO")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                IF Len(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')) < 15 
                    cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                        At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')
                EndIF 
                
                If !Empty(cIDMovRet)
                    RecLock("SF1",.F.)
                        SF1->F1_XIDMOV := cIDMovRet
                        SF1->F1_XINT_RM := "S"
                    SF1->(MSUnlock())
                    u_fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),"NF: "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE),"6","ENVIO")
                Else
                    cIDMovRet := wsNumeroMOV() //Realiza consulta do Movimento atraves do Numero,Serie e Cliente do NFC-e
                    
                    If !Empty(cIDMovRet)
                        RecLock("SF1",.F.)
                            SF1->F1_XIDMOV := cIDMovRet
                            SF1->F1_XINT_RM := "S"
                        SF1->(MSUnlock())
                        u_fEnvMail("RM1",cTitulo,cResult)
                    EndIF

                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog(cEndPoint,cBody,"",cResult,"NF: "+AllTrim(SF1->F1_DOC) + " - Serie: "+ AllTrim(SF1->F1_SERIE),"2","ERRO")
                EndIF 
            Endif

        EndIf
    EndIF 
    
    FWRestArea(aAreaSZ3)
    FWRestArea(aAreaSL1)
    FWRestArea(aAreaSD1)
    FWRestArea(aAreaSF1)
    FWRestArea(aArea)  

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fCanFinan
Realiza o cancelamento da baixa financeira no RM
/*/
//-----------------------------------------------------------------------------

User Function fCanFinan(pIDLan,pIDBaixa)
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsProcess/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""

    Default lRet := .F.

    cBody := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/">'
    cBody += '<soapenv:Header/>'
    cBody += '<soapenv:Body>'
    cBody += '<tot:ExecuteWithXmlParams>'
    cBody += '<tot:ProcessServerName>FinLanBaixaCancelamentoData</tot:ProcessServerName>'
    cBody += '<tot:strXmlParams>'
    cBody += '<![CDATA[<?xml version="1.0" encoding="utf-16"?>'
    cBody += '<FinLanCancelamentoBaixaParamsProc z:Id="i1" xmlns="http://www.totvs.com.br/RM/" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" xmlns:z="http://schemas.microsoft.com/2003/10/Serialization/">'
    cBody += '<ActionModule xmlns="http://www.totvs.com/">F</ActionModule>'
    cBody += '<ActionName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoAction</ActionName>'
    cBody += '<CanParallelize xmlns="http://www.totvs.com/">true</CanParallelize>'
    cBody += '<CanSendMail xmlns="http://www.totvs.com/">false</CanSendMail>'
    cBody += '<CanWaitSchedule xmlns="http://www.totvs.com/">false</CanWaitSchedule>'
    cBody += '<CodUsuario xmlns="http://www.totvs.com/">' + cUser + '</CodUsuario>'
    cBody += '<ConnectionId i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<ConnectionString i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<Context z:Id="i2" xmlns="http://www.totvs.com/" xmlns:a="http://www.totvs.com.br/RM/">'
    cBody += '<a:_params xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EXERCICIOFISCAL</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">22</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODLOCPRT</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODTIPOCURSO</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EDUTIPOUSR</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUNIDADEBIB</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODCOLIGADA</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$RHTIPOUSR</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">01</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODIGOEXTERNO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODSISTEMA</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIOSERVICO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema" />'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">' + cUser + '</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$IDPRJ</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CHAPAFUNCIONARIO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">00001</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODFILIAL</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '</a:_params>'
    cBody += '<a:Environment>DotNet</a:Environment>'
    cBody += '</Context>'
    cBody += '<CustomData i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<DisableIsolateProcess xmlns="http://www.totvs.com/">false</DisableIsolateProcess>'
    cBody += '<DriverType i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<ExecutionId xmlns="http://www.totvs.com/">d2344acc-51e6-487e-bbeb-7e0074c291bd</ExecutionId>'
    cBody += '<FailureMessage xmlns="http://www.totvs.com/">Falha na execucao do processo</FailureMessage>'
    cBody += '<FriendlyLogs i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<HideProgressDialog xmlns="http://www.totvs.com/">false</HideProgressDialog>'
    cBody += '<HostName xmlns="http://www.totvs.com/">RECN019403717</HostName>'
    cBody += '<Initialized xmlns="http://www.totvs.com/">true</Initialized>'
    cBody += '<Ip xmlns="http://www.totvs.com/">192.168.56.1</Ip>'
    cBody += '<IsolateProcess xmlns="http://www.totvs.com/">false</IsolateProcess>'
    cBody += '<JobID xmlns="http://www.totvs.com/">'
    cBody += '<Children />'
    cBody += '<ExecID>1</ExecID>'
    cBody += '<ID>-1</ID>'
    cBody += '<IsPriorityJob>false</IsPriorityJob>'
    cBody += '</JobID>'
    cBody += '<JobServerHostName xmlns="http://www.totvs.com/">RECN019403717</JobServerHostName>'
    cBody += '<MasterActionName xmlns="http://www.totvs.com/">FinLanAction</MasterActionName>'
    cBody += '<MaximumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1000</MaximumQuantityOfPrimaryKeysPerProcess>'
    cBody += '<MinimumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1</MinimumQuantityOfPrimaryKeysPerProcess>'
    cBody += '<NetworkUser xmlns="http://www.totvs.com/">rimeson.pereira</NetworkUser>'
    cBody += '<NotifyEmail xmlns="http://www.totvs.com/">false</NotifyEmail>'
    cBody += '<NotifyEmailList i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays" />'
    cBody += '<NotifyFluig xmlns="http://www.totvs.com/">false</NotifyFluig>'
    cBody += '<OnlineMode xmlns="http://www.totvs.com/">false</OnlineMode>'
    cBody += '<PrimaryKeyList xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<a:ArrayOfanyType>'
    cBody += '<a:anyType i:type="b:short" xmlns:b="http://www.w3.org/2001/XMLSchema">1</a:anyType>'
    cBody += '<a:anyType i:type="b:int" xmlns:b="http://www.w3.org/2001/XMLSchema">4732</a:anyType>'
    cBody += '</a:ArrayOfanyType>'
    cBody += '</PrimaryKeyList>'
    cBody += '<PrimaryKeyNames xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<a:string>CODCOLIGADA</a:string>'
    cBody += '<a:string>IDLAN</a:string>'
    cBody += '</PrimaryKeyNames>'
    cBody += '<PrimaryKeyTableName xmlns="http://www.totvs.com/">FLAN</PrimaryKeyTableName>'
    cBody += '<ProcessName xmlns="http://www.totvs.com/">Cancelamento de Baixa</ProcessName>'
    cBody += '<QuantityOfSplits xmlns="http://www.totvs.com/">0</QuantityOfSplits>'
    cBody += '<SaveLogInDatabase xmlns="http://www.totvs.com/">true</SaveLogInDatabase>'
    cBody += '<SaveParamsExecution xmlns="http://www.totvs.com/">false</SaveParamsExecution>'
    cBody += '<ScheduleDateTime xmlns="http://www.totvs.com/">2024-02-06T10:06:28.4839973-03:00</ScheduleDateTime>'
    cBody += '<Scheduler xmlns="http://www.totvs.com/">JobMonitor</Scheduler>'
    cBody += '<SendMail xmlns="http://www.totvs.com/">false</SendMail>'
    cBody += '<ServerName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoData</ServerName>'
    cBody += '<ServiceInterface i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.datacontract.org/2004/07/System" />'
    cBody += '<ShouldParallelize xmlns="http://www.totvs.com/">false</ShouldParallelize>'
    cBody += '<ShowReExecuteButton xmlns="http://www.totvs.com/">true</ShowReExecuteButton>'
    cBody += '<StatusMessage i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<SuccessMessage xmlns="http://www.totvs.com/">Processo executado com sucesso</SuccessMessage>'
    cBody += '<SyncExecution xmlns="http://www.totvs.com/">false</SyncExecution>'
    cBody += '<UseJobMonitor xmlns="http://www.totvs.com/">true</UseJobMonitor>'
    cBody += '<UserName xmlns="http://www.totvs.com/">' + cUser + '</UserName>'
    cBody += '<WaitSchedule xmlns="http://www.totvs.com/">false</WaitSchedule>'
    cBody += '<CodColCxaCaixa>-1</CodColCxaCaixa>'
    cBody += '<CodCxaCaixa />'
    cBody += '<CodSistema>F</CodSistema>'
    cBody += '<DataCaixa>0001-01-01T00:00:00</DataCaixa>'
    cBody += '<DataCancelamento>' + ( FWTimeStamp(3, dDataBase , Time())  )+ '</DataCancelamento>'
    cBody += '<DataSistema>' + ( FWTimeStamp(3, dDataBase , Time())  )+ '</DataSistema>'
    cBody += '<DescompensarExtratoLanctoPagar>false</DescompensarExtratoLanctoPagar>'
    cBody += '<DescompensarExtratoLanctoReceber>false</DescompensarExtratoLanctoReceber>'
    cBody += '<Historico>Referente a estorno de [OPE] ref. "[REF]"</Historico>'
    cBody += '<IdSessaoCaixa>-1</IdSessaoCaixa>'
    cBody += '<IsAdyen>false</IsAdyen>'
    cBody += '<IsModuloDeCaixa>false</IsModuloDeCaixa>'
    cBody += '<ListIdlanIdBaixa>'
    cBody += '<FinLanBaixaPKPar z:Id="i3">'
    cBody += '<InternalId i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<ServicoAlteracaoRepasse>false</ServicoAlteracaoRepasse>'
    cBody += '<CodColigada>'+ cCodEmp +'</CodColigada>'
    cBody += '<IdBaixa>'+ pIDBaixa +'</IdBaixa>'
    cBody += '<IdLan>'+ pIDLan +'</IdLan>'
    cBody += '<IdTransacao>0</IdTransacao>'
    cBody += '</FinLanBaixaPKPar>'
    cBody += '</ListIdlanIdBaixa>'
    cBody += '<ListLanEstornar />'
    cBody += '<ListNaoContabeis />'
    cBody += '<ListaBaixasEstornadas />'
    cBody += '<Origem>Default</Origem>' 
    cBody += '<TipoCancelamentoBaixaExtrato>CancelaSomenteItensSelecionados</TipoCancelamentoBaixaExtrato>'
    cBody += '<TransacoesSiTef i:nil="true" />'
    cBody += '<TransacoesTPD i:nil="true" />'
    cBody += '<Usuario>' + cUser + '</Usuario>'
    cBody += '</FinLanCancelamentoBaixaParamsProc>]]>'
    cBody += '</tot:strXmlParams>'
    cBody += '</tot:ExecuteWithXmlParams>'
    cBody += '</soapenv:Body>'
    cBody += '</soapenv:Envelope>'

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("ExecuteWithXmlParams")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog('FinLanBaixaCancelamentoData',cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Cancela Baixa: '+pIDBaixa,"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        cBody := AllTrim(cBody)

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog('FinLanBaixaCancelamentoData',cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Cancela Baixa: '+pIDBaixa,"2","ERRO")
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog('FinLanBaixaCancelamentoData',cBody,cResult,oXML:Error(),'Erro Cancela Baixa: '+pIDBaixa,"2","ERRO")
            Else
                IF oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult') <> '1'
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog('FinLanBaixaCancelamentoData',cBody,"",cResult,'Erro Cancela Baixa: '+pIDBaixa,"2","ERRO")
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                    u_fnGrvLog('FinLanBaixaCancelamentoData',cBody,cResult,"",'Cancela Baixa: '+pIDBaixa,"5","CANCELAMENTO")
                    lRet := .T.
                EndIF
            Endif

        EndIf
    EndIF

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fCanMovim
Realiza o cancelamento do Movimento no RM
/*/
//-----------------------------------------------------------------------------

User Function fCanMovim(pIDMov,pNumMov)
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsProcess/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""

    Default lRet := .F.

    cBody := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/">'
    cBody += '<soapenv:Header/>'
    cBody += '<soapenv:Body>'
    cBody += '<tot:ExecuteWithXmlParams>'
    cBody += '<tot:ProcessServerName>MovCancelMovProc</tot:ProcessServerName>'
    cBody += '<tot:strXmlParams><![CDATA[<?xml version="1.0" encoding="utf-16"?>'
    cBody += '<MovCancelMovProcParams z:Id="i1" xmlns="http://www.totvs.com.br/RM/" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" xmlns:z="http://schemas.microsoft.com/2003/10/Serialization/">'
    cBody += '<ActionModule xmlns="http://www.totvs.com/">T</ActionModule>'
    cBody += '<ActionName xmlns="http://www.totvs.com/">MovCancelMovProcAction</ActionName>'
    cBody += '<CanParallelize xmlns="http://www.totvs.com/">true</CanParallelize>'
    cBody += '<CanSendMail xmlns="http://www.totvs.com/">false</CanSendMail>'
    cBody += '<CanWaitSchedule xmlns="http://www.totvs.com/">false</CanWaitSchedule>'
    cBody += '<CodUsuario xmlns="http://www.totvs.com/">' + cUser + '</CodUsuario>'
    cBody += '<ConnectionId i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<ConnectionString i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<Context z:Id="i2" xmlns="http://www.totvs.com/" xmlns:a="http://www.totvs.com.br/RM/">'
    cBody += '<a:_params xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EXERCICIOFISCAL</b:Key> '
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">2</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODLOCPRT</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODTIPOCURSO</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EDUTIPOUSR</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUNIDADEBIB</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody += '</b:KeyValueOfanyTypeanyType> '
    cBody += '<b:KeyValueOfanyTypeanyType> '
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODCOLIGADA</b:Key> '
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">20</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$RHTIPOUSR</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODIGOEXTERNO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODSISTEMA</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">T</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIOSERVICO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema" />'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">' + cUser + '</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$IDPRJ</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CHAPAFUNCIONARIO</b:Key>'
    cBody += '<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '<b:KeyValueOfanyTypeanyType>'
    cBody += '<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODFILIAL</b:Key>'
    cBody += '<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value>'
    cBody += '</b:KeyValueOfanyTypeanyType>'
    cBody += '</a:_params>'
    cBody += '<a:Environment>DotNet</a:Environment>'
    cBody += '</Context>'
    cBody += '<CustomData i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<DisableIsolateProcess xmlns="http://www.totvs.com/">false</DisableIsolateProcess>'
    cBody += '<DriverType i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<ExecutionId xmlns="http://www.totvs.com/">703d5e78-80be-4ed5-8b33-49280422d547</ExecutionId>'
    cBody += '<FailureMessage xmlns="http://www.totvs.com/">Falha na execucao do processo</FailureMessage>'
    cBody += '<FriendlyLogs i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<HideProgressDialog xmlns="http://www.totvs.com/">false</HideProgressDialog>'
    cBody += '<HostName xmlns="http://www.totvs.com/">SERVIDOR</HostName>'
    cBody += '<Initialized xmlns="http://www.totvs.com/">true</Initialized>'
    cBody += '<Ip xmlns="http://www.totvs.com/">127.0.0.1</Ip>'
    cBody += '<IsolateProcess xmlns="http://www.totvs.com/">false</IsolateProcess>'
    cBody += '<JobID xmlns="http://www.totvs.com/">'
    cBody += '<Children/>'
    cBody += '<ExecID>1</ExecID>'
    cBody += '<ID>-1</ID>'
    cBody += '<IsPriorityJob>false</IsPriorityJob>'
    cBody += '</JobID>'
    cBody += '<JobServerHostName xmlns="http://www.totvs.com/">145873-core-instance-N-RM-D-C24LVE-1-0c72eWIN-CE01</JobServerHostName>'
    cBody += '<MasterActionName xmlns="http://www.totvs.com/">MovMovimentoMDIAction</MasterActionName>'
    cBody += '<MaximumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1000</MaximumQuantityOfPrimaryKeysPerProcess>'
    cBody += '<MinimumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1</MinimumQuantityOfPrimaryKeysPerProcess>'
    cBody += '<NetworkUser xmlns="http://www.totvs.com/">' + cUser + '</NetworkUser>'
    cBody += '<NotifyEmail xmlns="http://www.totvs.com/">false</NotifyEmail>'
    cBody += '<NotifyEmailList i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays" />'
    cBody += '<NotifyFluig xmlns="http://www.totvs.com/">false</NotifyFluig>'
    cBody += '<OnlineMode xmlns="http://www.totvs.com/">false</OnlineMode>'
    cBody += '<PrimaryKeyList xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<a:ArrayOfanyType>'
    cBody += '<a:anyType i:type="b:short" xmlns:b="http://www.w3.org/2001/XMLSchema">20</a:anyType>'
    cBody += '<a:anyType i:type="b:int" xmlns:b="http://www.w3.org/2001/XMLSchema">659146</a:anyType>'
    cBody += '</a:ArrayOfanyType>'
    cBody += '</PrimaryKeyList>'
    cBody += '<PrimaryKeyNames xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
    cBody += '<a:string>CODCOLIGADA</a:string>'
    cBody += '<a:string>IDMOV</a:string>'
    cBody += '</PrimaryKeyNames>'
    cBody += '<PrimaryKeyTableName xmlns="http://www.totvs.com/">TMOV</PrimaryKeyTableName>'
    cBody += '<ProcessName xmlns="http://www.totvs.com/">Cancelamento do Movimento</ProcessName>'
    cBody += '<QuantityOfSplits xmlns="http://www.totvs.com/">0</QuantityOfSplits>'
    cBody += '<SaveLogInDatabase xmlns="http://www.totvs.com/">true</SaveLogInDatabase>'
    cBody += '<SaveParamsExecution xmlns="http://www.totvs.com/">false</SaveParamsExecution>'
    cBody += '<ScheduleDateTime xmlns="http://www.totvs.com/">2024-02-06T15:35:43.7507458-03:00</ScheduleDateTime>'
    cBody += '<Scheduler xmlns="http://www.totvs.com/">JobMonitor</Scheduler>'
    cBody += '<SendMail xmlns="http://www.totvs.com/">false</SendMail>'
    cBody += '<ServerName xmlns="http://www.totvs.com/">MovCancelMovProc</ServerName>'
    cBody += '<ServiceInterface i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.datacontract.org/2004/07/System" />'
    cBody += '<ShouldParallelize xmlns="http://www.totvs.com/">false</ShouldParallelize>'
    cBody += '<ShowReExecuteButton xmlns="http://www.totvs.com/">true</ShowReExecuteButton>'
    cBody += '<StatusMessage i:nil="true" xmlns="http://www.totvs.com/" />'
    cBody += '<SuccessMessage xmlns="http://www.totvs.com/">Processo executado com sucesso</SuccessMessage>'
    cBody += '<SyncExecution xmlns="http://www.totvs.com/">false</SyncExecution>'
    cBody += '<UseJobMonitor xmlns="http://www.totvs.com/">true</UseJobMonitor>'
    cBody += '<UserName xmlns="http://www.totvs.com/">' + cUser + '</UserName>'
    cBody += '<WaitSchedule xmlns="http://www.totvs.com/">false</WaitSchedule>'
    cBody += '<MovimentosACancelar>'
    cBody += '<MovimentosCancelar z:Id="i3">'
    cBody += '<ApagarMovRelac>false</ApagarMovRelac>'
    cBody += '<CancelarMovimentosGeradosSimultFaturamento>false</CancelarMovimentosGeradosSimultFaturamento>'
    cBody += '<CancelarMovimentosGeradosSimultReabriCotacao>false</CancelarMovimentosGeradosSimultReabriCotacao>'
    cBody += '<CodColigada>'+ cCodEmp +'</CodColigada>'
    cBody += '<CodSistemaLogado>T</CodSistemaLogado>'
    cBody += '<CodUsuarioLogado>' + cUser + '</CodUsuarioLogado>'
    cBody += '<DataCancelamento>' + ( FWTimeStamp(3, dDataBase , Time())  )+ '</DataCancelamento>'
    cBody += '<ExcluirItensDaCotacao>false</ExcluirItensDaCotacao>'
    cBody += '<IdExercicioFiscal>2</IdExercicioFiscal>'
    cBody += '<IdMov>' + pIDMov + '</IdMov>'
    cBody += '<MotivoCancelamento>CANCELAMENTO DO MOVIMENTO</MotivoCancelamento>'
    cBody += '<NumeroMov>' + pNumMov + '</NumeroMov>'
    cBody += '</MovimentosCancelar>'
    cBody += '</MovimentosACancelar>'
    cBody += '</MovCancelMovProcParams>]]>'
    cBody += '</tot:strXmlParams>'
    cBody += '</tot:ExecuteWithXmlParams>'
    cBody += '</soapenv:Body>'
    cBody += '</soapenv:Envelope>'

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("ExecuteWithXmlParams")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog('MovCancelMovProc',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Cancela Documento: '+pIDMov,"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        cBody := AllTrim(cBody)

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog('MovCancelMovProc',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Cancela Documento: '+pIDMov,"2","ERRO")
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog('MovCancelMovProc',cBody,"",oXML:Error(),'Erro Cancela Documento: '+pIDMov,"2","ERRO")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                IF oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult') <> '1'
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog('MovCancelMovProc',cBody,"",cResult,'Erro Cancela Documento: '+pIDMov,"2","ERRO")
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                    u_fnGrvLog('MovCancelMovProc',cBody,cResult,"",'Cancela Documento: '+pIDMov,"5","CANCELAMENTO")
                    lRet := .T.
                EndIF 
            
            Endif

        EndIf
    EndIF

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fnConsultBX
Envelope de consulta RealizarConsultaSQL no RM
/*/
//-----------------------------------------------------------------------------

User Function fnConsultBX(pIDMov)

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRetAux   := {}
    Local aRet      := {}
    Local nY 

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>wsConsultaBaixa</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';IDMOV_N='+pIDMov+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog('wsConsultaBaixa',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta Baixa ID Mov: "+ pIDMov,"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog('wsConsultaBaixa',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta Baixa ID Mov: "+ pIDMov,"2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRetAux := {}
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:IDMOV'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:IDLAN'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:IDBAIXA'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:NUMEROMOV'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:DATAVENCIMENTO'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:CODCOLCXA'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:CODCXA'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:IDFORMAPAGTO'))
                    aAdd(aRetAux, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']'+'/ns1:VALORORIGINAL'))
                    aAdd(aRet,aRetAux)
                Next

                u_fnGrvLog('wsConsultaBaixa',cBody,cResult,"","Consulta Baixa ID Mov: "+ pIDMov,"1","CONSULTA")
            Endif

        EndIf
    EndIF 
    
Return aRet

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fBaixaFin
Realiza baixa financeira no RM
/*/
//-----------------------------------------------------------------------------

User Function fBaixaFin(cIDMOV)
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsProcess/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aBaixa    := {}
    Local cIDLan    := ""
    Local dDataVenc := CToD("//")
    Local cHoraVenc := ""
    Local cCodCX    := ""
    Local cCodColCX := ""
    Local cIDFormPg := ""
    Local cValor    := ""
    Local nY 

    Default lRet    := .F.
    Default cIDMOV  := "" 

    aBaixa := u_fnConsultBX(AllTrim(cIDMOV))

    IF Len(aBaixa) <= 0
        Return
    EndIF 

    For nY := 1 To Len(aBaixa)

        IF aBaixa[nY][3] == '0'

            cIDLan      := aBaixa[nY][2]
            dDataVenc   := CToD(SubStr(aBaixa[nY][5],9,2)+"/"+SubStr(aBaixa[nY][5],6,2)+"/"+SubStr(aBaixa[nY][5],1,4))
            cHoraVenc   := SubStr(aBaixa[nY][5],12)
            cCodColCX   := aBaixa[nY][6]
            cCodCX      := aBaixa[nY][7]
            cIDFormPg   := aBaixa[nY][8]
            cValor      := aBaixa[nY][9]

            cBody := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/">'
            cBody += '<soapenv:Header/>'
            cBody += '<soapenv:Body>'
            cBody += '<tot:ExecuteWithXmlParams>'
            cBody += '<tot:ProcessServerName>FinLanBaixaTBCData</tot:ProcessServerName>'
            cBody += '<tot:strXmlParams>'
            cBody += '<![CDATA[<?xml version="1.0" encoding="utf-16"?>'
            cBody += '<FinLanBaixaTBCParamsProc xmlns:i="http://www.w3.org/2001/XMLSchema-instance" z:Id="i1" xmlns:z="http://schemas.microsoft.com/2003/10/Serialization/" xmlns="http://www.totvs.com.br/RM/">'
            cBody += '<CodUsuario xmlns="http://www.totvs.com/">' + cUser + '</CodUsuario>'
            cBody += '<Context xmlns:d2p1="http://www.totvs.com.br/RM/" z:Id="i2" xmlns="http://www.totvs.com/">'
            cBody += '<d2p1:_params xmlns:d3p1="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$EXERCICIOFISCAL</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">2</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODLOCPRT</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODTIPOCURSO</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$EDUTIPOUSR</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODUNIDADEBIB</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODCOLIGADA</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">' + cCodEmp + '</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$RHTIPOUSR</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODIGOEXTERNO</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODSISTEMA</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">T</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODUSUARIOSERVICO</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string"></d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$IDPRJ</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CHAPAFUNCIONARIO</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">-1</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:KeyValueOfanyTypeanyType>'
            cBody += '<d3p1:Key xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:string">$CODFILIAL</d3p1:Key>'
            cBody += '<d3p1:Value xmlns:d5p1="http://www.w3.org/2001/XMLSchema" i:type="d5p1:int">' + cCodFil + '</d3p1:Value>'
            cBody += '</d3p1:KeyValueOfanyTypeanyType>'
            cBody += '</d2p1:_params>'
            cBody += '<d2p1:Environment>WebServices</d2p1:Environment>'
            cBody += '</Context>'
            cBody += '<PrimaryKeyList xmlns:d2p1="http://schemas.microsoft.com/2003/10/Serialization/Arrays" xmlns="http://www.totvs.com/">'
            cBody += '<d2p1:ArrayOfanyType>'
            cBody += '<d2p1:anyType xmlns:d4p1="http://www.w3.org/2001/XMLSchema" i:type="d4p1:int">0</d2p1:anyType>'
            cBody += '</d2p1:ArrayOfanyType>'
            cBody += '<d2p1:ArrayOfanyType>'
            cBody += '<d2p1:anyType xmlns:d4p1="http://www.w3.org/2001/XMLSchema" i:type="d4p1:decimal">0</d2p1:anyType>'
            cBody += '</d2p1:ArrayOfanyType>'
            cBody += '<d2p1:ArrayOfanyType>'
            cBody += '<d2p1:anyType xmlns:d4p1="http://www.w3.org/2001/XMLSchema" i:type="d4p1:string">TEXTO</d2p1:anyType>'
            cBody += '</d2p1:ArrayOfanyType>'
            cBody += '<d2p1:ArrayOfanyType>'
            cBody += '<d2p1:anyType xmlns:d4p1="http://www.w3.org/2001/XMLSchema" i:type="d4p1:dateTime">2024-09-16T00:00:00-03:00</d2p1:anyType>'
            cBody += '</d2p1:ArrayOfanyType>'
            cBody += '</PrimaryKeyList>'
            cBody += '<PrimaryKeyNames xmlns:d2p1="http://schemas.microsoft.com/2003/10/Serialization/Arrays" xmlns="http://www.totvs.com/">'
            cBody += '<d2p1:string>COLUNAPK</d2p1:string>'
            cBody += '</PrimaryKeyNames>'
            cBody += '<CodColigada>' + cCodEmp + '</CodColigada>'
            cBody += '<CodMoeda>R$</CodMoeda>'
            cBody += '<ContabilizarPosBaixa>false</ContabilizarPosBaixa>'
            cBody += '<CotacaoBaixa>0</CotacaoBaixa>'
            cBody += '<DataBaixa>'+ FWTimeStamp(3, dDataVenc, cHoraVenc) +'</DataBaixa>'
            cBody += '<DataSistema>'+ FWTimeStamp(3, dDataBase, Time()) +'</DataSistema>'
            cBody += '<HistoricoBaixa></HistoricoBaixa>'
            cBody += '<MotivoBxProtheus i:nil="true" />'
            cBody += '<TipoGeracaoExtrato>ExtratoParaCadaLancamento</TipoGeracaoExtrato>'
            cBody += '<UsarDataVencimentoBaixa>false</UsarDataVencimentoBaixa>'
            cBody += '<CodUsuario>' + cUser + '</CodUsuario>'
            cBody += '<IsMsgUnicaProtheusEai2>false</IsMsgUnicaProtheusEai2>'
            cBody += '<Pagamentos>'
            cBody += '<FinPagamentoBaixaTBCParamsProc>'
            cBody += '<LanctoParaBaixas/>'
            cBody += '<ListIdLan xmlns:d4p1="http://schemas.microsoft.com/2003/10/Serialization/Arrays">'
            cBody += '<d4p1:int>' + cIDLan + '</d4p1:int>'
            cBody += '</ListIdLan>'
            cBody += '<MeioPagamento>'
            cBody += '<Cartao/>'
            cBody += '<Cheque/>'
            cBody += '<CodColCxa>' + cCodColCX + '</CodColCxa>'
            cBody += '<CodColigada>' + cCodEmp + '</CodColigada>'
            cBody += '<CodCxa>' + cCodCX + '</CodCxa>'
            cBody += '<IdFormaPagto>' + cIDFormPg + '</IdFormaPagto>'
            cBody += '<Valor>' + cValor + '</Valor>'
            cBody += '</MeioPagamento>'
            cBody += '</FinPagamentoBaixaTBCParamsProc>'
            cBody += '</Pagamentos>'
            cBody += '<TipoGeracaoExtratoBaixa>ExtratoParaCadaLancamento</TipoGeracaoExtratoBaixa>'
            cBody += '<ValoresAlteracao/>'
            cBody += '</FinLanBaixaTBCParamsProc>]]>'
            cBody += '</tot:strXmlParams>'
            cBody += '</tot:ExecuteWithXmlParams>'
            cBody += '</soapenv:Body>'
            cBody += '</soapenv:Envelope>'

            oWsdl := TWsdlManager():New()
            oWsdl:nTimeout         := 120
            oWsdl:lSSLInsecure     := .T.
            oWsdl:lProcResp        := .T.
            oWsdl:bNoCheckPeerCert := .T.
            oWSDL:lUseNSPrefix     := .T.
            oWsdl:lVerbose         := .T.
            
            If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("ExecuteWithXmlParams")
                ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog('FinLanBaixaTBCData',cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Baixa: '+cIDLan,"2","ERRO")
            Else

                oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

                cBody := AllTrim(cBody)

                If !oWsdl:SendSoapMsg( cBody )
                    ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog('FinLanBaixaTBCData',cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),'Erro Baixa: '+cIDLan,"2","ERRO")
                Else
                    cResult := oWsdl:GetSoapResponse()
                    cResult := StrTran(cResult, "&lt;", "<")
                    cResult := StrTran(cResult, "&gt;&#xD;", ">")
                    cResult := StrTran(cResult, "&gt;", ">")
                    oXml := TXmlManager():New()

                    If !oXML:Parse( cResult )
                        ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                        u_fnGrvLog('FinLanBaixaTBCData',cBody,cResult,oXML:Error(),'Erro Baixa: '+cIDLan,"2","ERRO")
                    Else
                        oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                        oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                        IF oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult') != '1'
                            cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                            ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                            u_fnGrvLog('FinLanBaixaTBCData',cBody,"",cResult,'Erro Baixa: '+cIDLan,"2","ERRO")
                        Else
                            cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:ExecuteWithXmlParamsResponse/ns1:ExecuteWithXmlParamsResult')
                            u_fnGrvLog('FinLanBaixaTBCData',cBody,cResult,"",'Baixa: '+cIDLan,"8","BAIXA")
                            lRet := .T.
                        EndIF
                    Endif

                EndIf
            EndIF
        EndIF 
    Next 

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fInutNFCe
Realiza o cancelamento do Cupom no RM
/*/
//-----------------------------------------------------------------------------

User Function fInutNFCe()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath      := "/wsDataServer/MEX?wsdl"
    Local cBody      := ""
    Local cResult    := ""
    Local aInfMonNFe := {}
    Local cURLTss    := SuperGetMV("MV_NFCEURL",.F.,"")
    Local cIdEnt     := LjTSSIDENT( SLX->LX_MODDOC )
    Local cNFCeID    := SLX->LX_SERIE + SLX->LX_CUPOM
    Local lRetWS     := .F.
    Local cIDMovRet  := ""
    Local cXMLInut   := ""
    Local cProtInut  := ""
    Local cChvInut   := ""
    Local cAmbNFCe   := ""
    Local cChvNFe    := ""
    Local cEndPoint  := "FisNFeInutilizarData"
    Local cTitulo    := "Erro de Integração da Inutilização / Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE) + " com o TOTVS Corpore RM"

    Private oWS := Nil

    cIdEnt := LjTSSIDENT( SLX->LX_MODDOC )
    cNFCeID := SLX->LX_SERIE + SLX->LX_CUPOM

    oWS:= WSNFeSBRA():New()
    oWS:cUSERTOKEN := "TOTVS"
    oWS:cID_ENT := cIdEnt
    oWS:oWSNFEID := NFESBRA_NFES2():New()
    oWS:oWSNFEID:oWSNotas := NFESBRA_ARRAYOFNFESID2():New()
    aadd(oWS:oWSNFEID:oWSNotas:oWSNFESID2,NFESBRA_NFESID2():New())
    Atail(oWS:oWSNFEID:oWSNotas:oWSNFESID2):cID := cNFCeID
    oWS:nDIASPARAEXCLUSAO := 0
    oWS:_URL := AllTrim(cURLTss)+"/NFeSBRA.apw"

    lRetWS := oWS:RETORNANOTAS()
    
    If ValType(lRetWS) <> "L" .OR. !lRetWS
        
        FWAlertWarning(IIf(Empty(GetWscError(3)),GetWscError(1),GetWscError(3)),'Erro ao recuperar os dados da Inutilizacao')
    
    ElseIF oWs:oWsRetornaNotasResult:OWSNOTAS:oWSNFES3[1]:oWSNFECANCELADA <> Nil
        cXMLInut  := oWs:oWsRetornaNotasResult:OWSNOTAS:oWSNFES3[1]:oWSNFECANCELADA:cXML
        cProtInut := oWs:oWsRetornaNotasResult:OWSNOTAS:oWSNFES3[1]:oWSNFECANCELADA:cPROTOCOLO

        aInfMonNFe := ProcMonitorDoc(cIdEnt , cURLTss , {SLX->LX_SERIE, SLX->LX_CUPOM, SLX->LX_CUPOM} , 1 , SLX->LX_MODDOC , .F., @cChvNFe)

        IF Len(aInfMonNFe) > 0
            cAmbNFCe := cValToChar(aInfMonNFe[1][7])
            cChvNFe  := Substr(aInfMonNFe[1][17][02], At('Id="NFe',aInfMonNFe[1][17][02])+7, 44 )
        EndIF  
    EndIF 

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += ' 	<soapenv:Header/> '
    cBody += ' 	<soapenv:Body> '
    cBody += ' 		<tot:SaveRecord> '
    cBody += ' 			<tot:DataServerName>FisNFeInutilizarData</tot:DataServerName> '
    cBody += ' 			<tot:XML><![CDATA[<FisNFeInutilizar> '
    cBody += ' 					  <DNFEINUT> '
    cBody += ' 						<CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += ' 						<IDENTIFICADOR>-1</IDENTIFICADOR> '
    cBody += ' 						<CODFILIAL>' + cCodFil + '</CODFILIAL> '
    cBody += ' 						<SERIE>' + AllTrim(SLX->LX_SERIE) + '</SERIE> '
    cBody += ' 						<NUMDOC>' + AllTrim(SLX->LX_CUPOM) + '</NUMDOC> '
    cBody += ' 						<DATA>' + FWTimeStamp(3, SLX->LX_DTMOVTO , SLX->LX_HORA) + '</DATA> '
    cBody += ' 						<MODELO>' + AllTrim(SLX->LX_MODDOC) + '</MODELO> '
    cBody += ' 						<AMBIENTE>' + cAmbNFCe + '</AMBIENTE> '
    cBody += ' 						<OBSERVACAO>O documento numero: ' + AllTrim(SLX->LX_CUPOM) + ' nao sera utilizado pelo ERP</OBSERVACAO> '
    cBody += ' 						<PROTOCOLO>' + cProtInut + '</PROTOCOLO> '
    cBody += ' 						<XMLINUT>' + cXMLInut + '</XMLINUT> '
    cBody += ' 						<STATUS>N</STATUS> '
    cBody += ' 						<CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += ' 						<MSGSEFAZ>Cancelamento de NFC-e por emissao indevida, sem transmissao a SEFAZ</MSGSEFAZ> '
    cBody += ' 						<CHAVEACESSONFE>' + cChvInut + '</CHAVEACESSONFE> '
    cBody += ' 					  </DNFEINUT> '
    cBody += ' 					</FisNFeInutilizar>]]> '
    cBody += ' 			</tot:XML> '
    cBody += ' 			<tot:Contexto>CODCOLIGADA=' + cCodEmp + ';CODSISTEMA=T</tot:Contexto> '
    cBody += ' 		</tot:SaveRecord> '
    cBody += ' 	</soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("SaveRecord")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"Erro - Inutilizacao do Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE),"2","ERRO")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"Erro - Inutilizacao do Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE),"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"Erro - Inutilizacao do Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE),"2","ERRO")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                IF Len(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')) < 15 
                    cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                        At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                Else
                    cResult := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')
                EndIF 
                
                If !Empty(cIDMovRet)
                    RecLock("SLX",.F.)
                        SLX->LX_XIDMOV := cIDMovRet
                        SLX->LX_XINT_RM := "S"
                    SLX->(MSUnlock())
                    u_fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),"Inutilizacao do Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE),"6","ENVIO")
                Else
                    
                    If !Empty(cIDMovRet)
                        RecLock("SF1",.F.)
                            SF1->F1_XIDMOV := cIDMovRet
                            SF1->F1_XINT_RM := "S"
                        SF1->(MSUnlock())
                        u_fEnvMail("RM1",cTitulo,cResult)
                    EndIF

                    ApMsgAlert(cResult,"Erro Integracao TOTVS Corpore RM")
                    u_fnGrvLog(cEndPoint,cBody,"",cResult,"Erro - Inutilizacao do Cupom: "+AllTrim(SLX->LX_CUPOM) + " - Serie: "+ AllTrim(SLX->LX_SERIE),"2","ERRO")
                EndIF 
            Endif

        EndIf
    EndIF 
    
Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} wsNumeroMOV
Envelope de consulta RealizarConsultaSQL no RM
/*/
//-----------------------------------------------------------------------------
Static Function wsNumeroMOV()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cIDMovRet := ""

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>wsNumeroMOV</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA_N='+cCodEmp+';CODFILIAL_N='+cCodFil+';CODCFO_S='+AllTrim(SL1->L1_CLIENTE)+';NUMEROMOV_S='+Alltrim(SL1->L1_DOC)+';SERIE_S='+Alltrim(SL1->L1_SERIE)+'</tot:parameters> '
    cBody += '      </tot:RealizarConsultaSQL> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            u_fnGrvLog('wsNumeroMOV',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta ID Mov da NFC-e: " + Alltrim(SL1->L1_DOC) + " Serie: " + Alltrim(SL1->L1_SERIE),"2","ERRO")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                u_fnGrvLog('wsNumeroMOV',cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta ID Mov da NFC-e: " + Alltrim(SL1->L1_DOC) + " Serie: " + Alltrim(SL1->L1_SERIE),"2","ERRO")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                cIDMovRet := oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:IDMOV')

                u_fnGrvLog('wsNumeroMOV',cBody,cResult,"","Consulta ID Mov da NFC-e: " + Alltrim(SL1->L1_DOC) + " Serie: " + Alltrim(SL1->L1_SERIE),"1","CONSULTA")
            Endif

        EndIf
    EndIF 
    
Return cIDMovRet

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvMail
Envia e-mail através do Event View do Protheus
/*/
//-----------------------------------------------------------------------------

User Function fEnvMail(pEventID,pTitulo,pMesagem)

    Local cEventID  := pEventID //Evento cadastrado na tabela E3
    Local cTitulo   := pTitulo  //Título da Mensagem enviada por e-mail
    Local cMesagem  := pMesagem //Mensagem enviada no corpo do e-mail

    EventInsert(FW_EV_CHANEL_ENVIRONMENT, FW_EV_CATEGORY_MODULES, cEventID,FW_EV_LEVEL_INFO,"",cTitulo,cMesagem,.T.)

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fnGrvLog
Grava o LOG de integracao na tabela SZ1 - Log de integracao Protheus x RM
/*/
//-----------------------------------------------------------------------------

User Function fnGrvLog(pEndPoint,pBody,pResult,pErro,pDocto,pOper,pDscOper)
    Local cIdLog  := ""
    Local _cAlias := GetNextAlias()

    Default pEndPoint := ""
    Default pBody     := ""
    Default pResult   := ""
    Default pErro     := ""
    Default pDocto    := ""
    Default pOper     := ""
    Default pDscOper  := ""

    BeginSql Alias _cAlias
        SELECT MAX(Z1_ID) Z1_ID
        FROM %table:SZ1% SZ1
        WHERE Z1_FILIAL = %xFilial:SZ1%
            AND SZ1.%NotDel%
    EndSql
    cIdLog := IIF(!Empty((_cAlias)->Z1_ID),Soma1((_cAlias)->Z1_ID),StrZero(1,FWTamSX3("Z1_ID")[1]))
    (_cAlias)->(dbCloseArea())

    Reclock("SZ1",.T.)
        Replace SZ1->Z1_FILIAL  with xFilial("SZ1")
		Replace SZ1->Z1_ID      with cIdLog
        Replace SZ1->Z1_FILDEST with cFilAnt
        Replace SZ1->Z1_DATA    with dDataBase
        Replace SZ1->Z1_HORA    with Time()
        Replace SZ1->Z1_ROTINA  with FunName()
        Replace SZ1->Z1_DESC    with pEndPoint
        Replace SZ1->Z1_DOCTO   with pDocto
        Replace SZ1->Z1_OPERACA with pOper
        Replace SZ1->Z1_DSCOPER with pDscOper
        Replace SZ1->Z1_MENSAG  with IIF(!Empty(pErro),pErro,pResult)
        Replace SZ1->Z1_STATUS  with IIF(!Empty(pResult),"S","E")
        Replace SZ1->Z1_ARQJSON with pBody
    SZ1->(MsUnlock())

Return
