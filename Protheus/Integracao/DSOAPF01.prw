#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"
#Include 'FWMVCDef.ch'

//-----------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} DSOAPF01
User Function: DSOAPF01 - Função para Integração Via SOAP com o TOTVS Corpore RM
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 19/06/2024
@Permite
Programa Fonte
/*/
User Function DSOAPF01(pCodProd,pLocPad,pEndpoint)
    Local aArea := FWGetArea()
    
    Private cUrl      := SuperGetMV("MV_XURLRM" ,.F.,"https://associacaodas145873.rm.cloudtotvs.com.br:1801")
    Private cUser     := SuperGetMV("MV_XRMUSER",.F.,"rimeson")
    Private cPass     := SuperGetMV("MV_XRMPASS",.F.,"123456")
    Private cDiasInc  := SuperGetMV("MV_XDINCRM",.F.,"-10")
    Private cDiasAlt  := SuperGetMV("MV_XDALTRM",.F.,"0")
    Private cCodEmp   := ""
    Private cCodFil   := ""
    Private cPicVal   := PesqPict( "SL1", "L1_VALBRUT")
    Private cEndPoint := pEndpoint

    DBSelectArea("XXD")
    XXD->(DBSetOrder(3))
    If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
        cCodEmp := XXD->XXD_COMPA
        cCodFil := XXD->XXD_BRANCH
    Else 
        ApMsgStop("Coligada + Filial não encontrada no De/Para." + CRLF + CRLF +;
                  "Por favor acessar a rotina De/Para de Empresas Mensagem Unica (APCFG050), no SIGACFG e cadastrar o De/Para." + CRLF + ;
                  "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
        lErIntRM := .T.
        Return
    EndIF 

    FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Inicio da Integracao com o Corpore RM no Endpoint: '+ cEndPoint +' ===')

        Do Case 
            Case cEndPoint == 'wsCliFor'
                fwsCliFor()
            
            Case cEndPoint == 'wsCliForResumo'
                fwsCliForR()

            Case cEndPoint == 'wsProdutos'
                fwsProdutos()
            
            Case cEndPoint == 'wsTabPreco'
                fwsTabPreco()

            Case cEndPoint == 'wsPontoVenda'
                fwsPontoVenda()
            
            Case cEndPoint == 'wsPrdCodBarras'
                fwsPrdCodBarras()
            
            Case cEndPoint == 'wsVendedor'
                fwsVendedor()

            Case cEndPoint == 'wsTprdLoc'
                fwsTprdLoc(pCodProd,pLocPad)
            
            Case cEndPoint == 'MovMovCopiaReferenciaData'
                fEnvNFeDev()
            
            Case cEndPoint == 'MovMovimentoTBCData'
                fEnvNFeVend()
            
            Case cEndPoint == 'FinLanBaixaCancelamentoData'
                fCanFinan()

            Case cEndPoint == 'MovCancelMovProc'
                fCanMovim()

        End Case 

    FwLogMsg("INFO", , "REST", FunName(), "", "01", '===  Fim da Integracao com o Corpore RM no Endpoint: '+ cEndPoint +' === ')
    
    FWRestArea(aArea)

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsCliFor
Realiza a consulta de clientes através da API padrão RealizarConsultaSQL no RM (Completo)
/*/
//------------------------------------------------------------------------------------------

