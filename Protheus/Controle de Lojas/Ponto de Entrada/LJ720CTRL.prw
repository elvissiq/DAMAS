#Include "protheus.ch"

/*-----------------------------------------------------------------------------------------------------
  Função: LJ720CTRL

  Tipo: Ponto de entrada
  
  Este ponto de entrada é executado no início do programa LOJA720 na montagem da tela,
  permitindo configurar algumas propriedades de alguns objetos da tela, como por exemplo: 
  Radio Buttons e consulta padrão para busca do cliente.
  
  É passado como parâmetro um array com os controles que podem ser configurados,
  e deve ser retornado o array com as alterações desejadas, efetuadas nos controles desejados.
  
  Retorno:
    Array 
-----------------------------------------------------------------------------------------------------*/
User Function LJ720CTRL()
  Local aRet := ParamIXB

  //-------------------------
  //Radio Button "Processo"
  //-------------------------
  aRet[1][2] := 2 //1=Troca; 2=Devolução
  aRet[1][3] := .F. //.T.=Permite editar, .F.=Não permite editar

  //-------------------------
  //Radio Button "Origem"
  //-------------------------
  aRet[2][2] := 1 //1=Com Documento de Entrada; 2=Sem Documento de Entrada
  aRet[2][3] := .F. //.T.=Permite editar, .F.=Não permite editar

  //-------------------------
  //Radio Button "Buscar Venda Por"
  //-------------------------
  aRet[3][2] := 2 //1=Cliente e Data; 2=No. Cupom / Nota
  aRet[3][3] := .T. //.T.=Permite editar, .F.=Não permite editar

  //-------------------------
  //Consulta Padrao Cliente
  //-------------------------
  //aRet[4][2] := "XXX" //Consulta Padrão do Cliente (deve existir no SXB)
  //aRet[4][3] := .T. //.T.=Permite editar, .F.=Não permite editar

Return aRet
