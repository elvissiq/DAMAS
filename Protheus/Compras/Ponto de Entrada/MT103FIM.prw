//Bibliotecas
#Include 'totvs.ch'

/*/{Protheus.doc} MT103FIM
O ponto de entrada MT103FIM encontra-se no final da fun��o A103NFISCAL.
Ap�s o destravamento de todas as tabelas envolvidas na grava��o do documento de entrada, 
depois de fechar a opera��o realizada neste.
@author TOTVS NORDESTE
@since 13/03/2024
@version 1.0
    @return Nil, Fun��o n�o tem retorno
    @example
    MT103FIM()
    @obs https://tdn.totvs.com/pages/releaseview.action?pageId=6085406
@Historico
    10/06/2024 - Desenvolvimento da rotina - Elvis Siqueira
/*/

User Function MT103FIM()
    Local aArea := FWGetArea()

    If PARAMIXB[1] == 3 .and. PARAMIXB[2] == 1
    
        U_DSOAPF01(,,"MovMovCopiaReferenciaData") //Envia a Nota Fiscal de Entrada para o TOTVS Corpore RM

    EndIf

    FWRestArea(aArea)

Return