Static Function fwsCliFor()

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
    cBody += '          <tot:parameters>CODCOLIGADA_N=0;ATIVO_N=1;CODCFO_S=TODOS;CGCCFO_S=TODOS;NOMEFANTASIA_S=TODOS; PAGREC_N=1;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SA1")
                DBSelectArea("SYA")
                SYA->(DBSetOrder(2))
                DBSelectArea("CCH")
                CCH->(DBSetOrder(2))

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

                        oModel := FWLoadModel("CRMA980")
                        IF ! SA1->(MsSeek(xFilial("SA1")+aRegXML[2,3]))
                            nOpc := 3
                            oModel:SetOperation(nOpc)
                        Else
                            nOpc := 4
                            oModel:SetOperation(nOpc)
                        EndIF 
                        oModel:Activate()
                        oSA1Mod:= oModel:getModel("SA1MASTER")

                        aRegXML[05][03] := StrTran(aRegXML[05][03],".","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"-","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"/","")

                        aRegXML[14][03] := StrTran(aRegXML[05][03],"-","")

                        oSA1Mod:setValue("A1_COD"    ,aRegXML[02][03]                               ) // Codigo
                        oSA1Mod:setValue("A1_LOJA"   ,"01"                                          ) // Loja
                        oSA1Mod:setValue("A1_PESSOA" ,aRegXML[49][03]                               ) // Pessoa Fisica/Juridica
                        oSA1Mod:setValue("A1_TIPO"   ,"F"                                           ) // Tipo do Cliente (F=Cons.Final;L=Produtor Rural;R=Revendedor;S=Solidario;X=Exportacao)
                        oSA1Mod:setValue("A1_CGC"    ,aRegXML[05][03]                               ) // CNPJ/CPF
                        oSA1Mod:setValue("A1_INSCR"  ,aRegXML[06][03]                               ) // Inscricao Estadual
                        oSA1Mod:setValue("A1_NOME"   ,aRegXML[04][03]                               ) // Nome
                        oSA1Mod:setValue("A1_NREDUZ" ,Pad(aRegXML[03][03],FWTamSX3("A1_NREDUZ")[1]) ) // Nome Fantasia
                        oSA1Mod:setValue("A1_END"    ,aRegXML[08][03] + ", " + aRegXML[09][03]      ) // Endereco + Número
                        oSA1Mod:setValue("A1_COMPENT",aRegXML[10][03]                               ) // Complemento
                        oSA1Mod:setValue("A1_BAIRRO" ,aRegXML[11][03]                               ) // Bairro
                        oSA1Mod:setValue("A1_CEP"    ,aRegXML[14][03]                               ) // CEP
                        oSA1Mod:setValue("A1_EST"    ,aRegXML[13][03]                               ) // Estado
                        oSA1Mod:setValue("A1_COD_MUN",aRegXML[43][03]                               ) // Municipio
                        oSA1Mod:setValue("A1_MUN"    ,aRegXML[12][03]                               ) // Municipio
                        oSA1Mod:setValue("A1_TEL"    ,aRegXML[15][03]                               ) // Telefone
                        oSA1Mod:setValue("A1_FAX"    ,aRegXML[16][03]                               ) // Numero do FAX
                        oSA1Mod:setValue("A1_TELEX"  ,aRegXML[17][03]                               ) // Telex
                        oSA1Mod:setValue("A1_EMAIL"  ,aRegXML[18][03]                               ) // E-mail
                        oSA1Mod:setValue("A1_CONTATO",aRegXML[19][03]                               ) // Contato
                        oSA1Mod:setValue("A1_LC"     ,Val(aRegXML[22][03])                          ) // Limite de Credito
                        oSA1Mod:setValue("A1_MSBLQL" ,IIF(aRegXML[21][03]=="1","2","1")             ) // Status (Ativo ou Inativo)
                        If !Empty(Upper(aRegXML[52][03])) .And. SYA->(MSSeek(xFilial("SYA")+Upper(aRegXML[52][03])))
                            oSA1Mod:LoadValue("A1_PAIS"   ,SYA->YA_CODGI                            ) // Codigo do País
                        EndIF
                        If !Empty(Upper(aRegXML[52][03])) .And. CCH->(MSSeek(xFilial("CCH")+Upper(aRegXML[52][03])))
                            oSA1Mod:LoadValue("A1_CODPAIS",Alltrim(CCH->CCH_CODIGO)                 ) // Codigo do País Bacen.
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
                            fnGrvLog(cEndPoint,cBody,cResult,cErro,"Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
                        Else
                            fnGrvLog(cEndPoint,cBody,cResult,,"Erro Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
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
/*/{Protheus.doc} fwsCliForR
Realiza a consulta de clientes através da API padrão RealizarConsultaSQL no RM (Resumido)
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
    cBody += '          <tot:parameters>CODCOLIGADA_N=0;ATIVO_N=1;CODCFO_S=TODOS;CGCCFO_S=TODOS;NOMEFANTASIA_S=TODOS; PAGREC_N=1;CRIACAO_N='+cDiasInc+';ALTERACAO_N='+cDiasAlt+'</tot:parameters> '
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Clientes","2","Integracao Cliente")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SA1")
                DBSelectArea("SYA")
                SYA->(DBSetOrder(2))
                DBSelectArea("CCH")
                CCH->(DBSetOrder(2))

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

                        oModel := FWLoadModel("CRMA980")
                        IF ! SA1->(MsSeek(xFilial("SA1")+aRegXML[2,3]))
                            nOpc := 3
                            oModel:SetOperation(nOpc)
                        Else
                            nOpc := 4
                            oModel:SetOperation(nOpc)
                        EndIF 
                        oModel:Activate()
                        oSA1Mod:= oModel:getModel("SA1MASTER")

                        aRegXML[05][03] := StrTran(aRegXML[05][03],".","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"-","")
                        aRegXML[05][03] := StrTran(aRegXML[05][03],"/","")

                        aRegXML[14][03] := StrTran(aRegXML[05][03],"-","")

                        oSA1Mod:setValue("A1_COD"    ,aRegXML[02][03]                               ) // Codigo
                        oSA1Mod:setValue("A1_LOJA"   ,"01"                                          ) // Loja
                        oSA1Mod:setValue("A1_PESSOA" ,aRegXML[24][03]                               ) // Pessoa Fisica/Juridica
                        oSA1Mod:setValue("A1_TIPO"   ,"F"                                           ) // Tipo do Cliente (F=Cons.Final;L=Produtor Rural;R=Revendedor;S=Solidario;X=Exportacao)
                        oSA1Mod:setValue("A1_CGC"    ,aRegXML[05][03]                               ) // CNPJ/CPF
                        oSA1Mod:setValue("A1_INSCR"  ,aRegXML[06][03]                               ) // Inscricao Estadual
                        oSA1Mod:setValue("A1_NOME"   ,aRegXML[04][03]                               ) // Nome
                        oSA1Mod:setValue("A1_NREDUZ" ,Pad(aRegXML[03][03],FWTamSX3("A1_NREDUZ")[1]) ) // Nome Fantasia
                        oSA1Mod:setValue("A1_END"    ,aRegXML[08][03] + ", " + aRegXML[09][03]      ) // Endereco + Número
                        oSA1Mod:setValue("A1_COMPENT",aRegXML[10][03]                               ) // Complemento
                        oSA1Mod:setValue("A1_BAIRRO" ,aRegXML[11][03]                               ) // Bairro
                        oSA1Mod:setValue("A1_CEP"    ,aRegXML[14][03]                               ) // CEP
                        oSA1Mod:setValue("A1_EST"    ,aRegXML[13][03]                               ) // Estado
                        oSA1Mod:setValue("A1_COD_MUN",aRegXML[25][03]                               ) // Municipio
                        oSA1Mod:setValue("A1_MUN"    ,aRegXML[12][03]                               ) // Municipio
                        oSA1Mod:setValue("A1_TEL"    ,aRegXML[15][03]                               ) // Telefone
                        oSA1Mod:setValue("A1_FAX"    ,aRegXML[16][03]                               ) // Numero do FAX
                        oSA1Mod:setValue("A1_TELEX"  ,aRegXML[17][03]                               ) // Telex
                        oSA1Mod:setValue("A1_EMAIL"  ,aRegXML[18][03]                               ) // E-mail
                        oSA1Mod:setValue("A1_CONTATO",aRegXML[19][03]                               ) // Contato
                        oSA1Mod:setValue("A1_LC"     ,Val(aRegXML[20][03])                          ) // Limite de Credito
                        oSA1Mod:setValue("A1_MSBLQL" ,IIF(aRegXML[19][03]=="1","2","1")             ) // Status (Ativo ou Inativo)
                        If !Empty(Upper(aRegXML[23][03])) .And. SYA->(MSSeek(xFilial("SYA")+Upper(aRegXML[23][03])))
                            oSA1Mod:LoadValue("A1_PAIS"   ,SYA->YA_CODGI                            ) // Codigo do País
                        EndIF
                        If !Empty(Upper(aRegXML[23][03])) .And. CCH->(MSSeek(xFilial("CCH")+Upper(aRegXML[23][03])))
                            oSA1Mod:LoadValue("A1_CODPAIS",Alltrim(CCH->CCH_CODIGO)                 ) // Codigo do País Bacen.
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
                            fnGrvLog(cEndPoint,cBody,cResult,cErro,"Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
                        Else
                            fnGrvLog(cEndPoint,cBody,cResult,,"Erro Cliente: " + aRegXML[2,3] + " - " +aRegXML[4,3],cValToChar(nOpc),"Integracao Cliente")
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
Realiza a consulta de Produtos através da API padrão RealizarConsultaSQL no RM
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Produtos","2","Integracao Produtos")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SB1")
                DBSelectArea("SYA")
                SYA->(DBSetOrder(2))
                DBSelectArea("CCH")
                CCH->(DBSetOrder(2))

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

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

                        oSB1Mod:setValue("B1_COD"    ,aRegXML[04][03] ) // Codigo
                        oSB1Mod:setValue("B1_DESC"   ,aRegXML[09][03] ) // Descricao do Produto
                        oSB1Mod:setValue("B1_TIPO"   ,"ME"            ) // Tipo de Produto (MP,PA,.)
                        oSB1Mod:setValue("B1_UM"     ,aRegXML[59][03] ) // Unidade de Medida
                        oSB1Mod:setValue("B1_LOCPAD" ,"01"            ) // Armazem Padrao p/Requis.
                        oSB1Mod:setValue("B1_POSIPI" ,aRegXML[13][03] ) // Nomenclatura Ext.Mercosul
                        oSB1Mod:setValue("B1_ORIGEM" ,"0"             ) // Origem do Produto
                        oSB1Mod:setValue("B1_PESO"   ,aRegXML[16][03] ) // Peso Liquido
                        oSB1Mod:setValue("B1_PESBRU" ,aRegXML[17][03] ) // Peso Bruto

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
                            fnGrvLog(cEndPoint,cBody,cResult,cErro,"Produto: " + aRegXML[04][03] + " - " +aRegXML[09][03],cValToChar(nOpc),"Integracao Produto")
                        Else
                            fnGrvLog(cEndPoint,cBody,cResult,,"Erro Produto: " + aRegXML[04][03] + " - " +aRegXML[09][03],cValToChar(nOpc),"Integracao Produto")
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
Realiza a consulta da Tabela de Preço através da API padrão RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsTabPreco()

    Local oWsdl as Object
    Local oXml as Object  
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cErro     := ""
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao da Tabela de Preco","2","Integracao Tabela de Preco")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("DA0")
                DBSelectArea("DA1")

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

                        IF ! DA0->(MsSeek(xFilial("DA0") + StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1])))
                            nOpc := 3
                        Else
                            nOpc := 4
                        EndIF 
                        
                        aRegDA0 := {}
                        aRegDA1 := {}

                        aAdd(aRegDA0,{"DA0_CODTAB" , StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1]), Nil} ) // Codigo
                        aAdd(aRegDA0,{"DA0_DESCRI" , aRegXML[03][03]                                    , Nil} ) // Descricao
                        aAdd(aRegDA0,{"DA0_DATDE"  , FwDateTimeToLocal(aRegXML[12][03])[1]              , Nil} ) // Data Inicial
                        aAdd(aRegDA0,{"DA0_HORADE" , FwDateTimeToLocal(aRegXML[12][03])[2]              , Nil} ) // Hora Inicial
                        aAdd(aRegDA0,{"DA0_DATATE" , FwDateTimeToLocal(aRegXML[13][03])[1]              , Nil} ) // Data Final  
                        aAdd(aRegDA0,{"DA0_HORATE" , FwDateTimeToLocal(aRegXML[13][03])[2]              , Nil} ) // Hora Final

                        DA1->(DBGoTop())
                        
                        aLinha := {}
                        
                        IF ! DA1->(MsSeek(xFilial("DA1") + StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1]) + aRegXML[07][03] ))
                            While DA1->(!Eof()) .And. StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1]) == DA1->DA1_CODTAB
                                aLinha := {}
                                aAdd(aLinha,{"LINPOS", "DA1_ITEM", DA1->DA1_ITEM})
                                aAdd(aRegDA1,aLinha)
                                DA1->(DBSkip())
                            End 
                            aAdd(aLinha,{"LINPOS", "DA1_ITEM", Soma1(DA1->DA1_ITEM)})
                        Else 
                            aAdd(aLinha,{"LINPOS", "DA1_ITEM", DA1->DA1_ITEM })
                            aAdd(aLinha,{"AUTDELETA", "N", Nil})
                        EndIF 

                        aAdd(aLinha,{"DA1_CODPRO", aRegXML[07][03]                                    , Nil} ) // Codigo do Produto
                        aAdd(aLinha,{"DA1_PRCVEN", aRegXML[11][03]                                    , Nil} ) // Preco de venda
                        aAdd(aLinha,{"DA1_ATIVO" , IIF(aRegXML[14][03] == "1","1","2")                , Nil} ) // Item Ativo (1=Sim;2=Nao)
                        
                        lMsErroAuto := .F.

                        MSExecAuto({|x,y,z| Omsa010(x,y,z)},aCabec,aItens,nOpc)

                        If lMsErroAuto
                            aErro := GetAutoGRLog()
                            
                            For nAux := 1 To Len(aErro)
                                cErro += aErro[nAux] + CRLF
                            Next
                            
                            fnGrvLog(cEndPoint,cBody,cResult,cErro,"Tabela de Preço: " + StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1]) + " - " +aRegXML[07][03],cValToChar(nOpc),"Integracao Tabela de Preço")
                        Else
                            fnGrvLog(cEndPoint,cBody,cResult,,"Erro Tabela de Preço: " + StrZero(aRegXML[02][03], FWTamSX3("DA0_CODTAB")[1]) + " - " +aRegXML[07][03],cValToChar(nOpc),"Integracao Tabela de Preço")
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
Realiza a consulta de estoque através da API padrão employeeDataContent no RM
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

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>wsTprdLoc</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA='+cCodEmp+';CODFILIAL='+cCodFil+';CODLOC='+cLocEstoq+';IDPRD='+cCodProd+'</tot:parameters> '
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
        STFMessage("ItemRegistered","STOP","Error: " + DecodeUTF8(oWsdl:cError, "cp1252"))
        lErIntRM := .T.
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            STFMessage("ItemRegistered","STOP","Falha no objeto XML retornado pelo TOTVS Corpore RM : "+DecodeUTF8(oWsdl:cError, "cp1252"))
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","Integracao Estoque")
            lErIntRM := .T.
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                STFMessage("ItemRegistered","STOP","Falha ao gerar objeto XML : " + oXML:Error())
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","Integracao Estoque")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                nSaldo  := Val(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:SALDOFISICO'))
                If !Empty(nSaldo)
                    DBSelectArea("SB2")
                    If SB2->(MSSeek(xFilial("SB2") + cCodProd + cLocEstoq))
                        If SaldoSB2() != nSaldo
                            RecLock("SB2",.F.)
                                SB2->B2_QATU := nSaldo
                            SB2->(MSUnlock())
                        EndIF 
                    EndIF
                EndIF
                fnGrvLog(cEndPoint,cBody,cResult,"","Armazem: "+cLocEstoq+", Produto: "+cCodProd,"2","Integracao Estoque")
            Endif

        EndIf
    EndIF 
    
Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} fwsPontoVenda
Realiza a consulta de Ponto de Venda através da API padrão RealizarConsultaSQL no RM
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Ponto de Venda","2","Integracao Ponto de Venda")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SLG")

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

                        IF ! SA1->(MsSeek(xFilial("SA1")+aRegXML[2,3]))
                            RecLock("SLG",.T.)
                                SLG->LG_FILIAL  := xFilial("SLG")
                                SLG->LG_CODIGO  := StrZero(aRegXML[02][03], FWTamSX3("LG_CODIGO")[1])
                                SLG->LG_NOME    := aRegXML[03][03]
                                SLG->LG_NFCE    := .T.
                                SLG->LG_PDV     := aRegXML[06][03]
                                SLG->LG_SERPDV  := aRegXML[06][03]
                                SLG->LG_SERNFIS := '999'
                                SLG->LG_COO     := '999999'
                                SLG->LG_PORTIF  := 'COM1'
                                FwPutSX5(cFilAnt, "01", aRegXML[06][03], '000000001', /*cTextoEng*/, /*cTextoEsp*/, /*cTextoAlt*/)
                            SLG->(MSUnlock())

                            fnGrvLog(cEndPoint,cBody,cResult,"","Estacao: "+StrZero(aRegXML[02][03], FWTamSX3("LG_CODIGO")[1]),"3","Integracao Ponto de Venda")
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
Realiza a consulta do Código de Barras através da API padrão RealizarConsultaSQL no RM
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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SLK")
                SLK->(DBSetOrder(2))

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')
                    
                    If !Empty(aRegXML)

                        IF ! SLK->(MsSeek(xFilial("SLK") + Pad(aRegXML[05][03],FWTamSX3("LK_CODIGO")[1]) + aRegXML[03][03] ))
                            RecLock("SLK",.T.)
                                SLK->LK_FILIAL  := xFilial("SLK")
                                SLK->LK_CODBAR  := aRegXML[03][03]
                                SLK->LK_CODIGO  := aRegXML[05][03]
                                SLK->LK_QUANT   := 1
                            SLK->(MSUnlock())

                            fnGrvLog(cEndPoint,cBody,cResult,"","Codigo de Barras: "+aRegXML[05][03]+" - "+aRegXML[03][03],"3","Integracao Codigo de Barras")
                        Else
                            RecLock("SLK",.F.)
                                SLK->LK_CODBAR  := aRegXML[03][03]
                            SLK->(MSUnlock())

                            fnGrvLog(cEndPoint,cBody,cResult,"","Codigo de Barras: "+aRegXML[05][03]+" - "+aRegXML[03][03],"4","Integracao Codigo de Barras")
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
/*/{Protheus.doc} fwsVendedor
Realiza a consulta do Vendedor/Operador através da API padrão RealizarConsultaSQL no RM
/*/
//------------------------------------------------------------------------------------------

Static Function fwsVendedor()

    Local oWsdl as Object
    Local oXml as Object 
    Local oModel as Object 
    Local oSA6Mod as Object
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cErro     := ""
    Local aRegXML   := {}
    Local aErro     := {}
    Local aRegSA3   := {}
    Local cCodVend  := ""
    Local cCodOper  := ""
    Local _cAlias   := "SA6_"+FWTimeStamp(1)
    Local nOpc
    Local nY, nAux

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
        fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Codigo de Barras","2","Integracao Codigo de Barras")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Vendedor/Operador","2","Integracao Vendedor/Operador")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Erro na Importacao de Vendedor/Operador","2","Integracao Vendedor/Operador")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                DBSelectArea("SA3")
                DBSelectArea("SA6")

                For nY := 1 To oXML:XPathChildCount('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet')
                    aRegXML := {}
                    aRegXML := oXML:XPathGetChildArray('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado'+'[' + cValToChar(nY) + ']')

                    //SA3 - Vendedor
                    If !Empty(aRegXML)

                        cCodVend := StrZero(aRegXML[20][03],FWTamSX3("A3_COD")[1])

                        IF ! SA3->(MsSeek(xFilial("SA3") + cCodVend ))
                            
                            aRegSA3 := {}

                            aAdd(aRegSA3, {"A3_COD"  , cCodVend	        , Nil})
                            aAdd(aRegSA3, {"A3_NOME" , aRegXML[03][03]	, Nil})

                            lMsErroAuto := .F.
                            MSExecAuto({|x,y| MATA040(x,y)},aRegSA3,3)

                            If lMsErroAuto
                                aErro := GetAutoGRLog()
                                For nAux := 1 To Len(aErro)
                                    cErro += aErro[nAux] + CRLF
                                Next
                                fnGrvLog(cEndPoint,cBody,"",cErro,"Vendedor: "+cCodVend,"3","Integracao Vendedor")
                            Else
                                fnGrvLog(cEndPoint,cBody,cResult,"","Vendedor: "+cCodVend,"3","Integracao Vendedor")
                            EndIF 

                            
                        Else
                            aRegSA3 := {}
                            aAdd(aRegSA3, {"A3_NOME" , aRegXML[03][03]	, Nil})

                            lMsErroAuto := .F.
                            MSExecAuto({|x,y| MATA040(x,y)},aRegSA3,4)

                            If lMsErroAuto
                                aErro := GetAutoGRLog()
                                For nAux := 1 To Len(aErro)
                                    cErro += aErro[nAux] + CRLF
                                Next
                                fnGrvLog(cEndPoint,cBody,"",cErro,"Vendedor: "+cCodVend,"4","Integracao Vendedor")
                            Else
                                fnGrvLog(cEndPoint,cBody,cResult,"","Vendedor: "+cCodVend,"4","Integracao Vendedor")
                            EndIF
                        EndIF 
                        
                    EndIF

                    //SA6 - Bancos
                    If !Empty(aRegXML)
                        
                        SA6->(DBSetOrder(2))

                        oModel := FWLoadModel("MATA070")
                        IF ! SA6->(MsSeek(xFilial("SA6") + Pad(aRegXML[03][03],FWTamSX3("A6_NOME")[1]) ))
                            nOpc := 3
                            oModel:SetOperation(nOpc)

                            BeginSql Alias _cAlias
                                SELECT MAX(A6_COD) A6_COD
                                FROM %table:SA6% SA6
                                WHERE A6_FILIAL = %xFilial:SA6%
                                    AND SA6.A6_AGENCIA = '.'
                                    AND SA6.%NotDel%
                            EndSql
                            cCodOper := IIF(!Empty((_cAlias)->A6_COD),Soma1((_cAlias)->A6_COD),'C02')
                            (_cAlias)->(dbCloseArea())
                        Else
                            nOpc := 4
                            oModel:SetOperation(nOpc)
                            cCodOper := SA6->A6_COD
                        EndIF 
                        oModel:Activate()
                        oSA6Mod:= oModel:getModel("MATA070_SA6")

                        oSA6Mod:setValue("A6_COD"     , cCodOper                                        ) // Codigo
                        oSA6Mod:setValue("A6_AGENCIA" , "."                                             ) // Nro Agencia
                        oSA6Mod:setValue("A6_NUMCON"  , "."                                             ) // Nro Conta
                        oSA6Mod:setValue("A6_NOME"    , Pad(aRegXML[20][03],FWTamSX3("A6_NOME")[1])     ) // Nome Banco
                        oSA6Mod:setValue("A6_NREDUZ"  , Pad(aRegXML[20][03],FWTamSX3("A6_NREDUZ ")[1])  ) // Nome Red.Bco
                        
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
                            fnGrvLog(cEndPoint,cBody,cResult,cErro,"Operador: " + cCodOper ,cValToChar(nOpc),"Integracao Produto")
                        Else
                            IF nOpc == 3
                                FwPutSX5(,"23", cCodOper , Pad(aRegXML[20][03],FWTamSX3("A6_NOME")[1]), /*cTextoEng*/, /*cTextoEsp*/, /*cTextoAlt*/)
                                
                            EndIF 

                            fnGrvLog(cEndPoint,cBody,cResult,,"Erro Operador: " + cCodOper ,cValToChar(nOpc),"Integracao Produto")
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

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvNFeVend
Realiza o envio da Nota Fiscal de Saída para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvNFeVend()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsDataServer/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cLocEstoq := SuperGetMV("MV_LOCPAD")
    Local cIDMovRet := ""
    Local aRetCons  := {}

    DBSelectArea("SL2")
    IF SL2->(MsSeek(SL1->L1_FILIAL + SL1->L1_NUM ))
        cLocEstoq := SL2->L2_LOCAL
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
    cBody += '                                  <CODLOC>' + cLocEstoq + '</CODLOC> ' //Código do Local de Destino
    cBody += '                                  <CODCFO>' + SF1->F1_FORNECE + '</CODCFO> ' //Código do Cliente / Fornecedor
    cBody += '                                  <NUMEROMOV>' + SF1->F1_DOC + '</NUMEROMOV> '
    cBody += '                                  <SERIE>' + SF1->F1_SERIE + '</SERIE> '
    cBody += '                                  <CODTMV>2.2.25</CODTMV> '
    cBody += '                                  <TIPO>P</TIPO> '
    cBody += '                                  <STATUS>Q</STATUS> '
    cBody += '                                  <MOVIMPRESSO>0</MOVIMPRESSO> '
    cBody += '                                  <DOCIMPRESSO>0</DOCIMPRESSO> '
    cBody += '                                  <FATIMPRESSA>0</FATIMPRESSA> '
    cBody += '                                  <DATAEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA )  )+ '</DATAEMISSAO> '
    cBody += '                                  <DATASAIDA>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA )  )+ '</DATASAIDA> '
    cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
    cBody += '                                  <VALORBRUTO>' + AlltoChar(SL1->L1_VALBRUT, cPicVal) + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</VALORLIQUIDO> '
    cBody += '                                  <VALOROUTROS>0,0000</VALOROUTROS> '
    cBody += '                                  <PERCENTUALFRETE>0,0000</PERCENTUALFRETE> '
    cBody += '                                  <VALORFRETE>'+ AlltoChar(SL1->L1_FRETE, cPicVal) +'</VALORFRETE> '
    cBody += '                                  <PERCENTUALDESC>'+ AlltoChar(SL1->L1_DESCNF, cPicVal) +'</PERCENTUALDESC> '
    cBody += '                                  <VALORDESC>'+ AlltoChar(SL1->L1_DESCONT, cPicVal) +'</VALORDESC> '
    cBody += '                                  <PERCENTUALDESP>0,0000</PERCENTUALDESP> '
    cBody += '                                  <VALORDESP>'+ AlltoChar(SL1->L1_DESPESA, cPicVal) +'</VALORDESP> '
    cBody += '                                  <PERCCOMISSAO>'+ AlltoChar(SL1->L1_COMIS, cPicVal) +'</PERCCOMISSAO> '
    cBody += '                                  <PESOLIQUIDO>0,0000</PESOLIQUIDO> '
    cBody += '                                  <PESOBRUTO>0,0000</PESOBRUTO> '
    cBody += '                                  <CODTB1FLX></CODTB1FLX> '
    cBody += '                                  <CODTB4FLX></CODTB4FLX> '
    cBody += '                                  <IDMOVLCTFLUXUS>-1</IDMOVLCTFLUXUS> '
    cBody += '                                  <CODMOEVALORLIQUIDO>R$</CODMOEVALORLIQUIDO> '
    cBody += '                                  <DATAMOVIMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA )  )+ '</DATAMOVIMENTO> '
    cBody += '                                  <NUMEROLCTGERADO>1</NUMEROLCTGERADO> '
    cBody += '                                  <GEROUFATURA>0</GEROUFATURA> '
    cBody += '                                  <NUMEROLCTABERTO>1</NUMEROLCTABERTO> '
    cBody += '                                  <FRETECIFOUFOB>9</FRETECIFOUFOB> '
    cBody += '                                  <CODCFOAUX>CXXXXXXXXXX</CODCFOAUX> '
    cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Não terá Centro de Custo no cabeçalho
    cBody += '                                  <PERCCOMISSAOVEN2>0,0000</PERCCOMISSAOVEN2> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += '                                  <CODFILIALDESTINO>' + cCodFil + '</CODFILIALDESTINO> '
    cBody += '                                  <GERADOPORLOTE>0</GERADOPORLOTE> '
    cBody += '                                  <CODEVENTO>12</CODEVENTO> '
    cBody += '                                  <STATUSEXPORTCONT>1</STATUSEXPORTCONT> '
    cBody += '                                  <CODLOTE>41213</CODLOTE> '
    cBody += '                                  <IDNAT>19</IDNAT> ' //Verificar esse ID NAT 
    cBody += '                                  <GEROUCONTATRABALHO>0</GEROUCONTATRABALHO> '
    cBody += '                                  <GERADOPORCONTATRABALHO>0</GERADOPORCONTATRABALHO> '
    cBody += '                                  <HORULTIMAALTERACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA )  )+ '</HORULTIMAALTERACAO> '
    cBody += '                                  <INDUSOOBJ>0.00</INDUSOOBJ> '
    cBody += '                                  <INTEGRADOBONUM>0</INTEGRADOBONUM> '
    cBody += '                                  <FLAGPROCESSADO>0</FLAGPROCESSADO> '
    cBody += '                                  <ABATIMENTOICMS>0,0000</ABATIMENTOICMS> '
    cBody += '                                  <HORARIOEMISSAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) )+ '</HORARIOEMISSAO> '
    cBody += '                                  <USUARIOCRIACAO>' + cUser + '</USUARIOCRIACAO> '
    cBody += '                                  <DATACRIACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) )+ '</DATACRIACAO> '
    cBody += '                                  <STSEMAIL>0</STSEMAIL> '
    cBody += '                                  <VALORBRUTOINTERNO>' + AlltoChar(SL1->L1_VALBRUT, cPicVal) + '</VALORBRUTOINTERNO> '
    cBody += '                                  <VINCULADOESTOQUEFL>0</VINCULADOESTOQUEFL> '
    cBody += '                                  <HORASAIDA>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) )+ '</HORASAIDA> '
    cBody += '                                  <VRBASEINSSOUTRAEMPRESA>0,0000</VRBASEINSSOUTRAEMPRESA> '
    cBody += '                                  <CODTDO>65</CODTDO> '
    cBody += '                                  <VALORDESCCONDICIONAL>0,0000</VALORDESCCONDICIONAL> '
    cBody += '                                  <VALORDESPCONDICIONAL>0,0000</VALORDESPCONDICIONAL> '
    cBody += '                                  <DATACONTABILIZACAO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) )+ '</DATACONTABILIZACAO> '
    cBody += '                                  <INTEGRADOAUTOMACAO>0</INTEGRADOAUTOMACAO> '
    cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
    cBody += '                                  <DATALANCAMENTO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) )+ '</DATALANCAMENTO> '
    cBody += '                                  <RECIBONFESTATUS>0</RECIBONFESTATUS> '
    cBody += '                                  <VALORMERCADORIAS>' + SL1->L1_VALMERC + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>1</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</VALORRATEIOLAN> '
    cBody += '                                  <CHAVEACESSONFE>'+ AlltoChar(SL1->L1_KEYNFCE, cPicVal) +'</CHAVEACESSONFE> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + AlltoChar(SL1->L1_VALBRUT, cPicVal) + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</VALORLIQUIDOORIG> '
    cBody += '                                  <VALOROUTROSORIG>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</VALOROUTROSORIG> '
    cBody += '                                  <VALORRATEIOLANORIG>' + AlltoChar(SL1->L1_VLRLIQ, cPicVal) + '</VALORRATEIOLANORIG> '
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
    cBody += '                                  <DATAINICIOCREDITO>' + ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) ) + '</DATAINICIOCREDITO> '
    cBody += '                                  <OPERACAOPRESENCIAL>0</OPERACAOPRESENCIAL> '
    cBody += '                                  <NROSAT>'+Alltrim(SL1->L1_SERSAT)+'</NROSAT> '
    cBody += '                              </TMOVFISCAL> '
    cBody += '                              <TMOVRATCCU> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Não terá Centro de Custo no cabeçalho
    cBody += '                                  <NOME></NOME> '
    cBody += '                                  <VALOR></VALOR> '
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
    IF SL4->(MSSeek(SL1->L1_FILIAL + SL1->L1_NUM))
        While SL4->(!Eof()) .AND. ( SL2->L2_FILIAL  == SL1->L1_FILIAL );
                            .AND. ( SL2->L2_NUM     == SL1->L1_NUM )
            
            SL4->(MSSeek(SL4->L4_FILIAL + SubStr(Alltrim(SL4->L4_ADMINIS),1,3)))

            cBody += '                              <TMOVPAGTO> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <TIPOFORMAPAGTO></TIPOFORMAPAGTO> '
            cBody += '                                  <TAXAADM>'+ AlltoChar(SAE->AE_TAXA, cPicVal) +'</TAXAADM> '
            cBody += '                                  <CODCXA>'+ Alltrim(SL1->L1_OPERADO) +'</CODCXA> '
            cBody += '                                  <CODCOLCXA></CODCOLCXA> '
            cBody += '                                  <IDLAN>-1</IDLAN> '
            cBody += '                                  <NOMEREDE></NOMEREDE> '
            cBody += '                                  <NSU>'+ SL4->L4_NSUTEF +'</NSU> '
            cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
            cBody += '                                  <IDFORMAPAGTO></IDFORMAPAGTO> '
            cBody += '                                  <DATAVENCIMENTO>'+ ( FWTimeStamp(3, SL4->L4_DATA , SL1->L1_HORA) ) +'</DATAVENCIMENTO> '
            cBody += '                                  <TIPOPAGAMENTO></TIPOPAGAMENTO> '
            cBody += '                                  <VALOR>'+ AlltoChar(SL4->L4_VALOR, cPicVal) +'</VALOR> '
            cBody += '                                  <DEBITOCREDITO>'+IIF(Alltrim(SL4-L4_FORMA) == "CC", "C", IIF(Alltrim(SL4-L4_FORMA) == "CD", "D",""))+'</DEBITOCREDITO> '
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
        cBody += '                                  <NSEQITMMOV>' + AlltoChar(Val(SL2->L2_ITEM)) +  '</NSEQITMMOV> '
        cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
        cBody += '                                  <NUMEROSEQUENCIAL>' + AlltoChar(Val(SL2->L2_ITEM)) +  '</NUMEROSEQUENCIAL> '
        cBody += '                                  <IDPRD>' + SL2->L2_PRODUTO + '</IDPRD> '
        cBody += '                                  <NUMNOFABRIC></NUMNOFABRIC> '
        cBody += '                                  <QUANTIDADE>' + AlltoChar(SL2->L2_QUANT, cPicVal) + '</QUANTIDADE> '
        cBody += '                                  <PRECOUNITARIO>' + AlltoChar(SL2->L2_VRUNIT, cPicVal) + '</PRECOUNITARIO> '
        cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
        cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
        cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
        cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SL1->L1_EMISNF , SL1->L1_HORA) ) +'</DATAEMISSAO> '
        cBody += '                                  <CODUND>' + SL2->L2_UM + '</CODUND> '
        cBody += '                                  <QUANTIDADEARECEBER>' + AlltoChar(SL2->L2_QUANT, cPicVal) + '</QUANTIDADEARECEBER> '
        cBody += '                                  <FLAGEFEITOSALDO>1</FLAGEFEITOSALDO> '
        cBody += '                                  <VALORUNITARIO>' + AlltoChar(SL2->L2_VLRITEM, cPicVal) + '</VALORUNITARIO> '
        cBody += '                                  <VALORFINANCEIRO>' + AlltoChar(SL2->L2_VLRITEM, cPicVal) + '</VALORFINANCEIRO> '
        cBody += '                                  <CODCCUSTO>' + SL2->L2_CCUSTO + '</CODCCUSTO> '
        cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
        cBody += '                                  <QUANTIDADEORIGINAL>' + SL2->L2_QUANT + '</QUANTIDADEORIGINAL> '
        cBody += '                                  <IDNAT>42</IDNAT> '
        cBody += '                                  <FLAG>0</FLAG> '
        cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
        cBody += '                                  <VALORBRUTOITEM>' + AlltoChar(SL2->L2_VRUNIT, cPicVal) + '</VALORBRUTOITEM> '
        cBody += '                                  <VALORTOTALITEM>'+ AlltoChar(SL2->L2_VLRITEM, cPicVal) +'</VALORTOTALITEM> '
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
        cBody += '                                  <CODTBORCAMENTO></CODTBORCAMENTO> '
        cBody += '                                  <CODCOLTBORCAMENTO></CODCOLTBORCAMENTO> '
        cBody += '                                  <RATEIOFRETE>0,0000</RATEIOFRETE> '
        cBody += '                                  <RATEIODESC>0,0000</RATEIODESC> '
        cBody += '                                  <RATEIODESP>0,0000</RATEIODESP> '
        cBody += '                                  <VALORUNTORCAMENTO>0,0000</VALORUNTORCAMENTO> '
        cBody += '                                  <VALSERVICONFE>0,0000</VALSERVICONFE> '
        cBody += '                                  <CODLOC>' + SL2->L2_LOCAL + '</CODLOC> '
        cBody += '                                  <VALORBEM>0,0000</VALORBEM> '
        cBody += '                                  <VALORLIQUIDO>' + AlltoChar(SL2->L2_VRUNIT, cPicVal) + '</VALORLIQUIDO> '
        cBody += '                                  <RATEIOCCUSTODEPTO></RATEIOCCUSTODEPTO> '
        cBody += '                                  <VALORBRUTOITEMORIG>' + AlltoChar(SL2->L2_VRUNIT, cPicVal) + '</VALORBRUTOITEMORIG> '
        cBody += '                                  <CODNATUREZAITEM></CODNATUREZAITEM> '
        cBody += '                                  <QUANTIDADETOTAL>' + AlltoChar(SL2->L2_QUANT, cPicVal) + '</QUANTIDADETOTAL> '
        cBody += '                                  <PRODUTOSUBSTITUTO>0</PRODUTOSUBSTITUTO> '
        cBody += '                                  <PRECOUNITARIOSELEC>0</PRECOUNITARIOSELEC> '
        cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
        cBody += '                                  <VALORBASEDEPRECIACAOBEM>0,0000</VALORBASEDEPRECIACAOBEM> '
        cBody += '                                  <IDMOVSOLICITACAOMNT>0</IDMOVSOLICITACAOMNT> ' 
        cBody += '                              </TITMMOV> '
        cBody += '                              <TITMMOVRATCCU> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV></NSEQITMMOV> '
        cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Rateio de Centro de Custo do Item não terá
        cBody += '                                  <VALOR></VALOR> '
        cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
        cBody += '                              </TITMMOVRATCCU> '
        cBody += '                              <TMOVCOMPL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                              </TMOVCOMPL> '
        cBody += '                              <TITMMOVFISCAL> '
        cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
        cBody += '                                  <IDMOV>-1</IDMOV> '
        cBody += '                                  <NSEQITMMOV>'+ AlltoChar(Val(SL2->L2_ITEM)) +'</NSEQITMMOV> '
        cBody += '                                  <VLRTOTTRIB>'+ AlltoChar(SL2->L2_VLRITEM, cPicVal) +'</VLRTOTTRIB> '
        cBody += '                                  <VALORIBPTFEDERAL>'+ AlltoChar(SL2->L2_TOTFED, cPicVal) +'</VALORIBPTFEDERAL> '
        cBody += '                                  <VALORIBPTESTADUAL>'+ AlltoChar(SL2->L2_TOTEST, cPicVal) +'</VALORIBPTESTADUAL> '
        cBody += '                                  <VALORIBPTMUNICIPAL>'+ AlltoChar(SL2->L2_TOTMUN, cPicVal) +'</VALORIBPTMUNICIPAL> '
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
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"SL1 - "+SL1->L1_NUM,"3","Integracao NFC-e")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",oXML:Error(),"SL1 - "+SL1->L1_NUM,"3","Integracao NFC-e")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                     At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                
                If !Empty(cIDMovRet) .AND. SL1->(FieldPos("L1_XIDMOV") > 0)
                    RecLock("SL1",.F.)
                        SL1->L1_XIDMOV := cIDMovRet 
                    SL1->(MSUnlock())
                    aRetCons := fnConsultBX(cIDMovRet)
                    If Len(aRetCons) > 0
                        RecLock("SL1",.F.)
                            SL1->L1_XIDLAN := aRetCons[2]
                            SL1->L1_XIDBX  := aRetCons[3]
                        SL1->(MSUnlock())
                    EndIF 
                EndIF 
                fnGrvLog(cEndPoint,cBody,cResult,"","SL1 - "+SL1->L1_NUM,"3","Integracao NFC-e")
            Endif

        EndIf
    EndIF 
    
Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvNFeDev
Realiza o envio da Nota Fiscal de Entrada para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvNFeDev()

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsDataServer/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cLocEstoq := SuperGetMV("MV_LOCPAD")
    Local cIDMovRet := ""

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
    cBody += '                                  <CODLOC>' + cLocEstoq + '</CODLOC> ' //Código do Local de Destino
    cBody += '                                  <CODCFO>' + SF1->F1_FORNECE + '</CODCFO> ' //Código do Cliente / Fornecedor
    cBody += '                                  <NUMEROMOV>' + SF1->F1_DOC + '</NUMEROMOV> '
    cBody += '                                  <SERIE>' + SF1->F1_SERIE + '</SERIE> '
    cBody += '                                  <CODTMV>2.2.25</CODTMV> '
    cBody += '                                  <TIPO>P</TIPO> '
    cBody += '                                  <STATUS>F</STATUS> '
    cBody += '                                  <MOVIMPRESSO>0</MOVIMPRESSO> '
    cBody += '                                  <DOCIMPRESSO>0</DOCIMPRESSO> '
    cBody += '                                  <FATIMPRESSA>0</FATIMPRESSA> '
    cBody += '                                  <DATAEMISSAO>' + ( FWTimeStamp(3, SF1->F1_DAUTNFE , SF1->F1_HAUTNFE )  )+ '</DATAEMISSAO> '
    cBody += '                                  <DATASAIDA>' + ( FWTimeStamp(3, SF1->F1_DAUTNFE , SF1->F1_HAUTNFE )  )+ '</DATASAIDA> '
    cBody += '                                  <COMISSAOREPRES>0,0000</COMISSAOREPRES> '
    cBody += '                                  <VALORBRUTO>' + AlltoChar(SF1->F1_VALBRUT, cPicVal) + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</VALORLIQUIDO> '
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
    cBody += '                                  <CODTB1FLX></CODTB1FLX> '
    cBody += '                                  <CODTB4FLX></CODTB4FLX> '
    cBody += '                                  <IDMOVLCTFLUXUS>-1</IDMOVLCTFLUXUS> '
    cBody += '                                  <CODMOEVALORLIQUIDO>R$</CODMOEVALORLIQUIDO> '
    cBody += '                                  <DATAMOVIMENTO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATAMOVIMENTO> '
    cBody += '                                  <NUMEROLCTGERADO>1</NUMEROLCTGERADO> '
    cBody += '                                  <GEROUFATURA>0</GEROUFATURA> '
    cBody += '                                  <NUMEROLCTABERTO>1</NUMEROLCTABERTO> '
    cBody += '                                  <FRETECIFOUFOB>9</FRETECIFOUFOB> '
    cBody += '                                  <SEGUNDONUMERO></SEGUNDONUMERO> '
    cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Não terá Centro de Custo no cabeçalho
    cBody += '                                  <PERCCOMISSAOVEN2>0,0000</PERCCOMISSAOVEN2> '
    cBody += '                                  <CODCOLCFO>0</CODCOLCFO> '
    cBody += '                                  <CODUSUARIO>' + cUser + '</CODUSUARIO> '
    cBody += '                                  <CODFILIALDESTINO>' + cCodFil + '</CODFILIALDESTINO> '
    cBody += '                                  <GERADOPORLOTE>0</GERADOPORLOTE> '
    cBody += '                                  <CODEVENTO>32</CODEVENTO> '
    cBody += '                                  <STATUSEXPORTCONT>1</STATUSEXPORTCONT> '
    cBody += '                                  <CODLOTE>41222</CODLOTE> '
    cBody += '                                  <IDNAT>41</IDNAT> '
    cBody += '                                  <GEROUCONTATRABALHO>0</GEROUCONTATRABALHO> '
    cBody += '                                  <GERADOPORCONTATRABALHO>0</GERADOPORCONTATRABALHO> '
    cBody += '                                  <HORULTIMAALTERACAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</HORULTIMAALTERACAO> '
    cBody += '                                  <INDUSOOBJ>0.00</INDUSOOBJ> '
    cBody += '                                  <INTEGRADOBONUM>0</INTEGRADOBONUM> '
    cBody += '                                  <FLAGPROCESSADO>0</FLAGPROCESSADO> '
    cBody += '                                  <ABATIMENTOICMS>0,0000</ABATIMENTOICMS> '
    cBody += '                                  <HORARIOEMISSAO>' + ( FWTimeStamp(3, SF1->F1_DAUTNFE , SF1->F1_HAUTNFE )  )+ '</HORARIOEMISSAO> '
    cBody += '                                  <USUARIOCRIACAO>' + cUser + '</USUARIOCRIACAO> '
    cBody += '                                  <DATACRIACAO>' + ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA )  )+ '</DATACRIACAO> '
    cBody += '                                  <STSEMAIL>0</STSEMAIL> '
    cBody += '                                  <VALORBRUTOINTERNO>' + AlltoChar(SF1->F1_VALBRUT, cPicVal) + '</VALORBRUTOINTERNO> '
    cBody += '                                  <VINCULADOESTOQUEFL>0</VINCULADOESTOQUEFL> '
    cBody += '                                  <HORASAIDA>' + ( FWTimeStamp(3, SF1->F1_DAUTNFE , SF1->F1_HAUTNFE )  )+ '</HORASAIDA> '
    cBody += '                                  <VRBASEINSSOUTRAEMPRESA>0,0000</VRBASEINSSOUTRAEMPRESA> '
    cBody += '                                  <CODTDO>55</CODTDO> '
    cBody += '                                  <VALORDESCCONDICIONAL>0,0000</VALORDESCCONDICIONAL> '
    cBody += '                                  <VALORDESPCONDICIONAL>0,0000</VALORDESPCONDICIONAL> '
    cBody += '                                  <DATACONTABILIZACAO>' + ( FWTimeStamp(3, SF1->F1_DTDIGIT , SF1->F1_HORA )  )+ '</DATACONTABILIZACAO> '
    cBody += '                                  <INTEGRADOAUTOMACAO>0</INTEGRADOAUTOMACAO> '
    cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
    cBody += '                                  <DATALANCAMENTO>' + ( FWTimeStamp(3, SF1->F1_DTDIGIT , SF1->F1_HORA )  )+ '</DATALANCAMENTO> '
    cBody += '                                  <RECIBONFESTATUS>0</RECIBONFESTATUS> '
    cBody += '                                  <VALORMERCADORIAS>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>1</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</VALORRATEIOLAN> '
    cBody += '                                  <HISTORICOCURTO></HISTORICOCURTO> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + AlltoChar(SF1->F1_VALBRUT, cPicVal) + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</VALORLIQUIDOORIG> '
    cBody += '                                  <VALOROUTROSORIG>0,0000</VALOROUTROSORIG> '
    cBody += '                                  <VALORRATEIOLANORIG>0,0000</VALORRATEIOLANORIG> '
    cBody += '                                  <FLAGCONCLUSAO>0</FLAGCONCLUSAO> '
    cBody += '                                  <STATUSPARADIGMA>N</STATUSPARADIGMA> '
    cBody += '                                  <STATUSINTEGRACAO>N</STATUSINTEGRACAO> '
    cBody += '                                  <PERCCOMISSAOVEN3>0.0000</PERCCOMISSAOVEN3> '
    cBody += '                                  <PERCCOMISSAOVEN4>0.0000</PERCCOMISSAOVEN4> '
    cBody += '                                  <STATUSMOVINCLUSAOCOLAB>0</STATUSMOVINCLUSAOCOLAB> '
    cBody += '                                  <IDMOVRELAC>' + " " + '</IDMOVRELAC> ' //Verificar o ID Relacionado da NF de Saída
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
    cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Não terá Centro de Custo no cabeçalho
    cBody += '                                  <NOME></NOME> '
    cBody += '                                  <VALOR></VALOR> '
    cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
    cBody += '                              </TMOVRATCCU> '
    cBody += '                              <TMOVHISTORICO> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <HISTORICOLONGO></HISTORICOLONGO> '
    cBody += '                                  <HISTORICOCURTO></HISTORICOCURTO> '
    cBody += '                              </TMOVHISTORICO> '
    cBody += '                              <TMOVPAGTO> '
    cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
    cBody += '                                  <IDSEQPAGTO>-1</IDSEQPAGTO> '
    cBody += '                                  <IDMOV>-1</IDMOV> '
    cBody += '                                  <TIPOFORMAPAGTO></TIPOFORMAPAGTO> '
    cBody += '                                  <TAXAADM>0,0000</TAXAADM> '
    cBody += '                                  <CODCXA></CODCXA> '
    cBody += '                                  <CODCOLCXA></CODCOLCXA> '
    cBody += '                                  <IDLAN>-1</IDLAN> '
    cBody += '                                  <NOMEREDE></NOMEREDE> '
    cBody += '                                  <NSU></NSU> '
    cBody += '                                  <QTDEPARCELAS>0</QTDEPARCELAS> '
    cBody += '                                  <IDFORMAPAGTO></IDFORMAPAGTO> '
    cBody += '                                  <DATAVENCIMENTO></DATAVENCIMENTO> '
    cBody += '                                  <TIPOPAGAMENTO></TIPOPAGAMENTO> '
    cBody += '                                  <VALOR></VALOR> '
    cBody += '                                  <DEBITOCREDITO></DEBITOCREDITO> '
    cBody += '                              </TMOVPAGTO> '
    //Itens da Nota Fiscal de Entrada (Devolução)
    DBSelectArea("SD1")
    IF SD1->(MsSeek(SF1->F1_FILIAL + SF1->F1_DOC + SF1->F1_SERIE + SF1->F1_FORNECE + SF1->F1_LOJA))
        While !SD1->(Eof()) .AND. ( SD1->D1_FILIAL  == SF1->F1_FILIAL ); 
                            .AND. ( SD1->D1_DOC     == SF1->F1_DOC ); 
                            .AND. ( SF1->F1_SERIE   == SF1->F1_SERIE ); 
                            .AND. ( SD1->D1_FORNECE == SF1->F1_FORNECE ); 
                            .AND. ( SD1->D1_LOJA    == SF1->F1_LOJA ) 
            cBody += '                              <TITMMOV> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV>  '
            cBody += '                                  <NSEQITMMOV>' + SD1->D1_ITEM +  '</NSEQITMMOV> '
            cBody += '                                  <CODFILIAL>' + cCodFil + '</CODFILIAL> '
            cBody += '                                  <NUMEROSEQUENCIAL>' + SD1->D1_ITEM +  '</NUMEROSEQUENCIAL> '
            cBody += '                                  <IDPRD>' + SD1->D1_COD + '</IDPRD> '
            cBody += '                                  <NUMNOFABRIC></NUMNOFABRIC> '
            cBody += '                                  <QUANTIDADE>' + AlltoChar(SD1->D1_QUANT, cPicVal) + '</QUANTIDADE> '
            cBody += '                                  <PRECOUNITARIO>' + AlltoChar(SD1->D1_VUNIT, cPicVal) + '</PRECOUNITARIO> '
            cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
            cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
            cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
            cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA) ) +'</DATAEMISSAO> '
            cBody += '                                  <CODUND>' + SD1->D1_UM + '</CODUND> '
            cBody += '                                  <QUANTIDADEARECEBER>' + AlltoChar(SD1->D1_QUANT, cPicVal) + '</QUANTIDADEARECEBER> '
            cBody += '                                  <FLAGEFEITOSALDO>1</FLAGEFEITOSALDO> '
            cBody += '                                  <VALORUNITARIO>' + AlltoChar(SD1->D1_TOTAL, cPicVal) + '</VALORUNITARIO> '
            cBody += '                                  <VALORFINANCEIRO>' + AlltoChar(SD1->D1_TOTAL, cPicVal) + '</VALORFINANCEIRO> '
            cBody += '                                  <CODCCUSTO>' + SD1->D1_CC + '</CODCCUSTO> '
            cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
            cBody += '                                  <QUANTIDADEORIGINAL>' + AlltoChar(SD1->D1_QUANT, cPicVal) + '</QUANTIDADEORIGINAL> '
            cBody += '                                  <IDNAT>42</IDNAT> '
            cBody += '                                  <FLAG>0</FLAG> '
            cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
            cBody += '                                  <VALORBRUTOITEM>' + AlltoChar(SD1->D1_VUNIT, cPicVal) + '</VALORBRUTOITEM> '
            cBody += '                                  <VALORTOTALITEM>0,0000000000</VALORTOTALITEM> '
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
            cBody += '                                  <CODTBORCAMENTO></CODTBORCAMENTO> '
            cBody += '                                  <CODCOLTBORCAMENTO></CODCOLTBORCAMENTO> '
            cBody += '                                  <RATEIOFRETE>0,0000</RATEIOFRETE> '
            cBody += '                                  <RATEIODESC>0,0000</RATEIODESC> '
            cBody += '                                  <RATEIODESP>0,0000</RATEIODESP> '
            cBody += '                                  <VALORUNTORCAMENTO>0,0000</VALORUNTORCAMENTO> '
            cBody += '                                  <VALSERVICONFE>0,0000</VALSERVICONFE> '
            cBody += '                                  <CODLOC>' + SD1->D1_LOCAL + '</CODLOC> '
            cBody += '                                  <VALORBEM>0,0000</VALORBEM> '
            cBody += '                                  <VALORLIQUIDO>' + AlltoChar(SD1->D1_VUNIT, cPicVal) + '</VALORLIQUIDO> '
            cBody += '                                  <RATEIOCCUSTODEPTO></RATEIOCCUSTODEPTO> '
            cBody += '                                  <VALORBRUTOITEMORIG>' + AlltoChar(SD1->D1_VUNIT, cPicVal) + '</VALORBRUTOITEMORIG> '
            cBody += '                                  <CODNATUREZAITEM></CODNATUREZAITEM> '
            cBody += '                                  <QUANTIDADETOTAL>' + AlltoChar(SD1->D1_QUANT, cPicVal) + '</QUANTIDADETOTAL> '
            cBody += '                                  <PRODUTOSUBSTITUTO>0</PRODUTOSUBSTITUTO> '
            cBody += '                                  <PRECOUNITARIOSELEC>0</PRECOUNITARIOSELEC> '
            cBody += '                                  <INTEGRAAPLICACAO>T</INTEGRAAPLICACAO> '
            cBody += '                                  <VALORBASEDEPRECIACAOBEM>0,0000</VALORBASEDEPRECIACAOBEM> '
            cBody += '                                  <IDMOVSOLICITACAOMNT>0</IDMOVSOLICITACAOMNT> ' 
            cBody += '                              </TITMMOV> '
            cBody += '                              <TITMMOVRATCCU> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <NSEQITMMOV></NSEQITMMOV> '
            cBody += '                                  <CODCCUSTO></CODCCUSTO> ' //Rateio de Centro de Custo do Item não terá
            cBody += '                                  <VALOR></VALOR> '
            cBody += '                                  <IDMOVRATCCU>-1</IDMOVRATCCU> '
            cBody += '                              </TITMMOVRATCCU> '
            cBody += '                              <TMOVCOMPL> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                              </TMOVCOMPL> '
            cBody += '                              <TITMMOVFISCAL> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOV>-1</IDMOV> '
            cBody += '                                  <NSEQITMMOV>1</NSEQITMMOV> '
            cBody += '                                  <VLRTOTTRIB>0,0000</VLRTOTTRIB> '
            cBody += '                                  <VALORIBPTFEDERAL>0,0000</VALORIBPTFEDERAL> '
            cBody += '                                  <VALORIBPTESTADUAL>0,0000</VALORIBPTESTADUAL> '
            cBody += '                                  <VALORIBPTMUNICIPAL>0,0000</VALORIBPTMUNICIPAL> '
            cBody += '                                  <AQUISICAOPAA>0</AQUISICAOPAA> '
            cBody += '                              </TITMMOVFISCAL> '
            cBody += '                              <TMOVRELAC> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOVORIGEM>-1</IDMOVORIGEM> '
            cBody += '                                  <CODCOLDESTINO>' + cCodEmp + '</CODCOLDESTINO> '
            cBody += '                                  <IDMOVDESTINO></IDMOVDESTINO> ' //Identificador de Referencia
            cBody += '                                  <TIPORELAC>V</TIPORELAC> '
            cBody += '                                  <IDPROCESSO>-1</IDPROCESSO> '
            cBody += '                                  <VALORRECEBIDO>0</VALORRECEBIDO> '
            cBody += '                              </TMOVRELAC> '
            cBody += '                              <TITMMOVRELAC> '
            cBody += '                                  <CODCOLIGADA>' + cCodEmp + '</CODCOLIGADA> '
            cBody += '                                  <IDMOVORIGEM>-1</IDMOVORIGEM> '
            cBody += '                                  <NSEQITMMOVORIGEM>1</NSEQITMMOVORIGEM> '
            cBody += '                                  <CODCOLDESTINO>' + cCodEmp + '</CODCOLDESTINO> '
            cBody += '                                  <IDMOVDESTINO></IDMOVDESTINO> ' //Identificador de Referencia
            cBody += '                                  <NSEQITMMOVDESTINO>1</NSEQITMMOVDESTINO> '
            cBody += '                                  <QUANTIDADE>0,00000</QUANTIDADE> ' //Quantidade ?
            cBody += '                                  <VALORRECEBIDO>0</VALORRECEBIDO> ' //Valor Recebido ?
            cBody += '                              </TITMMOVRELAC> '
        EndDo 
    EndIF
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
    cBody += '                                  <IDMOVREF></IDMOVREF> ' //Identificador de Referencia
    cBody += '                                  <CHAVEACESSO>' + SF1->F1_CHVNFE + '</CHAVEACESSO> '
    cBody += '                                  <CODTMV>2.2.25</CODTMV> '
    cBody += '                                  <NUMEROMOV>' + SF1->F1_DOC + '</NUMEROMOV> '
    cBody += '                                  <SERIE>' + SF1->F1_SERIE + '</SERIE> '
    cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA) ) +'</DATAEMISSAO> '
    cBody += '                                  <VALORLIQUIDO>' + AlltoChar(SF1->F1_VALMERC, cPicVal) + '</VALORLIQUIDO> '
    cBody += '                              </TCHAVEACESSOREF> '
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
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"SF1 - "+SF1->F1_DOC,"3","Integracao NF Devolucao")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),"SF1 - "+SF1->F1_DOC,"3","Integracao NF Devolucao")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),"SF1 - "+SF1->F1_DOC,"3","Integracao NF Devolucao")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                     At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                
                If !Empty(cIDMovRet) .AND. SF1->(FieldPos("F1_XIDMOV") > 0)
                    RecLock("SF1",.F.)
                        SF1->F1_XIDMOV := cIDMovRet 
                    SF1->(MSUnlock())
                    aRetCons := fnConsultBX(cIDMovRet)
                    If Len(aRetCons) > 0
                        RecLock("SF1",.F.)
                            SF1->F1_XIDLAN := aRetCons[2]
                            SF1->F1_XIDBX  := aRetCons[3]
                        SF1->(MSUnlock())
                    EndIF
                EndIF 
                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),"SF1 - "+SF1->F1_DOC,"3","Integracao NF Devolucao")
            Endif

        EndIf
    EndIF 
    
Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fCanFinan
Realiza o cancelamento financeiro no RM
/*/
//-----------------------------------------------------------------------------

Static Function fCanFinan()
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsFormulaVisual/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cDataCanc := ""
    Local cIDBaixa  := ""
    Local cIDLan    := ""
    Local cDocCanc  := ""

    If Alltrim(FunName()) == "MATA103"
        cDataCanc := FWTimeStamp(3, dDataBase , Time() )
        cDocCanc  := "SF1 - NF: " + Alltrim(SF1->F1_DOC) + " Serie: "+Alltrim(SF1->F1_SERIE)
        cIDLan    := SF1->F1_XIDLAN
        cIDBaixa  := SF1->F1_XIDBX
    ElseIF Alltrim(FunName()) == "LOJA701"
        cDataCanc := FWTimeStamp(3, SLX->LX_DTMOVTO , SLX->LX_HORA )
        cDocCanc  := "SLX - Cupom: " + Alltrim(SLX->LX_CUPOM) + " Serie: "+Alltrim(SLX->LX_SERIE)
        cIDLan    := SLX->LX_XIDLAN
        cIDBaixa  := SLX->LX_XIDBX
    EndIF

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody := ' 	<soapenv:Header/> '
    cBody := ' 	<soapenv:Body> '
    cBody := ' 		<tot:ExecuteWithXmlParams> '
    cBody := ' 			<tot:ProcessServerName>FinLanBaixaCancelamentoData</tot:ProcessServerName> '
    cBody := ' 				<tot:strXmlParams> '
    cBody := ' 					<![CDATA[<?xml version="1.0" encoding="utf-16"?> '
    cBody := ' 							<FinLanCancelamentoBaixaParamsProc z:Id="i1" xmlns="http://www.totvs.com.br/RM/" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" xmlns:z="http://schemas.microsoft.com/2003/10/Serialization/"> '
    cBody := ' 							<ActionModule xmlns="http://www.totvs.com/">F</ActionModule> '
    cBody := ' 							<ActionName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoAction</ActionName> '
    cBody := ' 							<CanParallelize xmlns="http://www.totvs.com/">true</CanParallelize> '
    cBody := ' 							<CanSendMail xmlns="http://www.totvs.com/">false</CanSendMail> '
    cBody := ' 							<CanWaitSchedule xmlns="http://www.totvs.com/">false</CanWaitSchedule> '
    cBody := ' 							<CodUsuario xmlns="http://www.totvs.com/">mestre</CodUsuario> '
    cBody := ' 							<ConnectionId i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<ConnectionString i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<Context z:Id="i2" xmlns="http://www.totvs.com/" xmlns:a="http://www.totvs.com.br/RM/"> '
    cBody := ' 								<a:_params xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EXERCICIOFISCAL</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">22</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODLOCPRT</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODTIPOCURSO</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EDUTIPOUSR</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUNIDADEBIB</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODCOLIGADA</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$RHTIPOUSR</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">01</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODIGOEXTERNO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODSISTEMA</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIOSERVICO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema" /> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">mestre</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$IDPRJ</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CHAPAFUNCIONARIO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">00001</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODFILIAL</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 								</a:_params> '
    cBody := ' 								<a:Environment>DotNet</a:Environment> '
    cBody := ' 							</Context> '
    cBody := ' 							<CustomData i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<DisableIsolateProcess xmlns="http://www.totvs.com/">false</DisableIsolateProcess> '
    cBody := ' 							<DriverType i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<ExecutionId xmlns="http://www.totvs.com/">d2344acc-51e6-487e-bbeb-7e0074c291bd</ExecutionId> '
    cBody := ' 							<FailureMessage xmlns="http://www.totvs.com/">Falha na execução do processo</FailureMessage> '
    cBody := ' 							<FriendlyLogs i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<HideProgressDialog xmlns="http://www.totvs.com/">false</HideProgressDialog> '
    cBody := ' 							<HostName xmlns="http://www.totvs.com/">RECN019403717</HostName> '
    cBody := ' 							<Initialized xmlns="http://www.totvs.com/">true</Initialized> '
    cBody := ' 							<Ip xmlns="http://www.totvs.com/">192.168.56.1</Ip> '
    cBody := ' 							<IsolateProcess xmlns="http://www.totvs.com/">false</IsolateProcess> '
    cBody := ' 							<JobID xmlns="http://www.totvs.com/"> '
    cBody := ' 								<Children /> '
    cBody := ' 								<ExecID>1</ExecID> '
    cBody := ' 								<ID>-1</ID> '
    cBody := ' 								<IsPriorityJob>false</IsPriorityJob> '
    cBody := ' 							</JobID> '
    cBody := ' 							<JobServerHostName xmlns="http://www.totvs.com/">RECN019403717</JobServerHostName> '
    cBody := ' 							<MasterActionName xmlns="http://www.totvs.com/">FinLanAction</MasterActionName> '
    cBody := ' 							<MaximumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1000</MaximumQuantityOfPrimaryKeysPerProcess> '
    cBody := ' 							<MinimumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1</MinimumQuantityOfPrimaryKeysPerProcess> '
    cBody := ' 							<NetworkUser xmlns="http://www.totvs.com/">rimeson.pereira</NetworkUser> '
    cBody := ' 							<NotifyEmail xmlns="http://www.totvs.com/">false</NotifyEmail> '
    cBody := ' 							<NotifyEmailList i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays" /> '
    cBody := ' 							<NotifyFluig xmlns="http://www.totvs.com/">false</NotifyFluig> '
    cBody := ' 							<OnlineMode xmlns="http://www.totvs.com/">false</OnlineMode> '
    cBody := ' 							<PrimaryKeyList xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 								<a:ArrayOfanyType> '
    cBody := ' 								<a:anyType i:type="b:short" xmlns:b="http://www.w3.org/2001/XMLSchema">1</a:anyType> '
    cBody := ' 								<a:anyType i:type="b:int" xmlns:b="http://www.w3.org/2001/XMLSchema">4732</a:anyType> '
    cBody := ' 								</a:ArrayOfanyType> '
    cBody := ' 							</PrimaryKeyList> '
    cBody := ' 							<PrimaryKeyNames xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 								<a:string>CODCOLIGADA</a:string> '
    cBody := ' 								<a:string>IDLAN</a:string> '
    cBody := ' 							</PrimaryKeyNames> '
    cBody := ' 							<PrimaryKeyTableName xmlns="http://www.totvs.com/">FLAN</PrimaryKeyTableName> '
    cBody := ' 							<ProcessName xmlns="http://www.totvs.com/">Cancelamento de Baixa</ProcessName> '
    cBody := ' 							<QuantityOfSplits xmlns="http://www.totvs.com/">0</QuantityOfSplits> '
    cBody := ' 							<SaveLogInDatabase xmlns="http://www.totvs.com/">true</SaveLogInDatabase> '
    cBody := ' 							<SaveParamsExecution xmlns="http://www.totvs.com/">false</SaveParamsExecution> '
    cBody := ' 							<ScheduleDateTime xmlns="http://www.totvs.com/">2024-02-06T10:06:28.4839973-03:00</ScheduleDateTime> '
    cBody := ' 							<Scheduler xmlns="http://www.totvs.com/">JobMonitor</Scheduler> '
    cBody := ' 							<SendMail xmlns="http://www.totvs.com/">false</SendMail> '
    cBody := ' 							<ServerName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoData</ServerName> '
    cBody := ' 							<ServiceInterface i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.datacontract.org/2004/07/System" /> '
    cBody := ' 							<ShouldParallelize xmlns="http://www.totvs.com/">false</ShouldParallelize> '
    cBody := ' 							<ShowReExecuteButton xmlns="http://www.totvs.com/">true</ShowReExecuteButton> '
    cBody := ' 							<StatusMessage i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<SuccessMessage xmlns="http://www.totvs.com/">Processo executado com sucesso</SuccessMessage> '
    cBody := ' 							<SyncExecution xmlns="http://www.totvs.com/">false</SyncExecution> '
    cBody := ' 							<UseJobMonitor xmlns="http://www.totvs.com/">true</UseJobMonitor> '
    cBody := ' 							<UserName xmlns="http://www.totvs.com/">mestre</UserName> '
    cBody := ' 							<WaitSchedule xmlns="http://www.totvs.com/">false</WaitSchedule> '
    cBody := ' 							<CodColCxaCaixa>-1</CodColCxaCaixa> '
    cBody := ' 							<CodCxaCaixa /> '
    cBody := ' 							<CodSistema>F</CodSistema> '
    cBody := ' 							<DataCaixa>0001-01-01T00:00:00</DataCaixa> '
    cBody := ' 							<DataCancelamento>'+ cDataCanc +'</DataCancelamento> '
    cBody := ' 							<DataSistema>'+ cDataCanc +'</DataSistema> '
    cBody := ' 							<DescompensarExtratoLanctoPagar>false</DescompensarExtratoLanctoPagar> '
    cBody := ' 							<DescompensarExtratoLanctoReceber>false</DescompensarExtratoLanctoReceber> '
    cBody := ' 							<Historico>Referente a estorno de [OPE] ref. "[REF]"</Historico> '
    cBody := ' 							<IdSessaoCaixa>-1</IdSessaoCaixa> '
    cBody := ' 							<IsAdyen>false</IsAdyen> '
    cBody := ' 							<IsModuloDeCaixa>false</IsModuloDeCaixa> '
    cBody := ' 							<ListIdlanIdBaixa> '
    cBody := ' 								<FinLanBaixaPKPar z:Id="i3"> '
    cBody := ' 								<InternalId i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 								<ServicoAlteracaoRepasse>false</ServicoAlteracaoRepasse> '
    cBody := ' 								<CodColigada>'+ cCodEmp +'</CodColigada> '
    cBody := ' 								<IdBaixa>'+ cIDBaixa +'</IdBaixa> '
    cBody := ' 								<IdLan>'+ cIDLan +'</IdLan> '
    cBody := ' 								<IdTransacao>0</IdTransacao> '
    cBody := ' 								</FinLanBaixaPKPar> '
    cBody := ' 							</ListIdlanIdBaixa> '
    cBody := ' 							<ListLanEstornar /> '
    cBody := ' 							<ListNaoContabeis /> '
    cBody := ' 							<ListaBaixasEstornadas /> '
    cBody := ' 							<Origem>Default</Origem> ' 
    cBody := ' 							<TipoCancelamentoBaixaExtrato>CancelaSomenteItensSelecionados</TipoCancelamentoBaixaExtrato> '
    cBody := ' 							<TransacoesSiTef i:nil="true" /> '
    cBody := ' 							<TransacoesTPD i:nil="true" /> '
    cBody := ' 							<Usuario>mestre</Usuario> '
    cBody := ' 						</FinLanCancelamentoBaixaParamsProc>]]> '
    cBody := ' 				</tot:strXmlParams> '
    cBody := ' 		</tot:ExecuteWithXmlParams> '
    cBody := ' 	</soapenv:Body> '
    cBody := ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("FinLanBaixaCancelamentoData")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),cDocCanc,"5","Integracao de Cancelamento")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),cDocCanc,"5","Integracao de Cancelamento")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),cDocCanc,"5","Integracao de Cancelamento")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")

                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),cDocCanc,"5","Integracao de Cancelamento")
            Endif

        EndIf
    EndIF

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fCanMovim
Realiza o cancelamento do Movimento no RM
/*/
//-----------------------------------------------------------------------------

