// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Gillass is ERC20, Ownable {
    // ====== تنظیمات عرضه ======
    uint256 public constant TOTAL_SUPPLY = 2_000_000_000 * 10 ** 18; // 2B GIL

    address public pair;
    address public taxWallet;

    uint256 public buyTax = 0;       // مالیات خرید (‰0)
    uint256 public sellTax = 200;    // مالیات فروش (‰200 = 2%)

    mapping(address => bool) public isExcludedFromFee;

    // ====== سازنده ======
    constructor() ERC20("Gillass", "GIL") Ownable(msg.sender) {
        // 📌 آدرس‌ها
        address ownerAddr = 0x329483AD1068B4be6595b08b1fe6Fb62094Eeb78;
        address pairAddr  = 0xD4D40253E4F947751f644f9c90b6c4F4120a4a37;
        address taxAddr   = 0x329483AD1068B4be6595b08b1fe6Fb62094Eeb78;

        pair = pairAddr;
        taxWallet = taxAddr;

        // معافیت‌ها
        isExcludedFromFee[ownerAddr] = true;
        isExcludedFromFee[taxAddr] = true;
        isExcludedFromFee[address(this)] = true;

        // تقسیم عرضه
        uint256 emission = (TOTAL_SUPPLY * 55) / 100; // 55% -> قرارداد
        uint256 ownerPart = TOTAL_SUPPLY - emission;  // 45% -> مالک

        _mint(address(this), emission);  // emissionPool
        _mint(ownerAddr, ownerPart);     // برای مالک

        // مالکیت
        _transferOwnership(ownerAddr);
    }

    // ====== مدیریت ======
    function setPair(address _pair) external onlyOwner {
        pair = _pair;
    }

    function setTaxWallet(address _taxWallet) external onlyOwner {
        require(_taxWallet != address(0), "zero");
        taxWallet = _taxWallet;
    }

    function setBuyTax(uint256 _buyTax) external onlyOwner {
        require(_buyTax <= 500, "Too high"); // حداکثر 5%
        buyTax = _buyTax;
    }

    function setSellTax(uint256 _sellTax) external onlyOwner {
        require(_sellTax <= 500, "Too high"); // حداکثر 5%
        sellTax = _sellTax;
    }

    function excludeFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
    }

    // ====== منطق مالیات ======
    function _update(address from, address to, uint256 amount) internal override {
        uint256 taxAmount = 0;

        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            if (from == pair) {
                // خرید
                taxAmount = (amount * buyTax) / 10000;
            } else if (to == pair) {
                // فروش
                taxAmount = (amount * sellTax) / 10000;
            }
        }

        if (taxAmount > 0) {
            super._update(from, taxWallet, taxAmount);
            amount -= taxAmount;
        }

        super._update(from, to, amount);
    }
}
