// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../contracts/other/random_generator.sol";
import "../contracts/ArrayNfts.sol";
import "contracts/interface/router2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract ArrayNftsFinance is
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    RandomGenerator
{
    using AddressUpgradeable for address;

    address public USDT;
    address public ArrayNft;
    address public ArrayToken;
    address public WALLET;
    address public BlackHole;
    address public BuyBoxCostToken;
    address public PANCAKE_FACTORY;

    bool public isOpen;
    uint public startTime;
    uint public ACC;

    uint public costUsdtProportion;
    uint public openAmount;
    uint public boxPrice;
    uint[3] public cardIds;

    uint public resetPrice;
    uint public resetMaxTimes;
    uint[3] public resetPercentages;
    mapping(address => uint) public resetTimes;
    mapping(address => bool) public admin;

    struct BoxBag {
        uint cardId;
        uint amount;
    }
    struct BoxInfo {
        uint boxCardId;
        uint category;
        uint currentAmount;
        uint maxAmount;
        mapping(uint => BoxBag) bag;
    }
    BoxInfo public boxInfo;

    // nftRest
    struct ResetPool {
        uint cardId;
        uint percentage;
    }
    struct RestInfo {
        uint restTimes;
        mapping(uint => ResetPool) resetPool;
    }
    RestInfo public restInfo;

    // nftDistribute
    uint public lastTokenId;
    uint public tech;
    uint[3] public nftDistributeRatio;
    address public techAddr;
    struct NftDistribute {
        uint total;
        uint lvOne;
        uint lvTwo;
        uint lvThree;
    }
    NftDistribute public nftDistribute;
    mapping(uint => uint) public lastSingleDebt;

    mapping(uint => uint) public singleDebt;
    mapping(uint => uint) public singleClaimed;
    mapping(address => uint) public userNftRewardClaimed;

    //2.0
    uint public openedBox;
    event ClaimNftReward(address indexed addr, uint indexed amount);
    event Distribute(uint indexed amount);
    event BuyBox(address indexed user, uint indexed tokenId);
    event ResrtNft(
        address indexed user,
        uint indexed tokenId,
        uint indexed cardId
    );
    event OpenBox(
        address indexed user,
        uint indexed cardId,
        uint indexed tokenId
    );
    event Synthesis(
        address indexed user,
        uint indexed cardId,
        uint indexed tokenId
    );

    modifier onlyAdmin() {
        require(admin[msg.sender], "not admin");
        _;
    }

    function init() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        ACC = 1 ether;
        startTime = block.timestamp;
        USDT = 0x55d398326f99059fF775485246999027B3197955;
        // ArrayNft = ;
        // ArrayToken = ;
        // WALLET = address(0);
        // techAddr = ;
        BuyBoxCostToken = ArrayToken;
        BlackHole = 0x000000000000000000000000000000000000dEaD;
        // PANCAKE_FACTORY = ;
        // setAddress(mpoToken_, mpoNft_, mpoBox_);

        // box
        boxPrice = 100 ether;
        costUsdtProportion = 50;

        cardIds = [10001, 10002, 10003];

        //reset
        resetMaxTimes = 5;
        resetPrice = 10 ether;
        resetPercentages = [uint(750), uint(240), uint(10)];

        // de
        techAddr = msg.sender;
        tech = 40;
        nftDistributeRatio = [50, 30, 20];
        WALLET = address(this);
    }

    // admin
    function setAdmin(address addr_) public onlyOwner {
        admin[addr_] = true;
    }

    function setTechAddr(address techAddr_) public onlyAdmin {
        techAddr = techAddr_;
    }

    function setOpen(bool b_) public onlyOwner {
        isOpen = b_;
    }

    function setBoxPrice(uint boxPrice_) public onlyAdmin {
        boxPrice = boxPrice_;
    }

    function setCostUsdtProportion(uint costUsdtProportion_) public onlyAdmin {
        require(costUsdtProportion_ <= 100, "out of 100");
        costUsdtProportion = costUsdtProportion_;
    }

    function setUserReset(uint maxTimes_, uint resetPrice_) public onlyAdmin {
        resetMaxTimes = maxTimes_;
        resetPrice = resetPrice_;
    }

    function setArrayToken(address ArrayToken_) public onlyAdmin {
        ArrayToken = ArrayToken_;
    }

    function setArrayNft(address ArrayNft_) public onlyAdmin {
        ArrayNft = ArrayNft_;
    }

    function setBoxInfo(uint[2] calldata cardIds_, uint[2] calldata amounts_)
        public
        onlyAdmin
    {
        if (!isOpen) {
            isOpen = true;
        }
        require(amounts_.length == cardIds_.length, " len worry");
        boxInfo.category = cardIds_.length;

        uint total;
        for (uint i = 0; i < cardIds.length; i++) {
            boxInfo.bag[i] = BoxBag({cardId: cardIds[i], amount: amounts_[i]});
            total += amounts_[i];
        }
        boxInfo.maxAmount = total;
        boxInfo.currentAmount = boxInfo.maxAmount;
        require(openedBox + boxInfo.maxAmount < 3000, "out of 3000");
    }

    function setBuyBoxCostToken(address token_) public onlyAdmin {
        BuyBoxCostToken = token_;
    }

    // IBox721

    function checkCardIds() public view returns (uint[3] memory) {
        return cardIds;
    }

    function viewBoxBagInfo(uint category) public view returns (uint, uint) {
        uint cardId = boxInfo.bag[category].cardId;
        uint amount = boxInfo.bag[category].amount;
        return (cardId, amount);
    }

    function _randomLevel() private returns (uint) {
        uint level = randomCeil(boxInfo.currentAmount);
        uint newLeven;
        for (uint i = 0; i < boxInfo.category; ++i) {
            newLeven += boxInfo.bag[i].amount;
            if (level <= newLeven) {
                return i;
            }
        }
        revert("Random: Internal error");
    }

    function _getTokenPrice(address token_) internal view returns (uint price) {
        address _pair = IFactory(PANCAKE_FACTORY).getPair(USDT, token_);
        (uint re0, uint re1, ) = IPair(_pair).getReserves();
        address _t0 = IPair(_pair).token0();
        address _t1 = IPair(_pair).token1();
        {
            // scope for _t{0,1}, avoids stack too deep errors
            if (_t0 == USDT) price = (re0 * ACC) / re1;
            if (_t1 == USDT) price = (re1 * ACC) / re0;
        }
    }

    function buyBox() internal {
        uint U;
        uint T;

        uint tPrice = _getTokenPrice(BuyBoxCostToken);
        uint left;
        U = tPrice;
        if (costUsdtProportion != 100 && costUsdtProportion != 0) {
            U = (boxPrice * costUsdtProportion) / 100;
            left = boxPrice - U;
            T = (left * ACC) / tPrice;
        } else if (costUsdtProportion == 100) {
            U = boxPrice;
            T = 0;
        } else if (costUsdtProportion == 0) {
            U = 0;
            T = (boxPrice * ACC) / tPrice;
        }

        if (U != 0) IERC20(USDT).transferFrom(msg.sender, WALLET, U);

        if (T != 0) {
            if (BuyBoxCostToken == ArrayToken)
                IERC20(BuyBoxCostToken).transferFrom(msg.sender, BlackHole, T);

            if (BuyBoxCostToken != ArrayToken)
                IERC20(BuyBoxCostToken).transferFrom(msg.sender, BlackHole, T);
        }
    }

    function openBox() external returns (uint) {
        require(WALLET != address(0), "no wallet");
        require(isOpen && block.timestamp >= startTime, "not open");
        require(boxInfo.currentAmount > 0, "Out of limit");

        uint level = _randomLevel();
        uint cardId = boxInfo.bag[level].cardId;

        openAmount += 1;
        boxInfo.bag[level].amount -= 1;
        boxInfo.currentAmount -= 1;

        uint tokenId = ArrayNfts(ArrayNft).mint(msg.sender, cardId);
        buyBox();
        openedBox += 1;
        emit OpenBox(_msgSender(), cardId, tokenId);
        return tokenId;
    }

    //--------------------------------- Reset ---------------------------------

    function _randomResetLevel() private returns (uint) {
        uint level = randomCeil(1000);
        if (level <= resetPercentages[0]) {
            return cardIds[0];
        } else if (
            level > resetPercentages[0] && level <= resetPercentages[1]
        ) {
            return cardIds[1];
        } else if (level > resetPercentages[2]) {
            return cardIds[2];
        }
        revert("Random: Internal error");
    }

    function resetNft(uint tokenId_) public returns (uint) {
        require(isOpen && block.timestamp >= startTime, "not open");
        require(resetMaxTimes >= resetTimes[msg.sender], "out of time");
        ArrayNfts(ArrayNft).burn(tokenId_);
        uint _cardId = _randomResetLevel();
        restInfo.restTimes += 1;
        uint _tokenId = ArrayNfts(ArrayNft).mint(msg.sender, _cardId);
        IERC20(USDT).transferFrom(msg.sender, address(this), resetPrice);
        resetTimes[msg.sender] += 1;
        emit ResrtNft(msg.sender, _tokenId, _cardId);
        return _cardId;
    }

    //-------------------------------- Finance --------------------------------

    function setDistributeInfo(uint tech_, uint[3] calldata nftDistributeRatio_)
        public
        onlyAdmin
    {
        require(
            nftDistributeRatio_[0] +
                nftDistributeRatio_[1] +
                nftDistributeRatio_[2] ==
                100,
            "not 100"
        );
        require(tech_ < 100, "out of 100");

        tech = tech_;
        nftDistributeRatio = nftDistributeRatio_;
    }

    function checkNowTokenId() public view returns (uint max) {
        uint b = ArrayNfts(ArrayNft).burned();
        uint c = ArrayNfts(ArrayNft).totalSupply();
        max = b + c;
    }

    function calculateCardReward(uint cardId_, uint tokenId_)
        public
        view
        returns (uint)
    {
        uint re;
        if (tokenId_ > lastTokenId) {
            return 0;
        }
        if (singleClaimed[tokenId_] == 0) {
            re = singleDebt[cardId_] - lastSingleDebt[cardId_];
            return re;
        }

        if (singleDebt[cardId_] > singleClaimed[tokenId_]) {
            re = singleDebt[cardId_] - singleClaimed[tokenId_];
            return re;
        } else {
            return 0;
        }
    }

    function _updataClaimed(uint cardId_, uint tokenId_)
        internal
        returns (uint)
    {
        uint re;
        if (tokenId_ > lastTokenId) {
            return 0;
        }
        if (singleClaimed[tokenId_] == 0) {
            re = singleDebt[cardId_] - lastSingleDebt[cardId_];
            singleClaimed[tokenId_] = singleDebt[cardId_];
            return re;
        }

        if (singleDebt[cardId_] > singleClaimed[tokenId_]) {
            re = singleDebt[cardId_] - singleClaimed[tokenId_];
            singleClaimed[tokenId_] = singleDebt[cardId_];
            return re;
        } else {
            return 0;
        }
    }

    function calculateUserReward(address user_) public view returns (uint re) {
        uint[] memory tokenIdss;
        (tokenIdss, ) = ArrayNfts(ArrayNft).tokenOfOwnerForAll(user_);
        uint cid;
        if (tokenIdss.length > 0) {
            for (uint i; i < tokenIdss.length; i++) {
                cid = ArrayNfts(ArrayNft).cardIdMap(tokenIdss[i]);
                if (cid == cardIds[0]) {
                    re += calculateCardReward(cardIds[0], tokenIdss[i]);
                }
                if (cid == cardIds[1]) {
                    re += calculateCardReward(cardIds[1], tokenIdss[i]);
                }
                if (cid == cardIds[2]) {
                    re += calculateCardReward(cardIds[2], tokenIdss[i]);
                }
            }
        }
    }

    function _updataUserReward(address user_) internal returns (uint re) {
        uint[] memory tokenIdss;
        (tokenIdss, ) = ArrayNfts(ArrayNft).tokenOfOwnerForAll(user_);
        uint cid;
        if (tokenIdss.length > 0) {
            for (uint i; i < tokenIdss.length; i++) {
                cid = ArrayNfts(ArrayNft).cardIdMap(tokenIdss[i]);
                if (cid == cardIds[0]) {
                    re += _updataClaimed(cardIds[0], tokenIdss[i]);
                }
                if (cid == cardIds[1]) {
                    re += _updataClaimed(cardIds[1], tokenIdss[i]);
                }
                if (cid == cardIds[2]) {
                    re += _updataClaimed(cardIds[2], tokenIdss[i]);
                }
            }
        }
    }

    function _updataDebt(uint cardId_, uint amount_) internal returns (uint) {
        lastSingleDebt[cardId_] = singleDebt[cardId_];

        uint current;
        (, , current, , ) = ArrayNfts(ArrayNft).cardInfoes(cardId_);
        uint temp = amount_ / current;
        singleDebt[cardId_] += temp;
        return temp;
    }

    function claimNftReward() public returns (uint) {
        uint b = ArrayNfts(ArrayNft).balanceOf(msg.sender);
        require(b > 0, "not holder");
        require(nftDistribute.total != 0, "zero");

        uint re = _updataUserReward(msg.sender);

        if (re != 0) {
            IERC20(USDT).transfer(msg.sender, re);
            userNftRewardClaimed[msg.sender] += re;
        }

        // userNftsDebt[msg.sender][cardIds[0]] = singleDebt[cardIds[0]];
        // userNftsDebt[msg.sender][cardIds[1]] = singleDebt[cardIds[1]];
        // userNftsDebt[msg.sender][cardIds[2]] = singleDebt[cardIds[2]];

        emit ClaimNftReward(msg.sender, re);
        return re;
    }

    function distribute(uint amount_) public onlyAdmin {
        require(amount_ > 0, "0");
        IERC20(USDT).transfer(techAddr, (amount_ * tech) / 100);
        uint _amount = amount_ - ((amount_ * tech) / 100);
        uint _one = (_amount * nftDistributeRatio[0]) / 100;
        uint _two = (_amount * nftDistributeRatio[1]) / 100;
        uint _three = (_amount * nftDistributeRatio[2]) / 100;

        _updataDebt(cardIds[0], _one);
        _updataDebt(cardIds[1], _two);
        _updataDebt(cardIds[2], _three);

        nftDistribute.lvOne += _one;
        nftDistribute.lvTwo += _two;
        nftDistribute.lvThree += _three;
        nftDistribute.total += _amount;

        lastTokenId = INft(ArrayNft).getNowTokenId();

        emit Distribute(amount_);
    }

    //------------------------------- Synthesis -------------------------------

    function synthesis(uint[2] calldata tokenIds_)
        public
        returns (uint newTokenId)
    {
        bool _status;
        uint len = tokenIds_.length;
        require(len == 2, "worry len");
        require(
            ArrayNfts(ArrayNft).exists(tokenIds_[0]) &&
                ArrayNfts(ArrayNft).exists(tokenIds_[1]),
            "is null card"
        );
        uint a = ArrayNfts(ArrayNft).cardIdMap(tokenIds_[0]);
        uint b = ArrayNfts(ArrayNft).cardIdMap(tokenIds_[1]);
        require(a == b, "worry cardIDs");
        if (a == 10001) {
            _status = true;
            newTokenId = _synthesis1(tokenIds_);
        } else if (a == 10002) {
            _status = true;
            newTokenId = _synthesis2(tokenIds_);
        }
    }

    function _synthesis1(uint[2] calldata tokenIds_)
        internal
        returns (uint newTokenId)
    {
        uint cardId;
        uint len = tokenIds_.length;
        require(len == 2, "wrong length");
        for (uint u = 0; u < len; u++) {
            cardId = ArrayNfts(ArrayNft).cardIdMap(tokenIds_[u]);
            require(cardId == cardIds[0], "not 10001 card");
        }
        for (uint i; i < tokenIds_.length; i++) {
            ArrayNfts(ArrayNft).burn(tokenIds_[i]);
        }
        newTokenId = ArrayNfts(ArrayNft).mint(msg.sender, cardIds[1]);
        emit Synthesis(_msgSender(), cardIds[1], newTokenId);
    }

    function _synthesis2(uint[2] calldata tokenIds_)
        internal
        returns (uint newTokenId)
    {
        uint cardId;
        uint len = tokenIds_.length;
        require(len == 2, "wrong length");
        for (uint u = 0; u < len; u++) {
            cardId = ArrayNfts(ArrayNft).cardIdMap(tokenIds_[u]);
            require(cardId == cardIds[1], "not 10002 card");
        }
        for (uint i; i < tokenIds_.length; i++) {
            ArrayNfts(ArrayNft).burn(tokenIds_[i]);
        }
        newTokenId = ArrayNfts(ArrayNft).mint(msg.sender, cardIds[2]);
        emit Synthesis(_msgSender(), cardIds[2], newTokenId);
    }
}