Static Function fCanMovim()
    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsFormulaVisual/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local cDataCanc := ""
    Local cIDBaixa  := ""
    Local cIDLan    := ""
    Local cDocCanc  := ""

    If Alltrim(FunName()) == "MATA103"
        cDataCanc := FWTimeStamp(3, dDataBase , Time() )
        cDocCanc  := "SF1 - NF: " + Alltrim(SF1->F1_DOC) + " Serie: "+Alltrim(SF1->F1_SERIE)
        cIDLan    := SFT->FT_XIDLAN
        cIDBaixa  := SFT->FT_XIDBX
    ElseIF Alltrim(FunName()) == "LOJA701"
        cDataCanc := FWTimeStamp(3, SLX->LX_DTMOVTO , SLX->LX_HORA )
        cDocCanc  := "SLX - Cupom: " + Alltrim(SLX->LX_CUPOM) + " Serie: "+Alltrim(SLX->LX_SERIE)
        cIDLan    := SLX->LX_XIDLAN
        cIDBaixa  := SLX->LX_XIDBX
    EndIF

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody := ' 	<soapenv:Header/> '
    cBody := ' 	<soapenv:Body> '
    cBody := ' 		<tot:ExecuteWithXmlParams> '
    cBody := ' 			<tot:ProcessServerName>FinLanBaixaCancelamentoData</tot:ProcessServerName> '
    cBody := ' 				<tot:strXmlParams> '
    cBody := ' 					<![CDATA[<?xml version="1.0" encoding="utf-16"?> '
    cBody := ' 							<FinLanCancelamentoBaixaParamsProc z:Id="i1" xmlns="http://www.totvs.com.br/RM/" xmlns:i="http://www.w3.org/2001/XMLSchema-instance" xmlns:z="http://schemas.microsoft.com/2003/10/Serialization/"> '
    cBody := ' 							<ActionModule xmlns="http://www.totvs.com/">F</ActionModule> '
    cBody := ' 							<ActionName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoAction</ActionName> '
    cBody := ' 							<CanParallelize xmlns="http://www.totvs.com/">true</CanParallelize> '
    cBody := ' 							<CanSendMail xmlns="http://www.totvs.com/">false</CanSendMail> '
    cBody := ' 							<CanWaitSchedule xmlns="http://www.totvs.com/">false</CanWaitSchedule> '
    cBody := ' 							<CodUsuario xmlns="http://www.totvs.com/">mestre</CodUsuario> '
    cBody := ' 							<ConnectionId i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<ConnectionString i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<Context z:Id="i2" xmlns="http://www.totvs.com/" xmlns:a="http://www.totvs.com.br/RM/"> '
    cBody := ' 								<a:_params xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EXERCICIOFISCAL</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">22</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODLOCPRT</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODTIPOCURSO</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$EDUTIPOUSR</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUNIDADEBIB</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODCOLIGADA</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$RHTIPOUSR</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">01</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODIGOEXTERNO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODSISTEMA</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">F</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIOSERVICO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema" /> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODUSUARIO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">mestre</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$IDPRJ</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">-1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CHAPAFUNCIONARIO</b:Key> '
    cBody := ' 									<b:Value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">00001</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:KeyValueOfanyTypeanyType> '
    cBody := ' 									<b:Key i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$CODFILIAL</b:Key> '
    cBody := ' 									<b:Value i:type="c:int" xmlns:c="http://www.w3.org/2001/XMLSchema">1</b:Value> '
    cBody := ' 									</b:KeyValueOfanyTypeanyType> '
    cBody := ' 								</a:_params> '
    cBody := ' 								<a:Environment>DotNet</a:Environment> '
    cBody := ' 							</Context> '
    cBody := ' 							<CustomData i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<DisableIsolateProcess xmlns="http://www.totvs.com/">false</DisableIsolateProcess> '
    cBody := ' 							<DriverType i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<ExecutionId xmlns="http://www.totvs.com/">d2344acc-51e6-487e-bbeb-7e0074c291bd</ExecutionId> '
    cBody := ' 							<FailureMessage xmlns="http://www.totvs.com/">Falha na execução do processo</FailureMessage> '
    cBody := ' 							<FriendlyLogs i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<HideProgressDialog xmlns="http://www.totvs.com/">false</HideProgressDialog> '
    cBody := ' 							<HostName xmlns="http://www.totvs.com/">RECN019403717</HostName> '
    cBody := ' 							<Initialized xmlns="http://www.totvs.com/">true</Initialized> '
    cBody := ' 							<Ip xmlns="http://www.totvs.com/">192.168.56.1</Ip> '
    cBody := ' 							<IsolateProcess xmlns="http://www.totvs.com/">false</IsolateProcess> '
    cBody := ' 							<JobID xmlns="http://www.totvs.com/"> '
    cBody := ' 								<Children /> '
    cBody := ' 								<ExecID>1</ExecID> '
    cBody := ' 								<ID>-1</ID> '
    cBody := ' 								<IsPriorityJob>false</IsPriorityJob> '
    cBody := ' 							</JobID> '
    cBody := ' 							<JobServerHostName xmlns="http://www.totvs.com/">RECN019403717</JobServerHostName> '
    cBody := ' 							<MasterActionName xmlns="http://www.totvs.com/">FinLanAction</MasterActionName> '
    cBody := ' 							<MaximumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1000</MaximumQuantityOfPrimaryKeysPerProcess> '
    cBody := ' 							<MinimumQuantityOfPrimaryKeysPerProcess xmlns="http://www.totvs.com/">1</MinimumQuantityOfPrimaryKeysPerProcess> '
    cBody := ' 							<NetworkUser xmlns="http://www.totvs.com/">rimeson.pereira</NetworkUser> '
    cBody := ' 							<NotifyEmail xmlns="http://www.totvs.com/">false</NotifyEmail> '
    cBody := ' 							<NotifyEmailList i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays" /> '
    cBody := ' 							<NotifyFluig xmlns="http://www.totvs.com/">false</NotifyFluig> '
    cBody := ' 							<OnlineMode xmlns="http://www.totvs.com/">false</OnlineMode> '
    cBody := ' 							<PrimaryKeyList xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 								<a:ArrayOfanyType> '
    cBody := ' 								<a:anyType i:type="b:short" xmlns:b="http://www.w3.org/2001/XMLSchema">1</a:anyType> '
    cBody := ' 								<a:anyType i:type="b:int" xmlns:b="http://www.w3.org/2001/XMLSchema">4732</a:anyType> '
    cBody := ' 								</a:ArrayOfanyType> '
    cBody := ' 							</PrimaryKeyList> '
    cBody := ' 							<PrimaryKeyNames xmlns="http://www.totvs.com/" xmlns:a="http://schemas.microsoft.com/2003/10/Serialization/Arrays"> '
    cBody := ' 								<a:string>CODCOLIGADA</a:string> '
    cBody := ' 								<a:string>IDLAN</a:string> '
    cBody := ' 							</PrimaryKeyNames> '
    cBody := ' 							<PrimaryKeyTableName xmlns="http://www.totvs.com/">FLAN</PrimaryKeyTableName> '
    cBody := ' 							<ProcessName xmlns="http://www.totvs.com/">Cancelamento de Baixa</ProcessName> '
    cBody := ' 							<QuantityOfSplits xmlns="http://www.totvs.com/">0</QuantityOfSplits> '
    cBody := ' 							<SaveLogInDatabase xmlns="http://www.totvs.com/">true</SaveLogInDatabase> '
    cBody := ' 							<SaveParamsExecution xmlns="http://www.totvs.com/">false</SaveParamsExecution> '
    cBody := ' 							<ScheduleDateTime xmlns="http://www.totvs.com/">2024-02-06T10:06:28.4839973-03:00</ScheduleDateTime> '
    cBody := ' 							<Scheduler xmlns="http://www.totvs.com/">JobMonitor</Scheduler> '
    cBody := ' 							<SendMail xmlns="http://www.totvs.com/">false</SendMail> '
    cBody := ' 							<ServerName xmlns="http://www.totvs.com/">FinLanBaixaCancelamentoData</ServerName> '
    cBody := ' 							<ServiceInterface i:nil="true" xmlns="http://www.totvs.com/" xmlns:a="http://schemas.datacontract.org/2004/07/System" /> '
    cBody := ' 							<ShouldParallelize xmlns="http://www.totvs.com/">false</ShouldParallelize> '
    cBody := ' 							<ShowReExecuteButton xmlns="http://www.totvs.com/">true</ShowReExecuteButton> '
    cBody := ' 							<StatusMessage i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 							<SuccessMessage xmlns="http://www.totvs.com/">Processo executado com sucesso</SuccessMessage> '
    cBody := ' 							<SyncExecution xmlns="http://www.totvs.com/">false</SyncExecution> '
    cBody := ' 							<UseJobMonitor xmlns="http://www.totvs.com/">true</UseJobMonitor> '
    cBody := ' 							<UserName xmlns="http://www.totvs.com/">mestre</UserName> '
    cBody := ' 							<WaitSchedule xmlns="http://www.totvs.com/">false</WaitSchedule> '
    cBody := ' 							<CodColCxaCaixa>-1</CodColCxaCaixa> '
    cBody := ' 							<CodCxaCaixa /> '
    cBody := ' 							<CodSistema>F</CodSistema> '
    cBody := ' 							<DataCaixa>0001-01-01T00:00:00</DataCaixa> '
    cBody := ' 							<DataCancelamento>'+ cDataCanc +'</DataCancelamento> '
    cBody := ' 							<DataSistema>'+ cDataCanc +'</DataSistema> '
    cBody := ' 							<DescompensarExtratoLanctoPagar>false</DescompensarExtratoLanctoPagar> '
    cBody := ' 							<DescompensarExtratoLanctoReceber>false</DescompensarExtratoLanctoReceber> '
    cBody := ' 							<Historico>Referente a estorno de [OPE] ref. "[REF]"</Historico> '
    cBody := ' 							<IdSessaoCaixa>-1</IdSessaoCaixa> '
    cBody := ' 							<IsAdyen>false</IsAdyen> '
    cBody := ' 							<IsModuloDeCaixa>false</IsModuloDeCaixa> '
    cBody := ' 							<ListIdlanIdBaixa> '
    cBody := ' 								<FinLanBaixaPKPar z:Id="i3"> '
    cBody := ' 								<InternalId i:nil="true" xmlns="http://www.totvs.com/" /> '
    cBody := ' 								<ServicoAlteracaoRepasse>false</ServicoAlteracaoRepasse> '
    cBody := ' 								<CodColigada>'+ cCodEmp +'</CodColigada> '
    cBody := ' 								<IdBaixa>'+ cIDBaixa +'</IdBaixa> '
    cBody := ' 								<IdLan>'+ cIDLan +'</IdLan> '
    cBody := ' 								<IdTransacao>0</IdTransacao> '
    cBody := ' 								</FinLanBaixaPKPar> '
    cBody := ' 							</ListIdlanIdBaixa> '
    cBody := ' 							<ListLanEstornar /> '
    cBody := ' 							<ListNaoContabeis /> '
    cBody := ' 							<ListaBaixasEstornadas /> '
    cBody := ' 							<Origem>Default</Origem> ' 
    cBody := ' 							<TipoCancelamentoBaixaExtrato>CancelaSomenteItensSelecionados</TipoCancelamentoBaixaExtrato> '
    cBody := ' 							<TransacoesSiTef i:nil="true" /> '
    cBody := ' 							<TransacoesTPD i:nil="true" /> '
    cBody := ' 							<Usuario>mestre</Usuario> '
    cBody := ' 						</FinLanCancelamentoBaixaParamsProc>]]> '
    cBody := ' 				</tot:strXmlParams> '
    cBody := ' 		</tot:ExecuteWithXmlParams> '
    cBody := ' 	</soapenv:Body> '
    cBody := ' </soapenv:Envelope> '

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("FinLanBaixaCancelamentoData")
        ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
        fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),cDocCanc,"5","Integracao de Cancelamento")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgAlert(DecodeUTF8(oWsdl:cError, "cp1252"),"Erro Integracao TOTVS Corpore RM")
            fnGrvLog(cEndPoint,cBody,cResult,DecodeUTF8(oWsdl:cError, "cp1252"),cDocCanc,"5","Integracao de Cancelamento")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),cDocCanc,"5","Integracao de Cancelamento")
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/") 
                fnGrvLog(cEndPoint,cBody,cResult,oXML:Error(),cDocCanc,"5","Integracao de Cancelamento")
            Endif

        EndIf
    EndIF

Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fnConsultBX
Envelope de consulta RealizarConsultaSQL no RM
/*/
//-----------------------------------------------------------------------------

Static Function fnConsultBX(pIDMov)

    Local oWsdl as Object
    Local oXml as Object 
    Local cPath     := "/wsConsultaSQL/MEX?wsdl"
    Local cBody     := ""
    Local cResult   := ""
    Local aRet      := {}

    cBody := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/"> '
    cBody += '  <soapenv:Header/> '
    cBody += '  <soapenv:Body> '
    cBody += '      <tot:RealizarConsultaSQL> '
    cBody += '          <tot:codSentenca>wsConsultaBaixa</tot:codSentenca> '
    cBody += '          <tot:codColigada>0</tot:codColigada> '
    cBody += '          <tot:codSistema>T</tot:codSistema> '
    cBody += '          <tot:parameters>CODCOLIGADA='+cCodEmp+';IDMOV='+pIDMov+'</tot:parameters> '
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
            fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta Baixa ID Mov: "+ pIDMov,"2","Integracao Estoque")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgAlert(oXML:Error(),"Erro Integracao TOTVS Corpore RM")
                fnGrvLog(cEndPoint,cBody,"",DecodeUTF8(oWsdl:cError, "cp1252"),"Consulta Baixa ID Mov: "+ pIDMov,"2","Integracao Estoque")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                
                aAdd(aRet, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:IDMOV'))
                aAdd(aRet, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:IDLAN'))
                aAdd(aRet, oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:NUMEROMOV'))
                
                fnGrvLog(cEndPoint,cBody,cResult,"","Consulta Baixa ID Mov: "+ pIDMov,"2","Integracao Estoque")
            Endif

        EndIf
    EndIF 
    
Return aRet

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fnGrvLog
Grava o LOG de integração na tabela SZ1 - Log de Integração Protheus x RM
/*/
//-----------------------------------------------------------------------------

Static Function fnGrvLog(pEndPoint,pBody,pResult,pErro,pDocto,pOper,pDscOper)
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
        Replace SZ1->Z1_MENSAG  with IIF(!Empty(pResult),pResult,pErro)
        Replace SZ1->Z1_STATUS  with IIF(!Empty(pResult),"S","E")
        Replace SZ1->Z1_ARQJSON with pBody
    SZ1->(MsUnlock())

Return
