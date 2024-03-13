#INCLUDE "Totvs.ch"
#Include "Protheus.ch"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "totvswebsrv.ch"

//-----------------------------------------------------------------------------------
/*/{PROTHEUS.DOC} DSOAPF01
User Function: DSOAPF01 - Função para Integração Via SOAP com o TOTVS Corpore RM
@OWNER PanCristal
@VERSION PROTHEUS 12
@SINCE 13/03/2024
@Permite
Programa Fonte
/*/
User Function DSOAPF01(pCodProd,pLocPad)
    Local aArea := FWGetArea()
    
    Private cUrl    := SuperGetMV("MV_XURLRM" ,.F.,"https://associacaodas145873.rm.cloudtotvs.com.br:1801")
    Private cUser   := SuperGetMV("MV_XRMUSER",.F.,"rimeson")
    Private cPass   := SuperGetMV("MV_XRMPASS",.F.,"235289")
    Private cCodEmp := ""
    Private cCodFil := ""

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

    FwLogMsg("INFO", , "REST", FunName(), "", "01", '=== Inicio da Integracao com o Corpore RM ===')

        Do Case 
            Case FunName() == 'STIPOSMAIN'
                fConsultEst(pCodProd,pLocPad)
            
            Case FunName() == 'MATA103'
                fEnvNFe()

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

    MemoWrite("C:\Temp\ConsultaEstoque.xml",cBody)

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        STFMessage("ItemRegistered","STOP","Error: " + oWsdl:cError)
        lErIntRM := .T.
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            STFMessage("ItemRegistered","STOP","Falha no objeto XML retornado pelo TOTVS Corpore RM : "+oWsdl:cError)
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
            Endif

        EndIf
    EndIF 
    
Return

//-----------------------------------------------------------------------------
/*/{Protheus.doc} fEnvNFe
Realiza o envio da Nota Fiscal de Entrada para o Copore RM
/*/
//-----------------------------------------------------------------------------

