//Bibliotecas
#Include 'totvs.ch'

/*/{Protheus.doc} MT103FIM
O ponto de entrada MT103FIM encontra-se no final da função A103NFISCAL.
Após o destravamento de todas as tabelas envolvidas na gravação do documento de entrada, 
depois de fechar a operação realizada neste.
@author TOTVS NORDESTE
@since 21/08/2024
@version 1.0
    @return Nil, Função não tem retorno
    @example
    MT103FIM()
    @obs https://tdn.totvs.com/pages/releaseview.action?pageId=6085406
/*/

User Function MT103FIM()
    Local aArea    := FWGetArea()
    
    DBSelectArea('SF1')
    IF SF1->(MSSeek(xFilial("SF1")+cNFiscal+cSerie+cA100For+cLoja))
        U_DSOAPF01("MovMovCopiaReferenciaData")
    EndIF 

    FWRestArea(aArea)

Return
