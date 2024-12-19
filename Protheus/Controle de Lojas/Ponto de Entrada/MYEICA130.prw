#Include "Totvs.ch"

//----------------------------------------------------------
/*/{PROTHEUS.DOC} ITEM
Ponto de entrada na rotina de Manutenção de Cadastro de NCM
@OWNER COMPRAS
@AUTHOR TOTVS Nordeste (Elvis Siqueira)
@VERSION PROTHEUS 12
@SINCE 15/08/2023
@Atualizar NCMs 
/*/

User Function EICA130()
Local cParam
 
If ValType(ParamIXB) == "C"
   cParam:= ParamIXB
Else
   cParam:= ParamIXB[1]
EndIf
 
If cParam == "MENU"
   Aadd(aRotina, {"Atualizar NCM","u_zImpSYD" , 0 , 3})
EndIf
 
Return

/*/{Protheus.doc} Static Function zImpSYD
Função para atualizar a tabela de NCM no Protheus
@type  Function
@since 15/08/2023
@obs A atualização é baseada no JSON disponível para download em:
  https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/classificacao-fiscal-de-mercadorias/download-ncm-nomenclatura-comum-do-mercosul
/*/

User Function zImpSYD()
    Local aArea := FWGetArea()
  
    If FWAlertYesNo("Deseja atualizar a tabela de NCMs no Protheus?", "Continua")
        Processa({|| fImporta() }, 'NCMs...')
    EndIf
  
    FWRestArea(aArea)
Return

/*/{Protheus.doc} Static Function fImporta
Função para atualizar a tabela de NCM no Protheus
@type  Function
@obs 
/*/
  
Static Function fImporta()
    Local cLinkDown  := "https://portalunico.siscomex.gov.br/classif/api/publico/nomenclatura/download/json?perfil=PUBLICO"
    Local cTxtJson   := ""
    Local cError     := ""
    Local jImport
    Local jNomenclat
    Local jNCMAtu
    Local nNCMAtu    := 0
    Local cBARRAS    := If(isSRVunix(),"/","\") 
    Local cCodigo    := ""
    Local cDescric   := ""
    Local aDados     := {}
    Local cLog       := ""
    Local nLinhaErro := 0
    Local nTamDesc   := GetSX3Cache("YD_DESC_P", "X3_TAMANHO")
    //Variáveis para log do ExecAuto
    Private lMSHelpAuto    := .T.
    Private lAutoErrNoFile := .T.
    Private lMsErroAuto    := .F.
  
    cTxtJson := HttpGet(cLinkDown)
    cTxtJson := FWNoAccent(cTxtJson)
  
    If ! Empty(cTxtJson)
        jImport := JsonObject():New()
        cError  := jImport:FromJson(cTxtJson)
  
        DbSelectArea("SYD")
        SYD->(DbSetOrder(1)) // YD_FILIAL + YD_TEC + YD_EX_NCM + YD_EX_NBM + YD_DESTAQU
      
        If Empty(cError)
            jNomenclat := jImport:GetJsonObject('Nomenclaturas')
  
            nTotal := Len(jNomenclat)
            ProcRegua(nTotal)
            For nNCMAtu := 1 To nTotal
                IncProc("Processando registro " + cValToChar(nNCMAtu) + " de " + cValToChar(nTotal) + "...")
  
                jNCMAtu  := jNomenclat[nNCMAtu]
                cCodigo  := jNCMAtu:GetJsonObject("Codigo")
                cDescric := jNCMAtu:GetJsonObject("Descricao")
                cDescric := StrTran(cDescric, "-", "")
                cDescric := StrTran(cDescric, "<i>", "")
                cDescric := StrTran(cDescric, "</i>", "")
                cDescric := Alltrim(cDescric)
                cCodigo := Alltrim(cCodigo)
                cCodigo := StrTran(cCodigo, ".", "")
                cCodigo := StrTran(cCodigo, "-", "")
  
                If Len(cCodigo) == 8 .And. ! SYD->(MsSeek(FWxFilial("SYD") + cCodigo))
                    aDados := {}
                    aAdd(aDados, {"YD_TEC",    cCodigo,  Nil})
                    aAdd(aDados, {"YD_DESC_P", UPPER(SUBSTR(cDescric, 0, nTamDesc)), Nil})
                    aAdd(aDados, {"YD_UNID",   "UN",     Nil})
  
                    lMsErroAuto := .F.
                    MSExecAuto({|x, y| MVC_EICA130(x, y)}, aDados, 3)
  
                    If lMsErroAuto
                        cPastaErro := cBARRAS+'x_logs'+cBARRAS
                        cNomeErro  := 'erro_syd_cod_' + cCodigo + "_" + dToS(Date()) + '_' + StrTran(Time(), ':', '-') + '.txt'
  
                        If ! ExistDir(cPastaErro)
                            MakeDir(cPastaErro)
                        EndIf
  
                        cTextoErro := ""
                        cTextoErro += "Codigo:    " + cCodigo + CRLF
                        cTextoErro += "Descricao: " + cDescric + CRLF
                        cTextoErro += "--" + CRLF + CRLF
                        aLogErro := GetAutoGRLog()
                        For nLinhaErro := 1 To Len(aLogErro)
                            cTextoErro += aLogErro[nLinhaErro] + CRLF
                        Next

                        MemoWrite(cPastaErro + cNomeErro, cTextoErro)
                        cLog += '- Falha ao incluir registro, codigo [' + cCodigo + '], veja o arquivo de log em ' + cPastaErro + cNomeErro + CRLF
                    Else
                        cLog += '+ Sucesso no Execauto no codigo ' + cCodigo + ';' + CRLF
                    EndIf
                EndIf
            Next
  
            If ! Empty(cLog)
                cDirTmp := GetTempPath()
                cArqLog := 'importacao_' + dToS(Date()) + '_' + StrTran(Time(), ':', '-') + '.log'
                MemoWrite(cDirTmp + cArqLog, cLog)
                ShellExecute('OPEN', cArqLog, '', cDirTmp, 1)
            EndIf
  
        Else
            FWAlertError("Houve uma falha na conversão do JSON: " + CRLF + cError, "Erro no Parse")
        EndIf
    EndIf
Return