Static Function fEnvNFe()

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
    cBody += '                                  <VALORBRUTO>' + SF1->F1_VALBRUT + '</VALORBRUTO> '
    cBody += '                                  <VALORLIQUIDO>' + SF1->F1_VALMERC + '</VALORLIQUIDO> '
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
    cBody += '                                  <VALORBRUTOINTERNO>' + SF1->F1_VALBRUT + '</VALORBRUTOINTERNO> '
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
    cBody += '                                  <VALORMERCADORIAS>' + SF1->F1_VALMERC + '</VALORMERCADORIAS> '
    cBody += '                                  <USARATEIOVALORFIN>1</USARATEIOVALORFIN> '
    cBody += '                                  <CODCOLCFOAUX>0</CODCOLCFOAUX> '
    cBody += '                                  <VALORRATEIOLAN>' + SF1->F1_VALMERC + '</VALORRATEIOLAN> '
    cBody += '                                  <HISTORICOCURTO></HISTORICOCURTO> '
    cBody += '                                  <RATEIOCCUSTODEPTO>' + SF1->F1_VALMERC + '</RATEIOCCUSTODEPTO> '
    cBody += '                                  <VALORBRUTOORIG>' + SF1->F1_VALBRUT + '</VALORBRUTOORIG> '
    cBody += '                                  <VALORLIQUIDOORIG>' + SF1->F1_VALMERC + '</VALORLIQUIDOORIG> '
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
            cBody += '                                  <QUANTIDADE>' + SD1->D1_QUANT + '</QUANTIDADE> '
            cBody += '                                  <PRECOUNITARIO>' + SD1->D1_VUNIT + '</PRECOUNITARIO> '
            cBody += '                                  <PRECOTABELA>0,0000</PRECOTABELA> '
            cBody += '                                  <PERCENTUALDESC>0,0000</PERCENTUALDESC> '
            cBody += '                                  <VALORDESC>0,0000</VALORDESC> '
            cBody += '                                  <DATAEMISSAO>'+ ( FWTimeStamp(3, SF1->F1_EMISSAO , SF1->F1_HORA) ) +'</DATAEMISSAO> '
            cBody += '                                  <CODUND>' + SD1->D1_UM + '</CODUND> '
            cBody += '                                  <QUANTIDADEARECEBER>' + SD1->D1_QUANT + '</QUANTIDADEARECEBER> '
            cBody += '                                  <FLAGEFEITOSALDO>1</FLAGEFEITOSALDO> '
            cBody += '                                  <VALORUNITARIO>' + SD1->D1_TOTAL + '</VALORUNITARIO> '
            cBody += '                                  <VALORFINANCEIRO>' + SD1->D1_TOTAL + '</VALORFINANCEIRO> '
            cBody += '                                  <CODCCUSTO>' + SD1->D1_CC + '</CODCCUSTO> '
            cBody += '                                  <ALIQORDENACAO>0,0000</ALIQORDENACAO> '
            cBody += '                                  <QUANTIDADEORIGINAL>' + SD1->D1_QUANT + '</QUANTIDADEORIGINAL> '
            cBody += '                                  <IDNAT>42</IDNAT> '
            cBody += '                                  <FLAG>0</FLAG> '
            cBody += '                                  <FATORCONVUND>0,0000</FATORCONVUND> '
            cBody += '                                  <VALORBRUTOITEM>' + SD1->D1_VUNIT + '</VALORBRUTOITEM> '
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
            cBody += '                                  <VALORLIQUIDO>' + SD1->D1_VUNIT + '</VALORLIQUIDO> '
            cBody += '                                  <RATEIOCCUSTODEPTO></RATEIOCCUSTODEPTO> '
            cBody += '                                  <VALORBRUTOITEMORIG>' + SD1->D1_VUNIT + '</VALORBRUTOITEMORIG> '
            cBody += '                                  <CODNATUREZAITEM></CODNATUREZAITEM> '
            cBody += '                                  <QUANTIDADETOTAL>' + SD1->D1_QUANT + '</QUANTIDADETOTAL> '
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
    cBody += '                                  <VALORLIQUIDO>' + SF1->F1_VALMERC + '</VALORLIQUIDO> '
    cBody += '                              </TCHAVEACESSOREF> '
    cBody += '                          </MovMovimento>]]> '
    cBody += '          </tot:XML> '
    cBody += '          <tot:Contexto>CODCOLIGADA=' + cCodEmp + ';CODSISTEMA=T</tot:Contexto> '
    cBody += '     </tot:SaveRecord> '
    cBody += '  </soapenv:Body> '
    cBody += ' </soapenv:Envelope> '

    MemoWrite("C:\Temp\NFe_Entrada.xml",cBody)

    oWsdl := TWsdlManager():New()
    oWsdl:nTimeout         := 120
    oWsdl:lSSLInsecure     := .T.
    oWsdl:lProcResp        := .T.
    oWsdl:bNoCheckPeerCert := .T.
    oWSDL:lUseNSPrefix     := .T.
    oWsdl:lVerbose         := .T.
    
    If !oWsdl:ParseURL(cURL+cPath) .Or. Empty(oWsdl:ListOperations()) .Or. !oWsdl:SetOperation("RealizarConsultaSQL")
        STFMessage("ItemRegistered","Integração TOTVS Corpore RM","Error: " + oWsdl:cError)
        lErIntRM := .T.
    Else

        oWsdl:AddHttpHeader("Authorization", "Basic " + Encode64(cUser+":"+cPass))

        If !oWsdl:SendSoapMsg( cBody )
            STFMessage("ItemRegistered","Integração TOTVS Corpore RM","Falha no objeto XML retornado pelo TOTVS Corpore RM : "+oWsdl:cError)
            lErIntRM := .T.
            Return
        Else
            cResult := oWsdl:GetSoapResponse()
            cResult := StrTran(cResult, "&lt;", "<")
            cResult := StrTran(cResult, "&gt;&#xD;", ">")
            cResult := StrTran(cResult, "&gt;", ">")
            oXml := TXmlManager():New()

            If !oXML:Parse( cResult )
                STFMessage("ItemRegistered","Integração TOTVS Corpore RM","Falha ao gerar objeto XML : " + oXML:Error())
            Else
                oXML:XPathRegisterNs("ns" , "http://schemas.xmlsoap.org/soap/envelope/" )
                oXml:xPathRegisterNs("ns1", "http://www.totvs.com/")
                cIDMovRet  := SubStr(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult'),;
                                     At(";",(oXML:XPathGetNodeValue('/ns:Envelope/ns:Body/ns1:SaveRecordResponse/ns1:SaveRecordResult')))+1)
                
                If !Empty(cIDMovRet) .AND. SF1->(FieldPos("F1_XIDMOV") > 0)
                    RecLock("SF1",.F.)
                        SF1->F1_XIDMOV := cIDMovRet 
                    SF1->(MSUnlock())
                EndIF 
            
            Endif

        EndIf
    EndIF 
    
Return
