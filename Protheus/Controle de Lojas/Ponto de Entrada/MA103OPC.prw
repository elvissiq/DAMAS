#Include "Protheus.ch"
 
/*-------------------------------------------------------------------------------------*
 | P.E.:  MA103OPC                                                                     |
 | Desc:  MA103OPC - Adição de opções em "Outras Ações" da rotina Documento de Entrada.|
 | Link:  https://tdn.totvs.com/pages/releaseview.action?pageId=6085341                |
 *-------------------------------------------------------------------------------------*/

User Function MA103OPC()
        Local aDados := {}
        
        AAdd(aDados, { "Envia RM","u_fIntRM", 0, 1})

Return aDados
