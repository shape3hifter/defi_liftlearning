pragma solidity 0.8;

// SPDX-License-Identifier: UNLICENSED

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract PutTokenAcucar is ERC20 {
    uint256 expirationDate = 1664496580; // Timestamp de expira��o da put gerado a partir de  https://www.unixtimestamp.com/
    address underlyingAddress = 0x1AEF739B0f366DCF853F686300Ac721806480A2B; // AcucarCoin (ACU)
    address strikeAddress = 0xDE47C60e6964668cE158c75612F145BEf997229B; // RealCoin (BRLC)
    uint256 strikePrice = 2; // Pre�o do a��car no futuro
    uint256 EXERCISE_WINDOW = 60*60; 
    /* Timestamp para retirada ap�s a expira��o da op��o - chamada de "Janela de Exerc�cio"
    => Neste contrato "Data de expira��o" + (60 segundos * 60 segundos = 1 hora) 
    O motivo para esta janela de exerc�cio � para que o detentor do token exer�a a op��o do token
    e a contra parte n�o retire o colateral antes de ser realizada a retirada */

    mapping(address => uint256) opcoesCriadas;

    // PUT => direito de VENDA -> 100% collateralized

    constructor() ERC20("Put-Acucar-Lift-Oct", "PutAcucar") {}

    function criacao(uint256 amountOfOptions) public {
        uint256 collateralToLock = amountOfOptions * strikePrice;
        IERC20 strikeContract = IERC20(strikeAddress);

        strikeContract.transferFrom(msg.sender, address(this), collateralToLock);
        _mint(msg.sender, amountOfOptions);
        opcoesCriadas[msg.sender] = amountOfOptions;
        // _mint()
        // 1) Fazer a conta de quanto colateral ser� preciso pegar do vendedor
        // 2) Transferir o colateral necess�rio do vendedor para o contrato
        // 3) Transferir de volta um token, que representa o contrrato de op��o
    }

    function exercicio(uint256 amountOfOptions) public {
        require(block.timestamp > expirationDate, "A opcao nao expirou ainda");
        IERC20 strikeContract = IERC20(strikeAddress);
        IERC20 underlyingContract = IERC20(underlyingAddress);
        uint256 collateralToSend = amountOfOptions * strikePrice;

        underlyingContract.transferFrom(msg.sender, address(this), amountOfOptions); 
        // A quantidade de underlying (A�ucar) � a mesma da op��o (token PutAcucar) na propor��o de 1 <=> 1
        
        strikeContract.transfer(msg.sender, collateralToSend);
        //  N�mero de op��o * o strikpePrice do underlying. No nosso caso 1 A�ucar <=> 2 BRLC

        _burn(msg.sender, amountOfOptions);
        // Passo que ir� queimar as op��es que foram exercidas

        // 1) require() => block.timestamp > expirationDate
        // (check) comprador enviar underlying(acucar coin) pro contrato e 
        // (check) comprador vai receber o strike asset (brl coin)
        // _burn()
        // burn no amountOFOptions (quantidade de opCo�s a serem exercidas)
    }

    function retirada() public {
        /* Caso o vendedor n�o tenha sido exercido, ele pode retirar o colateral utilizando esta fun��o
        ou o comprador quer retirar as eventuais sobras */

        require(block.timestamp > expirationDate + EXERCISE_WINDOW, "A opcao nao expirou ainda");
        uint256 quantidadeCriada = opcoesCriadas[msg.sender];

         IERC20 strikeContract = IERC20(strikeAddress);
         IERC20 underlyingContract = IERC20(underlyingAddress);

        if (underlyingContract.balanceOf(address(this)) > 0) {
            underlyingContract.transfer(msg.sender, quantidadeCriada);
        } else {
            // envio o colateral original
            strikeContract.transfer(msg.sender, quantidadeCriada * strikePrice);
        }
         
         // SE O COMPRADOR NAO EXERCEU => ENVIAR O COLATERAL QUE TINHA SIDO TRANCADO
         // SE O COMPRADOR EXERCEU => ENVIAR O ACUCAR COIN QUE O COMPRADOR VENDEU 

        // enviar a sobras ou o colateral n�o utilizado do vendedor que trancou inicialmente como garantia
    }

}
