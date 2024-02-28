#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"

//-----------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} DSOAPF01
User Function: DSOAPF01 - Função para Integração Via SOAP com o TOTVS Corpore RM
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 09/02/2024
@Permite
Programa Fonte
/*/
User Function DSOAPF01(pCodProd,pLocPad)
    Local aArea := FWGetArea()
    
    Private cUrl    := SuperGetMV("MV_XURLRM" ,.F.,"https://associacaodas145873.rm.cloudtotvs.com.br:1801")
    Private cUser   := SuperGetMV("MV_XRMUSER",.F.,"rimeson.cardoso")
    Private cPass   := SuperGetMV("MV_XRMPASS",.F.,"235289")
    Private cCodEmp := ""
    Private cCodFil := ""
    Private nSaldo  := 0

    DBSelectArea("XXD")
    XXD->(DBSetOrder(3))
    If XXD->(MSSeek(Pad("RM",15)+cEmpAnt+cFilAnt))
        cCodEmp := XXD->XXD_COMPA
        cCodFil := XXD->XXD_BRANCH
    Else 
        ApMsgStop("Coligada + Filial não encontrada no De/Para." + CRLF + CRLF +;
                  "Por favor acessar a rotina De/Para de Empresas Mensagem Unica (APCFG050), no SIGACFG e cadastrar o De/Para." + CRLF + ;
                  "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
        Return
    EndIF 

    FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Inicio da Integracao com o Corpore RM ===')

        Do Case 
            Case FunName() == 'LOJA701'
                fConsultEst(pCodProd,pLocPad)

                FwLogMsg("INFO", , "REST", FunName(), "", "01", '===  Fim da Integracao com o Corpore RM === ')
                FWRestArea(aArea)
                Return nSaldo
        End Case 
    
    FwLogMsg("INFO", , "REST", FunName(), "", "01", '===  Fim da Integracao com o Corpore RM === ')
    
    FWRestArea(aArea)

Return 

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fConsultEst
Realiza a consulta de estoque através da API padrão employeeDataContent no RM
/*/
//-----------------------------------------------------------------------------

Static Function fConsultEst(pCodProd,pLocPad)

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
        ApMsgStop("Error: " + oWsdl:cError + CRLF + ;
                  "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            ApMsgStop("Falha no objeto XML retornado pelo TOTVS Corpore RM : "+oWsdl:cError + CRLF + ;
                      "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                ApMsgSTOP( "Falha ao gerar objeto XML : " + oXML:Error() + CRLF + ; 
                           "Fonte DSOAPF01.prw", "Integração TOTVS Corpore RM")
            else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                nSaldo  := Val(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:RealizarConsultaSQLResponse/ns1:RealizarConsultaSQLResult/ns1:NewDataSet/ns1:Resultado/ns1:SALDOFISICO'))
            Endif

        EndIf
    EndIF 
    
Return
