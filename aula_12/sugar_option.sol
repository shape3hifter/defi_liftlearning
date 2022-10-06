pragma solidity 0.8;

// SPDX-License-Identifier: UNLICENSED

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract PutTokenAcucar is ERC20 {
    uint256 expirationDate = 1664496580; // Timestamp de expiração da put gerado a partir de  https://www.unixtimestamp.com/
    address underlyingAddress = 0x1AEF739B0f366DCF853F686300Ac721806480A2B; // AcucarCoin (ACU)
    address strikeAddress = 0xDE47C60e6964668cE158c75612F145BEf997229B; // RealCoin (BRLC)
    uint256 strikePrice = 2; // Preço do açúcar no futuro
    uint256 EXERCISE_WINDOW = 60*60; 
    /* Timestamp para retirada após a expiração da opção - chamada de "Janela de Exercício"
    => Neste contrato "Data de expiração" + (60 segundos * 60 segundos = 1 hora) 
    O motivo para esta janela de exercício é para que o detentor do token exerça a opção do token
    e a contra parte não retire o colateral antes de ser realizada a retirada */

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
        // 1) Fazer a conta de quanto colateral será preciso pegar do vendedor
        // 2) Transferir o colateral necessário do vendedor para o contrato
        // 3) Transferir de volta um token, que representa o contrrato de opção
    }

    function exercicio(uint256 amountOfOptions) public {
        require(block.timestamp > expirationDate, "A opcao nao expirou ainda");
        IERC20 strikeContract = IERC20(strikeAddress);
        IERC20 underlyingContract = IERC20(underlyingAddress);
        uint256 collateralToSend = amountOfOptions * strikePrice;

        underlyingContract.transferFrom(msg.sender, address(this), amountOfOptions); 
        // A quantidade de underlying (Açucar) é a mesma da opção (token PutAcucar) na proporção de 1 <=> 1
        
        strikeContract.transfer(msg.sender, collateralToSend);
        //  Número de opção * o strikpePrice do underlying. No nosso caso 1 Açucar <=> 2 BRLC

        _burn(msg.sender, amountOfOptions);
        // Passo que irá queimar as opções que foram exercidas

        // 1) require() => block.timestamp > expirationDate
        // (check) comprador enviar underlying(acucar coin) pro contrato e 
        // (check) comprador vai receber o strike asset (brl coin)
        // _burn()
        // burn no amountOFOptions (quantidade de opCoès a serem exercidas)
    }

    function retirada() public {
        /* Caso o vendedor não tenha sido exercido, ele pode retirar o colateral utilizando esta função
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

        // enviar a sobras ou o colateral não utilizado do vendedor que trancou inicialmente como garantia
    }

}
